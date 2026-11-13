import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where Nova's thinking happens.
///
/// Two answers, and the privacy positioning survives both, because neither
/// of them is "we send your health data to a company you did not choose":
///
/// * [AiBackend.local] — the Gemma bundle on this phone. Nothing leaves.
/// * [AiBackend.cloud] — an OpenAI-compatible inference endpoint **the user
///   points us at**: Ollama or LM Studio on their laptop, llama.cpp or vLLM
///   on their own server, or anything else that speaks the same protocol.
///
/// The second one is not a vendor integration and deliberately has no
/// branded providers. Vyana does not hold a relationship with whoever is on
/// the other end — the user does. What Vyana owes them is to be exact about
/// where their address actually points, which is what [EndpointReach] is
/// for: an endpoint on this phone, on their own network, or out on the
/// internet are three different promises, and only the user can tell which
/// one they meant.
enum AiBackend { local, cloud }

extension AiBackendLabel on AiBackend {
  String get id => switch (this) {
        AiBackend.local => 'local',
        AiBackend.cloud => 'cloud',
      };

  String get label => switch (this) {
        AiBackend.local => 'On this phone',
        AiBackend.cloud => 'Your own endpoint',
      };

  static AiBackend fromId(String? id) =>
      id == AiBackend.cloud.id ? AiBackend.cloud : AiBackend.local;
}

/// What an endpoint's address means for the data sent to it.
///
/// Decided from the host, not from what the server calls itself: a server
/// is free to describe itself however it likes, and the address is the only
/// part of this the phone can actually verify.
enum EndpointReach { onThisPhone, onYourNetwork, overTheInternet }

extension EndpointReachCopy on EndpointReach {
  /// Said in the second person, because it is the user's decision being
  /// described rather than a property of the software.
  String get summary => switch (this) {
        EndpointReach.onThisPhone => 'Stays on this phone',
        EndpointReach.onYourNetwork => 'Stays on your network',
        EndpointReach.overTheInternet => 'Leaves your network',
      };

  String get detail => switch (this) {
        EndpointReach.onThisPhone =>
          'This address is the phone itself, so nothing is sent anywhere.',
        EndpointReach.onYourNetwork =>
          'This address is on your local network — a machine you run. '
              'Nothing reaches the internet.',
        EndpointReach.overTheInternet =>
          'This address is outside your network. Your conversation and the '
              'health figures Nova is given will be sent to whoever runs it.',
      };

  bool get isPrivate => this != EndpointReach.overTheInternet;
}

/// Classifies [host] without resolving it — a DNS lookup would be a network
/// call made to answer a question about whether to make network calls.
EndpointReach reachForHost(String host) {
  final h = host.trim().toLowerCase();
  if (h.isEmpty) return EndpointReach.overTheInternet;
  if (h == 'localhost' || h == '::1' || h.endsWith('.localhost')) {
    return EndpointReach.onThisPhone;
  }
  // mDNS names (`my-nas.local`) only resolve on the local segment.
  if (h.endsWith('.local')) return EndpointReach.onYourNetwork;

  final v4 = _parseIpv4(h);
  if (v4 != null) {
    final [a, b, _, _] = v4;
    if (a == 127) return EndpointReach.onThisPhone;
    // RFC1918, plus link-local and the emulator's host alias.
    if (a == 10) return EndpointReach.onYourNetwork;
    if (a == 172 && b >= 16 && b <= 31) return EndpointReach.onYourNetwork;
    if (a == 192 && b == 168) return EndpointReach.onYourNetwork;
    if (a == 169 && b == 254) return EndpointReach.onYourNetwork;
    return EndpointReach.overTheInternet;
  }
  return EndpointReach.overTheInternet;
}

List<int>? _parseIpv4(String host) {
  final parts = host.split('.');
  if (parts.length != 4) return null;
  final out = <int>[];
  for (final part in parts) {
    final n = int.tryParse(part);
    if (n == null || n < 0 || n > 255) return null;
    out.add(n);
  }
  return out;
}

/// Thrown when an endpoint is rejected before any request is made.
class EndpointRejected implements Exception {
  const EndpointRejected(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The endpoint as the user configured it.
@immutable
class CloudEndpoint {
  const CloudEndpoint({
    required this.baseUrl,
    required this.model,
    this.hasKey = false,
  });

  /// Root of the OpenAI-compatible API, e.g. `http://192.168.1.20:11434/v1`.
  final String baseUrl;

  /// Model name as that server knows it, e.g. `llama3.1:8b`.
  final String model;

  /// Whether a key is held for this endpoint. The key itself never travels
  /// with the config — it lives in the platform keystore.
  final bool hasKey;

  static const empty = CloudEndpoint(baseUrl: '', model: '');

  bool get isComplete => baseUrl.trim().isNotEmpty && model.trim().isNotEmpty;

  Uri? get uri => Uri.tryParse(baseUrl.trim());

  EndpointReach get reach {
    final parsed = uri;
    if (parsed == null) return EndpointReach.overTheInternet;
    return reachForHost(parsed.host);
  }

  CloudEndpoint copyWith({String? baseUrl, String? model, bool? hasKey}) =>
      CloudEndpoint(
        baseUrl: baseUrl ?? this.baseUrl,
        model: model ?? this.model,
        hasKey: hasKey ?? this.hasKey,
      );
}

/// Validates an endpoint URL before anything is sent to it.
///
/// Cleartext is allowed to the phone and to the local network, because that
/// is what Ollama and LM Studio actually serve and demanding HTTPS there
/// would make the feature unusable for its real audience. It is refused to
/// anywhere else: plain HTTP across the internet would put the
/// conversation, and the health figures in it, in the clear for every hop in
/// between.
///
/// This check is the whole of the rule, and it has to be, because Android's
/// own cleartext policy cannot express it — a network security config
/// matches domains, not CIDR blocks, so it can permit `localhost` but not
/// "any RFC1918 address". It is also not consulted here: `dart:io`'s
/// HttpClient uses its own sockets rather than a Java HTTP stack, so
/// `cleartextTrafficPermitted` never applies to these requests. Loosening
/// the manifest would therefore buy nothing and weaken the WebView and
/// everything else that *does* consult it.
Uri validateEndpoint(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    throw const EndpointRejected('Enter the address of your server.');
  }
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw const EndpointRejected(
      'That does not look like an address. It should start with http:// or '
      'https:// and name a host.',
    );
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    throw EndpointRejected('${uri.scheme}:// is not an address Vyana can call.');
  }
  if (uri.scheme == 'http' && !reachForHost(uri.host).isPrivate) {
    throw const EndpointRejected(
      'Plain http is only allowed to this phone or your own network. An '
      'address out on the internet has to be https, or everything Nova '
      'sends travels in the clear.',
    );
  }
  return uri;
}

/// Reads and writes the backend choice. The key goes to the platform
/// keystore — Keychain on iOS, EncryptedSharedPreferences on Android — and
/// never to SharedPreferences beside the rest of the settings.
class AiBackendStore {
  static const _backendKey = 'vyana.ai.backend_v1';
  static const _baseUrlKey = 'vyana.ai.endpoint_base_url_v1';
  static const _modelKey = 'vyana.ai.endpoint_model_v1';
  static const _secureKeyName = 'vyana.ai.endpoint_api_key_v1';

  // Android's default is the plugin's own ciphers now that Jetpack Security
  // is deprecated; iOS keeps the key out of reach until the phone has been
  // unlocked once since boot, which is as early as Nova ever needs it.
  static const _secure = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<AiBackend> readBackend() async {
    final prefs = await SharedPreferences.getInstance();
    return AiBackendLabel.fromId(prefs.getString(_backendKey));
  }

  Future<void> writeBackend(AiBackend backend) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backendKey, backend.id);
  }

  Future<CloudEndpoint> readEndpoint() async {
    final prefs = await SharedPreferences.getInstance();
    return CloudEndpoint(
      baseUrl: prefs.getString(_baseUrlKey) ?? '',
      model: prefs.getString(_modelKey) ?? '',
      hasKey: await readKey() != null,
    );
  }

  Future<void> writeEndpoint(CloudEndpoint endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, endpoint.baseUrl.trim());
    await prefs.setString(_modelKey, endpoint.model.trim());
  }

  Future<String?> readKey() async {
    try {
      final value = await _secure.read(key: _secureKeyName);
      return (value == null || value.isEmpty) ? null : value;
    } on Object catch (error) {
      // A keystore that will not open is a reason to behave as though there
      // is no key, never a reason to fall back to storing it in the clear.
      debugPrint('[AiBackend] keystore read failed: $error');
      return null;
    }
  }

  Future<void> writeKey(String? key) async {
    final value = key?.trim();
    try {
      if (value == null || value.isEmpty) {
        await _secure.delete(key: _secureKeyName);
      } else {
        await _secure.write(key: _secureKeyName, value: value);
      }
    } on Object catch (error) {
      debugPrint('[AiBackend] keystore write failed: $error');
      rethrow;
    }
  }
}

/// Streams completions from an OpenAI-compatible endpoint.
///
/// One protocol covers Ollama, LM Studio, llama.cpp's server, vLLM, LocalAI
/// and Jan, because they all speak `/chat/completions`. Vyana ships no
/// per-vendor code: whatever the user runs, this is the same request.
class CloudInferenceClient {
  CloudInferenceClient({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  /// Long enough for a cold model load on a laptop, short enough that a
  /// wrong address fails while the user is still looking at the screen.
  static const Duration connectTimeout = Duration(seconds: 20);

  Uri _resolve(String baseUrl, String path) {
    final root = validateEndpoint(baseUrl);
    final base = root.path.endsWith('/')
        ? root.path.substring(0, root.path.length - 1)
        : root.path;
    return root.replace(path: '$base$path');
  }

  Future<HttpClientRequest> _open(
    String baseUrl,
    String path,
    String? apiKey,
  ) async {
    final request = await _client.postUrl(_resolve(baseUrl, path));
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
    // Only sent when the user gave us one — a self-hosted Ollama usually
    // needs none, and inventing an Authorization header makes some servers
    // reject the request outright.
    if (apiKey != null && apiKey.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
    }
    return request;
  }

  /// A cheap round trip that proves the address, the model name and the key
  /// all work together, so the user finds out here rather than mid-sentence
  /// in a conversation with Nova.
  Future<void> testConnection({
    required String baseUrl,
    required String model,
    String? apiKey,
  }) async {
    final request = await _open(baseUrl, '/chat/completions', apiKey)
        .timeout(connectTimeout);
    request.add(utf8.encode(jsonEncode({
      'model': model,
      'messages': [
        {'role': 'user', 'content': 'Reply with the single word: ready'},
      ],
      'max_tokens': 8,
      'stream': false,
    })));
    final response = await request.close().timeout(connectTimeout);
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode == HttpStatus.unauthorized ||
        response.statusCode == HttpStatus.forbidden) {
      throw const EndpointRejected(
        'The server refused the key. Check it, or clear it if the server '
        'does not need one.',
      );
    }
    if (response.statusCode == HttpStatus.notFound) {
      throw const EndpointRejected(
        'No chat endpoint at that address. Most servers want the /v1 on the '
        'end, for example http://192.168.1.20:11434/v1',
      );
    }
    if (response.statusCode >= 400) {
      throw EndpointRejected(
        'The server answered ${response.statusCode}. ${_briefly(body)}',
      );
    }
  }

  /// Streams the reply, yielding the text accumulated so far — the same
  /// shape [GuideRuntimeService.streamResponse] yields, so callers cannot
  /// tell which backend answered.
  Stream<String> stream({
    required String baseUrl,
    required String model,
    required String prompt,
    String? apiKey,
  }) async* {
    final request = await _open(baseUrl, '/chat/completions', apiKey)
        .timeout(connectTimeout);
    request.add(utf8.encode(jsonEncode({
      'model': model,
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
      'stream': true,
    })));

    final response = await request.close().timeout(connectTimeout);
    if (response.statusCode >= 400) {
      final body = await response.transform(utf8.decoder).join();
      throw EndpointRejected(
        'Your endpoint answered ${response.statusCode}. ${_briefly(body)}',
      );
    }

    final buffer = StringBuffer();
    await for (final line in response
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      final chunk = _deltaFrom(line);
      if (chunk == null) continue;
      if (chunk.isEmpty) continue;
      buffer.write(chunk);
      yield buffer.toString();
    }
  }

  /// One SSE line to the text it carries, or null when it carries none.
  /// Kept pure and visible so the parsing can be tested without a server.
  @visibleForTesting
  static String? deltaFromLine(String line) => _deltaFrom(line);

  static String? _deltaFrom(String line) {
    if (!line.startsWith('data:')) return null;
    final payload = line.substring(5).trim();
    if (payload.isEmpty || payload == '[DONE]') return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return null;
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) return null;
      final first = choices.first;
      if (first is! Map) return null;
      // Streaming servers send `delta`; a few send a whole `message` per
      // chunk instead, and both are worth reading rather than dropping.
      final delta = first['delta'] ?? first['message'];
      if (delta is! Map) return null;
      final content = delta['content'];
      return content is String ? content : null;
    } on Object {
      return null;
    }
  }

  static String _briefly(String body) {
    final flat = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flat.isEmpty) return '';
    return flat.length > 160 ? '${flat.substring(0, 160)}…' : flat;
  }

  void close() => _client.close(force: true);
}

/// The app's view of where Nova thinks, and the actions that change it.
class AiBackendController extends ChangeNotifier {
  AiBackendController({AiBackendStore? store, CloudInferenceClient? client})
      : _store = store ?? AiBackendStore(),
        _client = client ?? CloudInferenceClient() {
    unawaited(_load());
  }

  final AiBackendStore _store;
  final CloudInferenceClient _client;

  AiBackend _backend = AiBackend.local;
  CloudEndpoint _endpoint = CloudEndpoint.empty;
  bool _loaded = false;
  bool _testing = false;
  String? _lastError;
  String? _lastSuccess;

  AiBackend get backend => _backend;
  CloudEndpoint get endpoint => _endpoint;
  bool get loaded => _loaded;
  bool get isTesting => _testing;
  String? get lastError => _lastError;
  String? get lastSuccess => _lastSuccess;

  /// Whether the chosen backend is actually usable. Local is answered by the
  /// model manager, so this only speaks for the cloud one.
  bool get cloudReady => _endpoint.isComplete;

  Future<void> _load() async {
    _backend = await _store.readBackend();
    _endpoint = await _store.readEndpoint();
    _loaded = true;
    notifyListeners();
  }

  Future<void> setBackend(AiBackend backend) async {
    _backend = backend;
    _lastError = null;
    _lastSuccess = null;
    notifyListeners();
    await _store.writeBackend(backend);
  }

  /// Saves the endpoint after proving it answers. Nothing is stored when the
  /// test fails: a saved endpoint that has never worked is a setting that
  /// lies to the next screen that reads it.
  Future<bool> saveEndpoint({
    required String baseUrl,
    required String model,
    String? apiKey,
    bool clearKey = false,
  }) async {
    _testing = true;
    _lastError = null;
    _lastSuccess = null;
    notifyListeners();
    try {
      validateEndpoint(baseUrl);
      if (model.trim().isEmpty) {
        throw const EndpointRejected(
          'Name the model as your server knows it, for example llama3.1:8b.',
        );
      }
      final key = clearKey ? null : (apiKey?.trim().isNotEmpty ?? false)
          ? apiKey!.trim()
          : await _store.readKey();

      await _client.testConnection(
        baseUrl: baseUrl,
        model: model,
        apiKey: key,
      );

      if (clearKey || (apiKey?.trim().isNotEmpty ?? false)) {
        await _store.writeKey(clearKey ? null : apiKey!.trim());
      }
      final saved = CloudEndpoint(
        baseUrl: baseUrl.trim(),
        model: model.trim(),
        hasKey: await _store.readKey() != null,
      );
      await _store.writeEndpoint(saved);
      _endpoint = saved;
      _lastSuccess = 'Connected. ${saved.reach.summary.toLowerCase()}.';
      return true;
    } on EndpointRejected catch (error) {
      _lastError = error.message;
      return false;
    } on TimeoutException {
      _lastError =
          'No answer from that address. Check the server is running and the '
          'phone is on the same network.';
      return false;
    } on SocketException catch (error) {
      _lastError = 'Could not reach that address: ${error.message}';
      return false;
    } on Object catch (error) {
      _lastError = 'Could not reach that address: $error';
      return false;
    } finally {
      _testing = false;
      notifyListeners();
    }
  }

  /// Forgets the endpoint and its key, and falls back to the on-device model.
  Future<void> forgetEndpoint() async {
    await _store.writeKey(null);
    await _store.writeEndpoint(CloudEndpoint.empty);
    await _store.writeBackend(AiBackend.local);
    _endpoint = CloudEndpoint.empty;
    _backend = AiBackend.local;
    _lastError = null;
    _lastSuccess = null;
    notifyListeners();
  }

  /// Streams a reply from the configured endpoint.
  Stream<String> streamFromEndpoint(String prompt) async* {
    final key = await _store.readKey();
    yield* _client.stream(
      baseUrl: _endpoint.baseUrl,
      model: _endpoint.model,
      prompt: prompt,
      apiKey: key,
    );
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}

final aiBackendProvider = ChangeNotifierProvider<AiBackendController>(
  (ref) => AiBackendController(),
);

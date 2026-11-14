import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vyana/src/services/ai_backend_service.dart';

/// Item 69, part four — the API key must not follow the address.
///
/// endpoint_privacy_test.dart proves `keyTravelsTo` answers correctly. This
/// proves `saveEndpoint` *asks* it, which is a different claim: a correct
/// helper that nothing calls fixes nothing, and the only way to see the
/// leak is to watch what reaches the client.
///
/// So the assertions here are about the key the fake client was handed. It
/// is the request that was leaking — the old server's secret went out
/// during the connection test against the new host, before any screen
/// could show where it had gone.
class _FakeStore extends AiBackendStore {
  _FakeStore({this.endpoint = CloudEndpoint.empty, this.key});

  CloudEndpoint endpoint;
  String? key;
  final List<String> told = [];

  @override
  Future<AiBackend> readBackend() async => AiBackend.cloud;

  @override
  Future<void> writeBackend(AiBackend backend) async {}

  @override
  Future<CloudEndpoint> readEndpoint() async =>
      endpoint.copyWith(hasKey: key != null);

  @override
  Future<void> writeEndpoint(CloudEndpoint value) async {
    endpoint = value;
  }

  @override
  Future<String?> readKey() async => key;

  @override
  Future<void> writeKey(String? value) async {
    key = (value == null || value.isEmpty) ? null : value;
  }

  @override
  Future<List<String>> readToldOrigins() async => told;

  @override
  Future<void> addToldOrigin(String baseUrl) async {
    final origin = endpointOrigin(baseUrl);
    if (origin != null && !told.contains(origin)) told.add(origin);
  }
}

class _FakeClient extends CloudInferenceClient {
  String? sentKey;
  bool wasCalled = false;
  bool refuse = false;

  @override
  Future<void> testConnection({
    required String baseUrl,
    required String model,
    String? apiKey,
  }) async {
    wasCalled = true;
    sentKey = apiKey;
    if (refuse) throw const EndpointRejected('nope');
  }

  @override
  void close() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// A controller whose stored endpoint and key are already in place.
  Future<(AiBackendController, _FakeStore, _FakeClient)> connected({
    required String baseUrl,
    String? key,
  }) async {
    final store = _FakeStore(
      endpoint: CloudEndpoint(baseUrl: baseUrl, model: 'llama3.1:8b'),
      key: key,
    );
    final client = _FakeClient();
    final controller = AiBackendController(store: store, client: client);
    // _load() is started in the constructor and not awaited there.
    while (!controller.loaded) {
      await Future<void>.delayed(Duration.zero);
    }
    return (controller, store, client);
  }

  group('moving to a different server', () {
    test('the old key is not sent to the new host', () async {
      final (controller, store, client) = await connected(
        baseUrl: 'https://api.openai.com/v1',
        key: 'sk-the-old-secret',
      );

      final ok = await controller.saveEndpoint(
        baseUrl: 'http://192.168.1.50:11434/v1',
        model: 'llama3.1:8b',
        // The key field left empty, which is the reported case.
      );

      expect(ok, isTrue);
      expect(client.wasCalled, isTrue);
      expect(
        client.sentKey,
        isNull,
        reason: 'The previous server\'s key reached a different host.',
      );
      // And it does not stay behind to be picked up by a later save.
      expect(store.key, isNull);
      expect(store.endpoint.hasKey, isFalse);
    });

    test('a key typed for the new host is the one used', () async {
      final (controller, store, client) = await connected(
        baseUrl: 'https://api.openai.com/v1',
        key: 'sk-the-old-secret',
      );

      await controller.saveEndpoint(
        baseUrl: 'https://ai.example.com/v1',
        model: 'gpt-oss',
        apiKey: 'sk-the-new-one',
      );

      expect(client.sentKey, 'sk-the-new-one');
      expect(store.key, 'sk-the-new-one');
    });

    test('a failed test leaves the old key alone', () async {
      // saveEndpoint promises that nothing is stored when the test fails.
      // Withholding the key from the request is the security fix; deleting
      // it is stored state, so a typo in the host must not cost someone the
      // key for the server they are still using.
      final (controller, store, client) = await connected(
        baseUrl: 'https://api.openai.com/v1',
        key: 'sk-the-old-secret',
      );
      client.refuse = true;

      final ok = await controller.saveEndpoint(
        baseUrl: 'http://192.168.1.99:11434/v1',
        model: 'llama3.1:8b',
      );

      expect(ok, isFalse);
      expect(client.sentKey, isNull, reason: 'still must not have been sent');
      expect(store.key, 'sk-the-old-secret');
      expect(store.endpoint.baseUrl, 'https://api.openai.com/v1');
    });
  });

  group('staying on the same server', () {
    test('changing only the model keeps the key', () async {
      final (controller, store, client) = await connected(
        baseUrl: 'https://ai.example.com/v1',
        key: 'sk-mine',
      );

      await controller.saveEndpoint(
        baseUrl: 'https://ai.example.com/v1',
        model: 'a-different-model',
      );

      expect(client.sentKey, 'sk-mine');
      expect(store.key, 'sk-mine');
      expect(store.endpoint.model, 'a-different-model');
    });

    test('clearing the key clears it', () async {
      final (controller, store, client) = await connected(
        baseUrl: 'https://ai.example.com/v1',
        key: 'sk-mine',
      );

      await controller.saveEndpoint(
        baseUrl: 'https://ai.example.com/v1',
        model: 'llama3.1:8b',
        clearKey: true,
      );

      expect(client.sentKey, isNull);
      expect(store.key, isNull);
    });
  });

  group('the notice', () {
    test('is due for a server never used, and not twice', () async {
      final (controller, store, _) = await connected(
        baseUrl: 'http://box.local:11434/v1',
      );

      expect(await controller.endpointNoticeDue(), isTrue);
      await controller.rememberEndpointNoticeShown();
      expect(await controller.endpointNoticeDue(), isFalse);
      expect(store.told, [endpointOrigin('http://box.local:11434/v1')]);
    });

    test('is due again once a different server is saved', () async {
      final (controller, _, _) = await connected(
        baseUrl: 'http://box.local:11434/v1',
      );
      await controller.rememberEndpointNoticeShown();
      expect(await controller.endpointNoticeDue(), isFalse);

      await controller.saveEndpoint(
        baseUrl: 'https://someone-elses-ai.example.com/v1',
        model: 'gpt-oss',
      );

      expect(
        await controller.endpointNoticeDue(),
        isTrue,
        reason: 'The vitals now go somewhere else, so say so again.',
      );
    });

    test('is not due when no endpoint is set up', () async {
      final (controller, _, _) = await connected(baseUrl: '');
      expect(await controller.endpointNoticeDue(), isFalse);
    });
  });
}

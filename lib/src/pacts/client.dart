import 'dart:convert';
import 'dart:io';

import 'models.dart';

class PactHttpRequest {
  const PactHttpRequest({
    required this.method,
    required this.url,
    required this.headers,
    this.body,
  });

  final String method;
  final Uri url;
  final Map<String, String> headers;
  final String? body;
}

class PactHttpResponse {
  const PactHttpResponse(this.status, this.body);
  final int status;
  final String body;
}

typedef PactTransport = Future<PactHttpResponse> Function(PactHttpRequest request);

typedef PactTokenReader = Future<String?> Function();
typedef PactTokenWriter = Future<void> Function({
  required String accessToken,
  String? refreshToken,
});

Future<PactHttpResponse> defaultPactTransport(PactHttpRequest req) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(req.method, req.url);
    request.followRedirects = false;
    req.headers.forEach(request.headers.set);
    final payload = req.body;
    if (payload != null) {
      final bytes = utf8.encode(payload);
      request.contentLength = bytes.length;
      request.add(bytes);
    }
    final response = await request.close();
    final body = await utf8.decodeStream(response);
    return PactHttpResponse(response.statusCode, body);
  } finally {
    client.close(force: true);
  }
}

/// Thin HTTP client for Phase 1 Pact endpoints. Auth is Bearer; 401 retries
/// once via POST /api/auth/refresh when a refresh token is available.
class PactClient {
  PactClient({
    required this.baseUrl,
    required this.readAccessToken,
    this.readRefreshToken,
    this.onTokens,
    PactTransport? transport,
  }) : _transport = transport ?? defaultPactTransport;

  final String baseUrl;
  final PactTokenReader readAccessToken;
  final PactTokenReader? readRefreshToken;
  final PactTokenWriter? onTokens;
  final PactTransport _transport;
  bool _refreshing = false;

  Future<PactUnlocks> unlocks() async {
    final json = await _json('GET', '/api/pacts/unlocks');
    return PactUnlocks.fromJson(json);
  }

  Future<List<PactSnapshot>> today() async {
    final json = await _json('GET', '/api/pacts/today');
    final rows = json['pacts'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((row) => PactSnapshot.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<PactSnapshot>> list(String filter) async {
    final json = await _json('GET', '/api/pacts', query: {'filter': filter});
    final rows = json['pacts'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((row) => PactSnapshot.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<PactSnapshot> getById(String id) async {
    final json = await _json('GET', '/api/pacts/$id');
    return PactSnapshot.fromJson(json);
  }

  Future<PactRecord> create(PactCreateInput input) async {
    final json = await _json('POST', '/api/pacts', body: input.toJson());
    final pact = json['pact'];
    if (pact is Map) return PactRecord.fromJson(Map<String, dynamic>.from(pact));
    return PactRecord.fromJson(json);
  }

  Future<PactMe> proof(
    String id, {
    required String date,
    required bool satisfied,
    String source = 'manual',
  }) async {
    final json = await _json('PUT', '/api/pacts/$id/proof', body: {
      'date': date,
      'satisfied': satisfied,
      'source': source,
    });
    final me = json['me'];
    if (me is Map) return PactMe.fromJson(Map<String, dynamic>.from(me));
    throw const PactException(502, 'proof_missing_progress');
  }

  Future<PactMe> freeze(String id, {String? date}) async {
    final json = await _json(
      'POST',
      '/api/pacts/$id/streak/freeze',
      body: {'date': ?date},
    );
    final me = json['me'];
    if (me is Map) return PactMe.fromJson(Map<String, dynamic>.from(me));
    throw const PactException(502, 'freeze_missing_progress');
  }

  Future<PactMe> restore(String id) async {
    final json = await _json('POST', '/api/pacts/$id/streak/restore');
    final me = json['me'];
    if (me is Map) return PactMe.fromJson(Map<String, dynamic>.from(me));
    throw const PactException(502, 'restore_missing_progress');
  }

  Future<void> cancel(String id) => _json('POST', '/api/pacts/$id/cancel');

  Future<void> leave(String id) => _json('POST', '/api/pacts/$id/leave');

  Future<void> start(String id) => _json('POST', '/api/pacts/$id/start');

  Future<List<PactProfile>> friends() async {
    final json = await _json('GET', '/api/friends');
    return pactRows(json['friends'], PactProfile.fromJson);
  }

  Future<PactFriendRequests> friendRequests() async {
    final json = await _json('GET', '/api/friends/requests');
    return PactFriendRequests.fromJson(json);
  }

  Future<void> sendFriendRequest({
    String? email,
    String? inviteCode,
    String? profileId,
  }) {
    return _json('POST', '/api/friends/requests', body: {
      'email': ?email,
      'inviteCode': ?inviteCode,
      'profileId': ?profileId,
    });
  }

  Future<void> respondFriendRequest(String id, String action) {
    return _json('POST', '/api/friends/requests/$id/respond', body: {'action': action});
  }

  Future<PactInviteCode> createFriendInvite({String role = 'friend', String? pactId}) async {
    final json = await _json('POST', '/api/friends/invites', body: {
      'role': role,
      'pactId': ?pactId,
    });
    return PactInviteCode.fromJson(json);
  }

  Future<PactJoinResult> join({String? shareCode, String? inviteCode}) async {
    final json = await _json('POST', '/api/pacts/join', body: {
      'shareCode': ?shareCode,
      'inviteCode': ?inviteCode,
    });
    return PactJoinResult.fromJson(json);
  }

  Future<void> inviteToPact(String pactId, List<String> profileIds) {
    return _json('POST', '/api/pacts/$pactId/invites', body: {'profileIds': profileIds});
  }

  Future<PactLeaderboard> leaderboard({String scope = 'friends'}) async {
    final json = await _json('GET', '/api/pacts/leaderboard', query: {'scope': scope});
    return PactLeaderboard.fromJson(json);
  }

  Future<List<PactFeedItem>> feed() async {
    final json = await _json('GET', '/api/pacts/feed');
    return pactRows(json['pacts'], PactFeedItem.fromJson);
  }

  Future<List<PactBackable>> backable() async {
    final json = await _json('GET', '/api/pacts/backable');
    return pactRows(json['candidates'], PactBackable.fromJson);
  }

  Future<void> backPact(
    String pactId, {
    required String participantId,
    String itemLabel = '',
    String message = '',
    String pledgeType = 'item',
  }) {
    return _json('POST', '/api/pacts/$pactId/backings', body: {
      'participantId': participantId,
      'pledgeType': pledgeType,
      'itemLabel': itemLabel,
      'message': message,
    });
  }

  Future<PactProgress> progress(String id) async {
    final json = await _json('GET', '/api/pacts/$id/progress');
    return PactProgress.fromJson(json);
  }

  Future<void> encourage(
    String pactId, {
    required String participantId,
    required String message,
  }) {
    return _json('POST', '/api/pacts/$pactId/encourage', body: {
      'participantId': participantId,
      'message': message,
    });
  }

  Future<PactSettlement> settlement(String pactId) async {
    final json = await _json('GET', '/api/pacts/$pactId/settlement');
    return PactSettlement.fromJson(json);
  }

  Future<bool> refreshSession() async {
    final refresh = await readRefreshToken?.call();
    if (refresh == null || refresh.isEmpty) return false;
    if (_refreshing) return false;
    _refreshing = true;
    try {
      final response = await _transport(
        PactHttpRequest(
          method: 'POST',
          url: _uri('/api/auth/refresh'),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'refreshToken': refresh}),
        ),
      );
      if (response.status < 200 || response.status >= 300) return false;
      final json = _decode(response.body);
      final access = json['accessToken']?.toString();
      if (access == null || access.isEmpty) return false;
      await onTokens?.call(
        accessToken: access,
        refreshToken: json['refreshToken']?.toString(),
      );
      return true;
    } finally {
      _refreshing = false;
    }
  }

  Future<Map<String, dynamic>> _json(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    Future<PactHttpResponse> send() async {
      final token = await readAccessToken();
      final headers = <String, String>{
        'Accept': 'application/json',
        if (body != null) 'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
      return _transport(
        PactHttpRequest(
          method: method,
          url: _uri(path, query),
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        ),
      );
    }

    var response = await send();
    if (response.status == 401 && await refreshSession()) {
      response = await send();
    }

    final json = _decode(response.body);
    if (response.status < 200 || response.status >= 300) {
      throw PactException(
        response.status,
        json['error']?.toString() ?? 'request_failed',
      );
    }
    return json;
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: query);
  }

  Map<String, dynamic> _decode(String body) {
    if (body.trim().isEmpty) return const {};
    final parsed = jsonDecode(body);
    if (parsed is Map<String, dynamic>) return parsed;
    if (parsed is Map) return Map<String, dynamic>.from(parsed);
    return const {};
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/env_config.dart';
import 'client.dart';
import 'models.dart';

const _accessKey = 'vyana_pact_access';
const _refreshKey = 'vyana_pact_refresh';

class PactTokenStore {
  PactTokenStore._();

  static String? _memoryAccess;
  static String? _memoryRefresh;

  static Future<String?> readAccess() async {
    if (_memoryAccess != null && _memoryAccess!.isNotEmpty)
      return _memoryAccess;
    final env = EnvConfig.seekNirvanaAccessToken;
    if (env.isNotEmpty) return env;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessKey);
  }

  static Future<String?> readRefresh() async {
    if (_memoryRefresh != null && _memoryRefresh!.isNotEmpty) {
      return _memoryRefresh;
    }
    final env = EnvConfig.seekNirvanaRefreshToken;
    if (env.isNotEmpty) return env;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshKey);
  }

  static Future<void> save({
    required String accessToken,
    String? refreshToken,
  }) async {
    _memoryAccess = accessToken;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      _memoryRefresh = refreshToken;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await prefs.setString(_refreshKey, refreshToken);
    }
  }

  static Future<void> clear() async {
    _memoryAccess = null;
    _memoryRefresh = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
  }
}

class PactState {
  const PactState({
    this.loading = true,
    this.busy = false,
    this.signedIn = false,
    this.error,
    this.unlocks,
    this.active = const [],
    this.unfinished = const [],
    this.past = const [],
    this.friends = const [],
    this.friendRequests = const PactFriendRequests(),
    this.feed = const [],
    this.backable = const [],
    this.backing = const [],
    this.friendsBoard,
    this.communities = const [],
    this.templates = const [],
    this.suggestions = const [],
  });

  final bool loading;
  final bool busy;
  final bool signedIn;
  final String? error;
  final PactUnlocks? unlocks;
  final List<PactSnapshot> active;
  final List<PactSnapshot> unfinished;
  final List<PactSnapshot> past;
  final List<PactProfile> friends;
  final PactFriendRequests friendRequests;
  final List<PactFeedItem> feed;
  final List<PactBackable> backable;
  final List<PactBackable> backing;
  final PactLeaderboard? friendsBoard;
  final List<PactCommunity> communities;
  final List<PactTemplate> templates;
  final List<PactSuggestion> suggestions;

  PactSnapshot? get primary => active.isEmpty ? null : active.first;

  int get circleInvites => communities.where((c) => c.isInvited).length;

  bool get ownsCircle =>
      communities.any((c) => c.isOwner && c.kind == 'circle');

  bool canBack(String pactId, String? participantId) {
    if (participantId == null || participantId.isEmpty) return false;
    return backable.any(
      (row) => row.pact.id == pactId && row.participantId == participantId,
    );
  }

  PactState copyWith({
    bool? loading,
    bool? busy,
    bool? signedIn,
    String? error,
    bool clearError = false,
    PactUnlocks? unlocks,
    List<PactSnapshot>? active,
    List<PactSnapshot>? unfinished,
    List<PactSnapshot>? past,
    List<PactProfile>? friends,
    PactFriendRequests? friendRequests,
    List<PactFeedItem>? feed,
    List<PactBackable>? backable,
    List<PactBackable>? backing,
    PactLeaderboard? friendsBoard,
    List<PactCommunity>? communities,
    List<PactTemplate>? templates,
    List<PactSuggestion>? suggestions,
  }) {
    return PactState(
      loading: loading ?? this.loading,
      busy: busy ?? this.busy,
      signedIn: signedIn ?? this.signedIn,
      error: clearError ? null : (error ?? this.error),
      unlocks: unlocks ?? this.unlocks,
      active: active ?? this.active,
      unfinished: unfinished ?? this.unfinished,
      past: past ?? this.past,
      friends: friends ?? this.friends,
      friendRequests: friendRequests ?? this.friendRequests,
      feed: feed ?? this.feed,
      backable: backable ?? this.backable,
      backing: backing ?? this.backing,
      friendsBoard: friendsBoard ?? this.friendsBoard,
      communities: communities ?? this.communities,
      templates: templates ?? this.templates,
      suggestions: suggestions ?? this.suggestions,
    );
  }
}

class PactController extends StateNotifier<PactState> {
  PactController(this._client) : super(const PactState()) {
    refresh();
  }

  final PactClient _client;

  Future<void> saveSession({
    required String accessToken,
    String? refreshToken,
  }) async {
    await PactTokenStore.save(
      accessToken: accessToken.trim(),
      refreshToken: refreshToken?.trim(),
    );
    await refresh();
  }

  Future<void> signOut() async {
    await PactTokenStore.clear();
    state = const PactState(loading: false);
  }

  Future<void> refresh() async {
    final signedIn = state.signedIn;
    state = state.copyWith(
      loading: !signedIn,
      busy: signedIn,
      clearError: true,
    );
    try {
      final access = await PactTokenStore.readAccess();
      final refreshToken = await PactTokenStore.readRefresh();
      if ((access == null || access.isEmpty) &&
          (refreshToken == null || refreshToken.isEmpty)) {
        state = const PactState(loading: false);
        return;
      }
      if ((access == null || access.isEmpty) && refreshToken != null) {
        final ok = await _client.refreshSession();
        if (!ok) {
          state = const PactState(loading: false);
          return;
        }
      }

      final unlocks = await _client.unlocks();
      final today = await _client.today();
      final unfinished = await _client.list('unfinished');
      final past = await _client.list('past');
      var friends = const <PactProfile>[];
      var friendRequests = const PactFriendRequests();
      var feed = const <PactFeedItem>[];
      var backable = const <PactBackable>[];
      var backing = const <PactBackable>[];
      PactLeaderboard? friendsBoard;
      var communities = const <PactCommunity>[];
      var templates = const <PactTemplate>[];
      var suggestions = const <PactSuggestion>[];
      try {
        friends = await _client.friends();
        friendRequests = await _client.friendRequests();
      } catch (_) {}
      try {
        feed = await _client.feed();
      } catch (_) {}
      try {
        backable = await _client.backable();
      } catch (_) {}
      try {
        backing = await _client.myBackings();
      } catch (_) {}
      try {
        friendsBoard = await _client.leaderboard(scope: 'friends');
      } catch (_) {}
      try {
        communities = await _client.communities();
      } catch (_) {}
      try {
        templates = await _client.templates();
      } catch (_) {}
      try {
        suggestions = await _client.suggested();
      } catch (_) {}
      final active = <PactSnapshot>[];
      for (final row in today) {
        if (!row.pact.isSocial) {
          active.add(row);
          continue;
        }
        try {
          final progress = await _client.progress(row.pact.id);
          active.add(
            row.copyWith(
              me: progress.me,
              others: progress.others,
              backings: progress.backings,
            ),
          );
        } catch (_) {
          active.add(row);
        }
      }
      state = PactState(
        loading: false,
        signedIn: true,
        unlocks: unlocks,
        active: active,
        unfinished: unfinished,
        past: past,
        friends: friends,
        friendRequests: friendRequests,
        feed: feed,
        backable: backable,
        backing: backing,
        friendsBoard: friendsBoard,
        communities: communities,
        templates: templates,
        suggestions: suggestions,
      );
    } on PactException catch (error) {
      if (error.unauthorized) {
        await PactTokenStore.clear();
        state = PactState(loading: false, error: pactErrorMessage(error.error));
        return;
      }
      state = state.copyWith(
        loading: false,
        error: pactErrorMessage(error.error),
      );
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Could not reach Seek Nirvana.',
      );
    }
  }

  Future<bool> create(
    PactCreateInput input, {
    List<String> invitees = const [],
  }) => _run(() async {
    final pact = await _client.create(input);
    if (invitees.isNotEmpty) {
      await _client.inviteToPact(pact.id, invitees);
    }
  });

  Future<bool> proveToday(PactSnapshot snapshot, {required bool satisfied}) {
    if (snapshot.today.isEmpty) return Future.value(false);
    return _run(() async {
      await _client.proof(
        snapshot.pact.id,
        date: snapshot.today,
        satisfied: satisfied,
      );
    });
  }

  Future<bool> freezeToday(PactSnapshot snapshot) {
    return _run(() async {
      await _client.freeze(snapshot.pact.id, date: snapshot.today);
    });
  }

  Future<bool> restoreStreak(PactSnapshot snapshot) {
    return _run(() async {
      await _client.restore(snapshot.pact.id);
    });
  }

  Future<bool> leaveActive(PactSnapshot snapshot) {
    return _run(() async {
      await _client.leave(snapshot.pact.id);
    });
  }

  Future<bool> joinPact({String? shareCode, String? inviteCode}) =>
      _run(() async {
        await _client.join(shareCode: shareCode, inviteCode: inviteCode);
      });

  Future<bool> addFriend({String? email, String? inviteCode}) => _run(() async {
    await _client.sendFriendRequest(email: email, inviteCode: inviteCode);
  });

  Future<bool> respondFriend(String id, String action) => _run(() async {
    await _client.respondFriendRequest(id, action);
  });

  Future<PactInviteCode?> mintFriendInvite() async {
    try {
      return await _client.createFriendInvite();
    } on PactException catch (error) {
      state = state.copyWith(error: pactErrorMessage(error.error));
      return null;
    }
  }

  Future<bool> encourage(
    PactSnapshot snapshot, {
    required String participantId,
    required String message,
  }) => _run(() async {
    await _client.encourage(
      snapshot.pact.id,
      participantId: participantId,
      message: message,
    );
  });

  Future<bool> inviteFriends(String pactId, List<String> profileIds) =>
      _run(() async {
        await _client.inviteToPact(pactId, profileIds);
      });

  Future<bool> backSomeone({
    required String pactId,
    required String participantId,
    required String itemLabel,
    String message = '',
  }) => _run(() async {
    await _client.backPact(
      pactId,
      participantId: participantId,
      itemLabel: itemLabel,
      message: message,
    );
  });

  Future<bool> createCircle({required String name}) => _run(() async {
    await _client.createCommunity(name: name);
  });

  Future<PactCommunity?> loadCircle(String id) async {
    try {
      return await _client.community(id);
    } on PactException catch (error) {
      state = state.copyWith(error: pactErrorMessage(error.error));
      return null;
    } catch (_) {
      state = state.copyWith(error: 'Could not reach Seek Nirvana.');
      return null;
    }
  }

  Future<bool> inviteToCircle(String id, List<String> profileIds) =>
      _run(() async {
        await _client.inviteToCommunity(id, profileIds);
      });

  Future<bool> joinCircle(String id) => _run(() async {
    await _client.joinCommunity(id);
  });

  Future<bool> leaveCircle(String id) => _run(() async {
    await _client.leaveCommunity(id);
  });

  Future<PactRecord?> startCirclePact(String id, PactCreateInput input) async {
    if (state.busy) return null;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final pact = await _client.startCommunityPact(id, input);
      await refresh();
      return pact;
    } on PactException catch (error) {
      state = state.copyWith(
        busy: false,
        loading: false,
        error: pactErrorMessage(error.error),
      );
      return null;
    } catch (_) {
      state = state.copyWith(
        busy: false,
        loading: false,
        error: 'Could not reach Seek Nirvana.',
      );
      return null;
    }
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (state.busy) return false;
    state = state.copyWith(busy: true, clearError: true);
    try {
      await action();
      await refresh();
      return true;
    } on PactException catch (error) {
      state = state.copyWith(
        busy: false,
        loading: false,
        error: pactErrorMessage(error.error),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        busy: false,
        loading: false,
        error: 'Could not reach Seek Nirvana.',
      );
      return false;
    }
  }
}

final pactClientProvider = Provider<PactClient>((ref) {
  return PactClient(
    baseUrl: EnvConfig.seekNirvanaApiUrl,
    readAccessToken: PactTokenStore.readAccess,
    readRefreshToken: PactTokenStore.readRefresh,
    onTokens: PactTokenStore.save,
  );
});

final pactControllerProvider = StateNotifierProvider<PactController, PactState>(
  (ref) {
    return PactController(ref.watch(pactClientProvider));
  },
);

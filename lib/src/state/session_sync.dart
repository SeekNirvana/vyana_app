part of '../../main.dart';

/// Opt-in cloud sync for sessions, route points and waveform-heavy data.
/// Off by default to preserve on-device sovereignty. The real uploader plugs
/// in behind [SessionSyncService]; until then enabling it only records intent
/// (nothing leaves the device).
abstract class SessionSyncService {
  Future<void> queue(String sessionId);
}

class NoopSessionSyncService implements SessionSyncService {
  const NoopSessionSyncService();
  @override
  Future<void> queue(String sessionId) async {
    debugPrint('SESSION_SYNC queued $sessionId (no backend wired yet)');
  }
}

final sessionSyncServiceProvider =
    Provider<SessionSyncService>((ref) => const NoopSessionSyncService());

class SessionSyncController extends StateNotifier<bool> {
  SessionSyncController() : super(false) {
    _load();
  }

  static const _key = 'vyana_session_sync_enabled';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

final sessionSyncEnabledProvider =
    StateNotifierProvider<SessionSyncController, bool>(
  (ref) => SessionSyncController(),
);

part of '../../main.dart';

/// Push alerts — the half of "notifications" that is not plumbing. Three sets:
///
/// * **Ring & data** (offline, not synced in 24h, battery low once at 15%) —
///   silence warnings, on by default: the data is being lost *now* and
///   cannot be delivered later.
/// * **Health alerts** (HR outside the user's band, SpO₂ drop) — on.
/// * **Nudges** (sleep summary ready, practice reminder, streak about to
///   break) — off by default; they are what makes an app feel needy.
///
/// Rule: push only when the app cannot tell you later.
class NotificationPrefs {
  const NotificationPrefs({
    this.ringAndData = true,
    this.healthAlerts = true,
    this.nudges = false,
  });

  final bool ringAndData;
  final bool healthAlerts;
  final bool nudges;

  int get onCount => (ringAndData ? 1 : 0) + (healthAlerts ? 1 : 0) + (nudges ? 1 : 0);

  NotificationPrefs copyWith({
    bool? ringAndData,
    bool? healthAlerts,
    bool? nudges,
  }) =>
      NotificationPrefs(
        ringAndData: ringAndData ?? this.ringAndData,
        healthAlerts: healthAlerts ?? this.healthAlerts,
        nudges: nudges ?? this.nudges,
      );
}

class NotificationPrefsController extends StateNotifier<NotificationPrefs> {
  NotificationPrefsController() : super(const NotificationPrefs()) {
    unawaited(_load());
  }

  static const _kRing = 'vyana.notify.ring_and_data';
  static const _kHealth = 'vyana.notify.health_alerts';
  static const _kNudges = 'vyana.notify.nudges';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    state = NotificationPrefs(
      ringAndData: prefs.getBool(_kRing) ?? true,
      healthAlerts: prefs.getBool(_kHealth) ?? true,
      nudges: prefs.getBool(_kNudges) ?? false,
    );
  }

  Future<void> setRingAndData(bool on) async {
    state = state.copyWith(ringAndData: on);
    await _save(_kRing, on);
  }

  Future<void> setHealthAlerts(bool on) async {
    state = state.copyWith(healthAlerts: on);
    await _save(_kHealth, on);
  }

  Future<void> setNudges(bool on) async {
    state = state.copyWith(nudges: on);
    await _save(_kNudges, on);
  }

  Future<void> _save(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    if (value) await VitalsNotificationService.instance.requestPermissions();
  }
}

final notificationPrefsProvider =
    StateNotifierProvider<NotificationPrefsController, NotificationPrefs>(
  (_) => NotificationPrefsController(),
);

/// A ring that has not handed over data in this long invalidates the day.
const Duration kRingStaleAfter = Duration(hours: 24);

/// When the ring last handed data over — the newest sync we know of, from a
/// live pull or the hydrated cache.
DateTime? ringLastSyncedAt(RingController c) => c.lastSyncedAt;

/// Stale = not synced within [kRingStaleAfter], or nothing synced at all while
/// a ring is paired.
bool ringIsStale(RingController c) {
  if (!c.hasRingContext) return false;
  final at = ringLastSyncedAt(c);
  // Unknown is not stale: a ring that has never synced has nothing to be
  // stale about, and an old cache with no timestamp must not raise a false
  // alarm on first launch after an upgrade.
  if (at == null) return false;
  return DateTime.now().difference(at) > kRingStaleAfter;
}

/// A paired ring that has been out of reach long enough to matter — not the
/// few seconds of a passive reconnect, which would flash the banner on and
/// off every time the ring drops.
const Duration kRingOfflineAfter = Duration(minutes: 10);

bool ringIsOffline(RingController c) {
  if (c.pairedRing == null || c.isConnected) return false;
  final confirmed = c.lastConnectionConfirmedAt;
  if (confirmed == null) {
    // Never connected this launch: offline once the app has been up a while.
    return c.hasRingContext && !c.isConnecting && ringIsStale(c);
  }
  return DateTime.now().difference(confirmed) > kRingOfflineAfter;
}

/// Watches the ring and fires the push-worthy alerts, each at most once per
/// episode. Copy names the consequence, not the event.
class RingAlertService {
  RingAlertService(this._ref);

  final Ref _ref;
  bool _lowBatteryFired = false;
  bool _staleFired = false;
  bool _offlineFired = false;
  DateTime? _lastHealthAlert;
  DateTime? _wentOffline;

  Future<void> evaluate(RingController c) async {
    if (!c.hasRingContext) return;
    final prefs = _ref.read(notificationPrefsProvider);
    final notify = VitalsNotificationService.instance;

    if (prefs.ringAndData) {
      final battery = c.batteryPercent;
      if (battery != null && battery > 0 && battery <= 15) {
        if (!_lowBatteryFired) {
          _lowBatteryFired = true;
          await notify.showAlert(
            id: 4301,
            title: 'Your ring is at $battery%',
            body: 'Charge it before tonight or there will be no sleep data '
                'in the morning.',
          );
        }
      } else if (battery != null && battery > 30) {
        _lowBatteryFired = false;
      }

      if (ringIsStale(c)) {
        if (!_staleFired) {
          _staleFired = true;
          final at = ringLastSyncedAt(c);
          final when = at == null ? 'a while' : _sinceLabel(at);
          await notify.showAlert(
            id: 4302,
            title: 'Your ring has not synced since $when',
            body: "Today's readiness is missing. Open Vyana with the ring "
                'nearby to catch up.',
          );
        }
      } else {
        _staleFired = false;
      }

      if (!c.isConnected && c.pairedRing != null) {
        _wentOffline ??= DateTime.now();
        final offlineFor = DateTime.now().difference(_wentOffline!);
        if (!_offlineFired && offlineFor > const Duration(hours: 2)) {
          _offlineFired = true;
          await notify.showAlert(
            id: 4303,
            title: 'Nothing is reading you right now',
            body: 'Your ring has been out of reach for two hours — the '
                'readings it takes now are not reaching your phone.',
          );
        }
      } else {
        _wentOffline = null;
        _offlineFired = false;
      }
    }

    if (prefs.healthAlerts) {
      final since = _lastHealthAlert;
      if (since == null ||
          DateTime.now().difference(since) > const Duration(hours: 6)) {
        final profile = _ref.read(userProfileProvider).valueOrNull;
        final band = restingHrBand(
          TrainingFrequencyX.fromName(profile?.trainingFrequency),
        );
        final hr = c.vitals.heartRate;
        final spo2 = c.vitals.bloodOxygen;
        if (hr != null && hr > 0 && hr > band.high + 20) {
          _lastHealthAlert = DateTime.now();
          await notify.showAlert(
            id: 4304,
            title: 'Resting heart rate is $hr bpm',
            body: 'That is well above your ${band.low.round()}–'
                '${band.high.round()} band. If you are at rest, it is worth '
                'a moment to sit and breathe.',
          );
        } else if (spo2 != null && spo2 > 0 && spo2 < 92) {
          _lastHealthAlert = DateTime.now();
          await notify.showAlert(
            id: 4305,
            title: 'Blood oxygen read $spo2%',
            body: 'Lower than usual. Re-seat the ring and take another '
                'reading; if it stays low, do not ignore it.',
          );
        }
      }
    }
  }

  static String _sinceLabel(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inDays >= 1) {
      const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return days[at.weekday - 1];
    }
    return '${diff.inHours} hours ago';
  }
}

final ringAlertServiceProvider =
    Provider<RingAlertService>((ref) => RingAlertService(ref));

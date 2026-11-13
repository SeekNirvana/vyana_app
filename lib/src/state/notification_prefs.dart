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

/// Stale = not synced within [kRingStaleAfter], or a paired ring that has
/// never handed data over on this phone at all.
bool ringIsStale(RingController c) {
  if (!c.hasRingContext) return false;
  final at = ringLastSyncedAt(c);
  if (at == null) {
    // The cache always stamps a sync time, so no timestamp means nothing has
    // ever been pulled here (fresh install, new phone). A paired ring with no
    // data is exactly the case that needs a SYNC affordance; a ring that only
    // exists as cached history from before pairing has nothing to be stale
    // about yet.
    return c.pairedRing != null;
  }
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
    // Never connected this launch. Once a reconnect attempt has actually
    // failed the ring is out of reach, not "still connecting" — say so
    // rather than showing a cached battery for a ring we have not spoken to.
    if (c.isConnecting) return false;
    return c.reconnectFailedThisLaunch || ringIsStale(c);
  }
  return DateTime.now().difference(confirmed) > kRingOfflineAfter;
}

/// Everything the ring alerts need, flattened so it can be written by the
/// main isolate and read by the foreground-service isolate (bug 44).
///
/// The service isolate has no Riverpod container and no BLE connection, so it
/// cannot build a [RingController]. Alerts used to be evaluated only on the
/// main isolate, reached through `sendDataToMain` — and while the app was
/// closed the main isolate is suspended, so those ticks were queued and ran
/// on resume. That is exactly the reported symptom: the low-battery alert for
/// a ring that died overnight arrived when the app was opened.
class RingAlertSnapshot {
  const RingAlertSnapshot({
    required this.at,
    required this.hasRingContext,
    required this.paired,
    required this.connected,
    required this.batteryPercent,
    required this.batteryReadAt,
    required this.lastSyncedAt,
    required this.lastConnectionConfirmedAt,
    required this.restingHr,
    required this.spo2,
    required this.hrBandLow,
    required this.hrBandHigh,
    this.charging = false,
  });

  factory RingAlertSnapshot.from(RingController c, {TrainingFrequency? band}) {
    final hrBand = restingHrBand(band);
    return RingAlertSnapshot(
      at: DateTime.now(),
      hasRingContext: c.hasRingContext,
      paired: c.pairedRing != null,
      connected: c.isConnected,
      batteryPercent: c.batteryPercent,
      batteryReadAt: c.batteryReadAt,
      lastSyncedAt: ringLastSyncedAt(c),
      lastConnectionConfirmedAt: c.lastConnectionConfirmedAt,
      restingHr: HomeDashboard.from(c).restingHr,
      spo2: c.vitals.bloodOxygen,
      hrBandLow: hrBand.low,
      hrBandHigh: hrBand.high,
      charging: c.wasChargingWhenLastSeen,
    );
  }

  final DateTime at;
  final bool hasRingContext;
  final bool paired;
  final bool connected;
  final int? batteryPercent;
  final DateTime? batteryReadAt;
  final DateTime? lastSyncedAt;
  final DateTime? lastConnectionConfirmedAt;
  final int? restingHr;
  final int? spo2;
  final double hrBandLow;
  final double hrBandHigh;

  /// Bug 43: the newest status says charging, connected or not. The ring is
  /// off the finger on purpose, so neither a battery reading mid-charge nor
  /// two hours out of reach is news.
  final bool charging;

  /// Bug 44 (3): a cached percentage from hours ago is not a reading. It can
  /// neither raise the alert nor clear one that is already standing.
  bool get batteryIsCurrent {
    final read = batteryReadAt;
    if (read == null) return false;
    return DateTime.now().difference(read) <= kBatteryFreshFor;
  }

  /// Stale = not synced within [kRingStaleAfter], or a paired ring that has
  /// never handed data over at all. Mirrors [ringIsStale] on the snapshot.
  bool get isStale {
    if (!hasRingContext) return false;
    final at = lastSyncedAt;
    if (at == null) return paired;
    return DateTime.now().difference(at) > kRingStaleAfter;
  }

  Map<String, Object?> toJson() => {
        'at': at.millisecondsSinceEpoch,
        'hasRingContext': hasRingContext,
        'paired': paired,
        'connected': connected,
        'batteryPercent': batteryPercent,
        'batteryReadAt': batteryReadAt?.millisecondsSinceEpoch,
        'lastSyncedAt': lastSyncedAt?.millisecondsSinceEpoch,
        'lastConnectionConfirmedAt':
            lastConnectionConfirmedAt?.millisecondsSinceEpoch,
        'restingHr': restingHr,
        'spo2': spo2,
        'hrBandLow': hrBandLow,
        'hrBandHigh': hrBandHigh,
        'charging': charging,
      };

  static RingAlertSnapshot? fromJson(Map<String, Object?> json) {
    DateTime? time(Object? v) => v is int
        ? DateTime.fromMillisecondsSinceEpoch(v)
        : null;
    final at = time(json['at']);
    if (at == null) return null;
    return RingAlertSnapshot(
      at: at,
      hasRingContext: json['hasRingContext'] == true,
      paired: json['paired'] == true,
      connected: json['connected'] == true,
      batteryPercent: json['batteryPercent'] as int?,
      batteryReadAt: time(json['batteryReadAt']),
      lastSyncedAt: time(json['lastSyncedAt']),
      lastConnectionConfirmedAt: time(json['lastConnectionConfirmedAt']),
      restingHr: json['restingHr'] as int?,
      spo2: json['spo2'] as int?,
      hrBandLow: (json['hrBandLow'] as num?)?.toDouble() ?? 50,
      hrBandHigh: (json['hrBandHigh'] as num?)?.toDouble() ?? 80,
      charging: json['charging'] == true,
    );
  }

  static const _key = 'vyana.ring.alert.snapshot';

  Future<void> save() async {
    try {
      final store = await SharedPreferences.getInstance();
      await store.setString(_key, jsonEncode(toJson()));
    } on Object catch (error) {
      debugPrint('Ring alert snapshot save failed: $error');
    }
  }

  /// Reads the snapshot the main isolate last wrote. Safe in either isolate.
  static Future<RingAlertSnapshot?> load() async {
    try {
      final store = await SharedPreferences.getInstance();
      final raw = store.getString(_key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return fromJson(decoded.cast<String, Object?>());
    } on Object catch (error) {
      debugPrint('Ring alert snapshot load failed: $error');
      return null;
    }
  }
}

/// A battery reading older than this says nothing about the ring now.
const Duration kBatteryFreshFor = Duration(minutes: 30);

/// Bug 44 (4): the evening check. Below this at bedtime the ring will not
/// survive the night, so there is still time to do something about it.
///
/// A night costs roughly 10–15%; 30% leaves margin. Replace it with the
/// measured overnight drain once logged battery-at-bedtime / battery-on-waking
/// pairs from real rings say what it actually is.
const int kOvernightBatteryMin = 30;

/// When "charge it before tonight" is worth saying — late enough that the
/// reading reflects the day, early enough to act on.
const int kEveningBatteryCheckFromHour = 19;
const int kEveningBatteryCheckToHour = 22;

/// The flat-battery floor, kept as a fallback outside the evening window.
const int kLowBatteryPercent = 15;

/// When the next evening battery check falls due. Bug 47: iOS gives no timer
/// in the background, so the alert has to be handed to the OS in advance —
/// which means knowing the moment it should land.
DateTime nextEveningBatteryCheck(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  if (now.hour < kEveningBatteryCheckFromHour) {
    return today.add(const Duration(hours: kEveningBatteryCheckFromHour));
  }
  if (now.hour < kEveningBatteryCheckToHour) {
    // Already inside the window: there is nothing to wait for.
    return now.add(const Duration(minutes: 1));
  }
  return today
      .add(const Duration(days: 1))
      .add(const Duration(hours: kEveningBatteryCheckFromHour));
}

/// Above this a low-battery episode is over and the alert may fire again.
const int kBatteryRecoveredPercent = 30;

/// Alert state that must outlive the process: the app is restarted far more
/// often than a ring stays offline for two hours, and an alert that resets on
/// every launch never fires. Shared by both isolates, so neither can fire an
/// alert the other has already sent.
class _AlertKeys {
  static const offlineSince = 'vyana.ring.alert.offlineSince';
  static const offlineFired = 'vyana.ring.alert.offlineFired';
  static const lowBatteryFiredAt = 'vyana.ring.alert.lowBatteryFiredAt';
  static const overnightBatteryFiredOn =
      'vyana.ring.alert.overnightBatteryFiredOn';
  static const staleFired = 'vyana.ring.alert.staleFired';
  static const healthFiredAt = 'vyana.ring.alert.healthFiredAt';
}

/// Out of reach this long before the offline alert fires.
const Duration kOfflineAlertAfter = Duration(hours: 2);

/// Low-battery alert repeats at most this often while the ring stays low.
const Duration kLowBatteryRepeatAfter = Duration(hours: 12);

/// Health alerts are at most this often, whatever the readings do.
const Duration kHealthAlertRepeatAfter = Duration(hours: 6);

int _dayStamp(DateTime at) => at.year * 10000 + at.month * 100 + at.day;

/// Fires the push-worthy alerts for [snapshot], at most once per episode.
/// Copy names the consequence, not the event.
///
/// Bug 44 (2): deliberately free of Riverpod, the ring controller and the
/// BLE stack, so the foreground-service isolate can run it on every heartbeat
/// without waking the UI isolate. It needs SharedPreferences and the
/// notifications plugin, both of which work in a background isolate.
Future<void> evaluateRingAlerts({
  required RingAlertSnapshot snapshot,
  required NotificationPrefs prefs,
  required SharedPreferences store,
  required VitalsNotificationService notify,
  DateTime? now,
}) async {
  if (!snapshot.hasRingContext) return;
  final at = now ?? DateTime.now();
  // Both isolates evaluate and both write the "already fired" flags, and
  // SharedPreferences caches per isolate. Without this reload each isolate
  // would work from its own stale copy and send the same alert twice.
  try {
    await store.reload();
  } on Object catch (_) {
    // A failed reload only risks a duplicate alert, never a missing one.
  }

  if (prefs.ringAndData) {
    await _evaluateBattery(snapshot, store, notify, at);
    await _evaluateStaleSync(snapshot, store, notify);
    await _evaluateOffline(snapshot, store, notify, at);
  }

  if (prefs.healthAlerts) {
    await _evaluateHealth(snapshot, store, notify, at);
  }
}

Future<void> _evaluateBattery(
  RingAlertSnapshot s,
  SharedPreferences store,
  VitalsNotificationService notify,
  DateTime at,
) async {
  // Bug 43: on the charger the battery is on its way up, by choice. Nothing
  // to warn about, and nothing to clear either — the percentage mid-charge
  // is not the percentage the user will wear.
  if (s.charging) return;
  final battery = s.batteryPercent;
  // Bug 44 (3): no current reading, no decision — neither fire nor clear.
  if (battery == null || battery <= 0 || !s.batteryIsCurrent) return;

  if (battery > kBatteryRecoveredPercent) {
    await store.remove(_AlertKeys.lowBatteryFiredAt);
    await store.remove(_AlertKeys.overnightBatteryFiredOn);
    return;
  }

  final inEvening = at.hour >= kEveningBatteryCheckFromHour &&
      at.hour < kEveningBatteryCheckToHour;
  if (inEvening) {
    // Once a night: the point is to catch it while there is time to charge.
    if (battery >= kOvernightBatteryMin) return;
    if (store.getInt(_AlertKeys.overnightBatteryFiredOn) == _dayStamp(at)) {
      return;
    }
    await store.setInt(_AlertKeys.overnightBatteryFiredOn, _dayStamp(at));
    await notify.showAlert(
      id: 4301,
      title: 'Your ring is at $battery%',
      body: 'That will not last the night. Charge it before bed or there '
          'will be no sleep data in the morning.',
    );
    return;
  }

  // Outside the evening window the flat-battery floor still matters — but
  // nothing is said after 22:00, when there is nothing to be done about it.
  if (at.hour >= kEveningBatteryCheckToHour) return;
  if (battery > kLowBatteryPercent) return;
  final firedAtMs = store.getInt(_AlertKeys.lowBatteryFiredAt);
  final firedAt = firedAtMs == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(firedAtMs);
  if (firedAt != null && at.difference(firedAt) <= kLowBatteryRepeatAfter) {
    return;
  }
  await store.setInt(_AlertKeys.lowBatteryFiredAt, at.millisecondsSinceEpoch);
  await notify.showAlert(
    id: 4301,
    title: 'Your ring is at $battery%',
    // Deliberately not "before tonight": this one can fire at any hour of
    // the day, and a message about tonight at 09:00 reads as a mistake.
    body: 'Charge it soon — this low it stops recording.',
  );
}

Future<void> _evaluateStaleSync(
  RingAlertSnapshot s,
  SharedPreferences store,
  VitalsNotificationService notify,
) async {
  final lastSync = s.lastSyncedAt;
  // A ring that has never synced here gets the SYNC pill and banner, not a
  // push — there is no "since when" to report.
  if (!s.isStale || lastSync == null) {
    await store.remove(_AlertKeys.staleFired);
    return;
  }
  if (store.getBool(_AlertKeys.staleFired) ?? false) return;
  await store.setBool(_AlertKeys.staleFired, true);
  await notify.showAlert(
    id: 4302,
    title: 'Your ring has not synced since ${_sinceLabel(lastSync)}',
    body: "Today's readiness is missing. Open Vyana with the ring "
        'nearby to catch up.',
  );
}

Future<void> _evaluateOffline(
  RingAlertSnapshot s,
  SharedPreferences store,
  VitalsNotificationService notify,
  DateTime at,
) async {
  if (s.connected) {
    await store.remove(_AlertKeys.offlineSince);
    await store.remove(_AlertKeys.offlineFired);
    return;
  }
  if (!s.paired) return;
  // Bug 43: a ring taken off and put on charge is out of reach on purpose.
  if (s.charging) return;
  final sinceMs = store.getInt(_AlertKeys.offlineSince);
  if (sinceMs == null) {
    // Start the clock from the last confirmed connection when we know it,
    // else from now.
    final start = s.lastConnectionConfirmedAt ?? at;
    await store.setInt(_AlertKeys.offlineSince, start.millisecondsSinceEpoch);
    return;
  }
  if (store.getBool(_AlertKeys.offlineFired) ?? false) return;
  final since = DateTime.fromMillisecondsSinceEpoch(sinceMs);
  if (at.difference(since) <= kOfflineAlertAfter) return;
  await store.setBool(_AlertKeys.offlineFired, true);
  await notify.showAlert(
    id: 4303,
    title: 'Nothing is reading you right now',
    body: 'Your ring has been out of reach for two hours — the '
        'readings it takes now are not reaching your phone.',
  );
}

Future<void> _evaluateHealth(
  RingAlertSnapshot s,
  SharedPreferences store,
  VitalsNotificationService notify,
  DateTime at,
) async {
  final firedMs = store.getInt(_AlertKeys.healthFiredAt);
  if (firedMs != null) {
    final fired = DateTime.fromMillisecondsSinceEpoch(firedMs);
    if (at.difference(fired) <= kHealthAlertRepeatAfter) return;
  }
  // Bug 11: this used to read `vitals.heartRate`, the newest live value, so
  // the alert fired after any workout — "Resting heart rate is 101 bpm"
  // about a heart rate that was not resting. It reads the day's resting HR,
  // which is the only thing the band applies to.
  final hr = s.restingHr;
  final spo2 = s.spo2;
  if (hr != null && hr > 0 && hr > s.hrBandHigh + kSafetyRestingHrMargin) {
    await store.setInt(_AlertKeys.healthFiredAt, at.millisecondsSinceEpoch);
    await notify.showAlert(
      id: 4304,
      title: 'Resting heart rate is $hr bpm',
      body: 'That is well above your ${s.hrBandLow.round()}–'
          '${s.hrBandHigh.round()} band. If you are at rest, it is worth '
          'a moment to sit and breathe.',
    );
  } else if (spo2 != null && spo2 > 0 && spo2 < 92) {
    await store.setInt(_AlertKeys.healthFiredAt, at.millisecondsSinceEpoch);
    await notify.showAlert(
      id: 4305,
      title: 'Blood oxygen read $spo2%',
      body: 'Lower than usual. Re-seat the ring and take another '
          'reading; if it stays low, do not ignore it.',
    );
  }
}

String _sinceLabel(DateTime at) {
  final diff = DateTime.now().difference(at);
  if (diff.inDays >= 1) {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
      'Sunday',
    ];
    return days[at.weekday - 1];
  }
  return '${diff.inHours} hours ago';
}

/// Reads the notification switches straight from storage, for the isolate
/// that has no provider container.
Future<NotificationPrefs> loadNotificationPrefs(
  SharedPreferences store,
) async =>
    NotificationPrefs(
      ringAndData: store.getBool(NotificationPrefsController._kRing) ?? true,
      healthAlerts: store.getBool(NotificationPrefsController._kHealth) ?? true,
      nudges: store.getBool(NotificationPrefsController._kNudges) ?? false,
    );

/// Main-isolate entry point: builds the snapshot from the live controller,
/// stores it for the service isolate, and evaluates right away.
class RingAlertService {
  RingAlertService(this._ref);

  final Ref _ref;

  Future<void> evaluate(RingController c) async {
    if (!c.hasRingContext) return;
    final profile = _ref.read(userProfileProvider).valueOrNull;
    final snapshot = RingAlertSnapshot.from(
      c,
      band: TrainingFrequencyX.fromName(profile?.trainingFrequency),
    );
    await snapshot.save();
    await evaluateRingAlerts(
      snapshot: snapshot,
      prefs: _ref.read(notificationPrefsProvider),
      store: await SharedPreferences.getInstance(),
      notify: VitalsNotificationService.instance,
    );
  }
}

final ringAlertServiceProvider =
    Provider<RingAlertService>((ref) => RingAlertService(ref));

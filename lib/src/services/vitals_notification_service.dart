import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../wellness/wellness_state.dart';

/// Local notifications for the hands-off "Monitor all vitals" flow: the user
/// taps once, sets the phone aside, and gets pinged with their state of being
/// when the run finishes. Single channel, no scheduling — fire-and-forget.
class VitalsNotificationService {
  VitalsNotificationService._();

  static final VitalsNotificationService instance =
      VitalsNotificationService._();

  static const _channelId = 'vyana_vitals';
  static const _channelName = 'Vitals monitoring';
  static const _channelDescription =
      'Tells you when a health check has finished.';
  static const _progressId = 4201;
  static const _resultId = 4202;

  static const _practiceEndId = 4205;
  static const _staleRingId = 4302;
  static const _ringOfflineId = 4303;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _tzReady = false;

  /// Safe to call multiple times; initialises the plugin and creates the
  /// Android channel on first use.
  Future<void> ensureInitialized() async {
    if (_ready) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: darwin),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDescription,
              importance: Importance.high,
            ),
          );
      _ready = true;
    } on Object catch (error) {
      debugPrint('[VitalsNotificationService] init failed: $error');
    }
  }

  /// Loads the timezone database and the device's zone, which `zonedSchedule`
  /// needs. Separate from [ensureInitialized] because only scheduling pays
  /// this cost.
  Future<bool> _ensureTimezone() async {
    if (_tzReady) return true;
    try {
      tzdata.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
      _tzReady = true;
    } on Object catch (error) {
      debugPrint('[VitalsNotificationService] timezone init failed: $error');
    }
    return _tzReady;
  }

  NotificationDetails _alertDetails(String body) => NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(),
      );

  /// Schedules [title]/[body] for [at]. Delivered by the OS, so it arrives
  /// even if the app has been swiped away or killed — which is the whole
  /// point for the practice bell and the 24-hour stale-ring alert.
  Future<void> _scheduleAt({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    await ensureInitialized();
    if (!_ready) return;
    if (!await _ensureTimezone()) return;
    if (!at.isAfter(DateTime.now())) return;
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(at, tz.local),
        _alertDetails(body),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } on Object catch (error) {
      debugPrint('[VitalsNotificationService] schedule failed: $error');
    }
  }

  /// Bug 12 (3): the end of a timed practice, scheduled at start so it still
  /// fires with the phone locked and face down.
  Future<void> schedulePracticeEnd({
    required DateTime at,
    required String activityName,
  }) async {
    await cancelPracticeEnd();
    await _scheduleAt(
      id: _practiceEndId,
      at: at,
      title: "Time's up",
      body: 'Your $activityName is complete.',
    );
  }

  Future<void> cancelPracticeEnd() async {
    try {
      await _plugin.cancel(_practiceEndId);
    } on Object catch (_) {}
  }

  /// Bug 6 (2): the stale-ring alert, scheduled for lastSync + 24h and
  /// re-scheduled on every successful sync, so it fires even when the app
  /// never runs in between.
  Future<void> scheduleStaleRingAlert(DateTime lastSync) async {
    await cancelStaleRingAlert();
    await _scheduleAt(
      id: _staleRingId,
      at: lastSync.add(const Duration(hours: 24)),
      title: 'Your ring has not synced for a day',
      body: "Today's readiness is missing. Open Vyana with the ring nearby "
          'to catch up.',
    );
  }

  Future<void> cancelStaleRingAlert() async {
    try {
      await _plugin.cancel(_staleRingId);
    } on Object catch (_) {}
  }

  /// Bug 6: the two-hour "nothing is reading you" alert, handed to the OS at
  /// the moment the ring was last confirmed connected.
  ///
  /// This is deliberately a scheduled notification rather than a background
  /// task: the alert is purely a function of elapsed time since a known
  /// moment, so the OS can deliver it with the app dead, on both platforms,
  /// with no isolate that would have no Bluetooth connection to inspect
  /// anyway. Cancelled the moment the ring is confirmed back.
  Future<void> scheduleRingOfflineAlert(DateTime lastConnected) async {
    await cancelRingOfflineAlert();
    await _scheduleAt(
      id: _ringOfflineId,
      at: lastConnected.add(const Duration(hours: 2)),
      title: 'Nothing is reading you right now',
      body: 'Your ring has been out of reach for two hours — the readings it '
          'takes now are not reaching your phone.',
    );
  }

  Future<void> cancelRingOfflineAlert() async {
    try {
      await _plugin.cancel(_ringOfflineId);
    } on Object catch (_) {}
  }

  /// §5 "Forgotten session": the app cannot tell you later that a session is
  /// still recording, so it says so while it still matters. Once per session.
  Future<void> showForgottenSession({
    required String activityName,
    int? settledMinutesAgo,
  }) async {
    final body = settledMinutesAgo == null
        ? 'It has been running longer than usual.'
        : 'Your heart rate settled $settledMinutesAgo minutes ago.';
    await showAlert(
      id: 4206,
      title: 'Still on your ${activityName.toLowerCase()}?',
      body: body,
    );
  }

  /// Ask the OS for permission (Android 13+ and iOS). Best-effort — a denied
  /// permission just means no banner; the in-app summary still shows.
  Future<void> requestPermissions() async {
    await ensureInitialized();
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } on Object catch (error) {
      debugPrint('[VitalsNotificationService] permission request failed: $error');
    }
  }

  /// A quiet, ongoing notification while the run is in progress so the user can
  /// keep the phone aside and still see it is working.
  Future<void> showProgress({required int done, required int total}) async {
    await ensureInitialized();
    if (!_ready) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        onlyAlertOnce: true,
        showProgress: true,
        maxProgress: total,
        progress: done,
        indeterminate: total == 0,
      ),
      iOS: const DarwinNotificationDetails(presentSound: false),
    );
    await _safeShow(
      _progressId,
      'Reading your vitals…',
      total == 0 ? 'Getting ready' : 'Captured $done of $total',
      details,
    );
  }

  /// The completion ping, framed as a state of being rather than numbers.
  /// [retakeNote] surfaces any vitals that couldn't be read (loose contact).
  Future<void> showResult(WellnessState state, {String? retakeNote}) async {
    await ensureInitialized();
    if (!_ready) return;
    await cancelProgress();
    final base = state.hasData
        ? "You're feeling ${state.title.toLowerCase()} — ${state.spokenLine}."
        : 'Monitoring finished, but no clean readings came through. '
            'Make sure the ring is snug and try again.';
    final body = retakeNote == null ? base : '$base\n$retakeNote';
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(body),
      ),
      iOS: const DarwinNotificationDetails(),
    );
    await _safeShow(_resultId, 'Vitals check-in complete', body, details);
  }

  /// Tell the user the run could not finish (e.g. ring never reconnected).
  Future<void> showFailure(String reason) async {
    await ensureInitialized();
    if (!_ready) return;
    await cancelProgress();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(reason),
      ),
      iOS: const DarwinNotificationDetails(),
    );
    await _safeShow(_resultId, "Couldn't finish your check-in", reason, details);
  }

  /// A one-off push alert (ring offline / stale / low battery, or a health
  /// alert). Each caller owns its [id] so an alert replaces itself rather
  /// than stacking.
  Future<void> showAlert({
    required int id,
    required String title,
    required String body,
  }) async {
    await ensureInitialized();
    if (!_ready) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(body),
      ),
      iOS: const DarwinNotificationDetails(),
    );
    await _safeShow(id, title, body, details);
  }

  Future<void> cancelProgress() async {
    try {
      await _plugin.cancel(_progressId);
    } on Object catch (_) {}
  }

  Future<void> _safeShow(
    int id,
    String title,
    String body,
    NotificationDetails details,
  ) async {
    try {
      await _plugin.show(id, title, body, details);
    } on Object catch (error) {
      debugPrint('[VitalsNotificationService] show failed: $error');
    }
  }
}

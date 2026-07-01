import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
      'Tells you when a Monitor all vitals run has finished.';
  static const _progressId = 4201;
  static const _resultId = 4202;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

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

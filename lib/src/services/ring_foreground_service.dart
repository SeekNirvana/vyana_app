part of '../../main.dart';

/// Message the foreground-service isolate sends to the main isolate on each
/// heartbeat, asking it to reconnect (if needed) and pull fresh ring history.
/// The main isolate owns the BLE connection, so the actual sync must run there.
const kRingForegroundSyncTick = 'ring_foreground_sync_tick';

/// The callback that the native service runs when it starts the foreground
/// task. Must be a top-level or static function marked with the entry-point
/// pragma so it is not tree-shaken.
@pragma('vm:entry-point')
void ringForegroundServiceCallback() {
  FlutterForegroundTask.setTaskHandler(RingForegroundTaskHandler());
}

/// Runs inside the foreground service isolate. Its job is twofold: keep the
/// persistent notification current, and — because the foreground service keeps
/// the process (and the main isolate's BLE connection) alive — fire a periodic
/// heartbeat to the main isolate so ring history is pulled even while the app
/// is backgrounded. The heartbeat cadence is the native `repeat` interval set
/// in [RingForegroundService.init]/[RingForegroundService.setRepeatInterval].
class RingForegroundTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _updateNotification(
      title: 'Vyana is running',
      body: 'Keeping your ring connected',
    );
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Ask the main isolate (which owns the ring connection) to sync. It decides
    // whether a reconnect is needed and whether enough time has elapsed.
    FlutterForegroundTask.sendDataToMain(kRingForegroundSyncTick);
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // No extra cleanup needed.
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map) {
      final title = data['title'] as String?;
      final body = data['body'] as String?;
      _updateNotification(title: title, body: body);
    }
  }

  void _updateNotification({String? title, String? body}) {
    FlutterForegroundTask.updateService(
      notificationTitle: title ?? 'Vyana',
      notificationText: body ?? 'Ring connected',
    );
  }
}

/// Wrapper around the `flutter_foreground_task` plugin for Android. It is a
/// no-op on iOS because iOS background execution will be built later.
class RingForegroundService {
  static bool _initialized = false;

  /// Default background heartbeat cadence (minutes) when no interval is passed.
  static const int _defaultRepeatMinutes = kPeriodicSyncDefaultIntervalMinutes;

  /// The heartbeat cadence the service was last (re)configured with, so we only
  /// call `updateService` when it actually changes.
  static int _repeatMinutes = _defaultRepeatMinutes;

  static ForegroundTaskOptions _taskOptions(int intervalMinutes) {
    return ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(
        Duration(minutes: intervalMinutes).inMilliseconds,
      ),
      autoRunOnBoot: false,
      allowWakeLock: true,
      allowWifiLock: false,
    );
  }

  /// Initializes the foreground task plugin and the communication port.
  /// Call this once early in the app lifecycle (e.g. in `main()`).
  static void init() {
    if (!Platform.isAndroid) return;
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'vyana_foreground_service',
        channelName: 'Vyana foreground service',
        channelDescription:
            'Keeps the ring connected and vitals syncing in the background.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        enableVibration: false,
        playSound: false,
        showWhen: false,
        showBadge: false,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: _taskOptions(_repeatMinutes),
    );
    _initialized = true;
  }

  static Future<void> start({int? intervalMinutes}) async {
    if (!Platform.isAndroid) return;
    if (intervalMinutes != null) _repeatMinutes = intervalMinutes;
    _ensureInitialized();

    final permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (await FlutterForegroundTask.isRunningService) {
      // Already running — just make sure the heartbeat cadence is current.
      await setRepeatInterval(_repeatMinutes);
      return;
    }

    final result = await FlutterForegroundTask.startService(
      serviceTypes: const [
        ForegroundServiceTypes.dataSync,
        ForegroundServiceTypes.remoteMessaging,
      ],
      notificationTitle: 'Vyana is running',
      notificationText: 'Keeping your ring connected',
      callback: ringForegroundServiceCallback,
    );

    if (result is ServiceRequestFailure) {
      debugPrint('RING_FOREGROUND_SERVICE_START_FAILED: ${result.error}');
    }
  }

  /// Re-configures the background heartbeat cadence while the service runs.
  static Future<void> setRepeatInterval(int intervalMinutes) async {
    if (!Platform.isAndroid) return;
    _repeatMinutes = intervalMinutes;
    if (!(await FlutterForegroundTask.isRunningService)) return;
    final result = await FlutterForegroundTask.updateService(
      foregroundTaskOptions: _taskOptions(intervalMinutes),
    );
    if (result is ServiceRequestFailure) {
      debugPrint('RING_FOREGROUND_SERVICE_UPDATE_FAILED: ${result.error}');
    }
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    if (!(await FlutterForegroundTask.isRunningService)) return;

    final result = await FlutterForegroundTask.stopService();
    if (result is ServiceRequestFailure) {
      debugPrint('RING_FOREGROUND_SERVICE_STOP_FAILED: ${result.error}');
    }
  }

  static Future<void> update({String? title, String? body}) async {
    if (!Platform.isAndroid) return;
    if (!(await FlutterForegroundTask.isRunningService)) return;

    FlutterForegroundTask.sendDataToTask(<String, String?>{
      'title': title,
      'body': body,
    });
  }

  static void _ensureInitialized() {
    if (_initialized) return;
    init();
  }
}

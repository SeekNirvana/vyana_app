part of '../../main.dart';

/// The callback that the native service runs when it starts the foreground
/// task. Must be a top-level or static function marked with the entry-point
/// pragma so it is not tree-shaken.
@pragma('vm:entry-point')
void ringForegroundServiceCallback() {
  FlutterForegroundTask.setTaskHandler(RingForegroundTaskHandler());
}

/// Runs inside the foreground service isolate and updates the persistent
/// notification that the user sees while Vyana keeps the ring connected.
class RingForegroundTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _updateNotification(
      title: 'Vyana is running',
      body: 'Ring vitals syncing in background',
    );
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // The main isolate sends fresh vitals/data when needed.
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
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 5000,
        isOnceEvent: false,
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
    _initialized = true;
  }

  static Future<void> start() async {
    if (!Platform.isAndroid) return;
    _ensureInitialized();

    final permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (await FlutterForegroundTask.isRunningService) return;

    final result = await FlutterForegroundTask.startService(
      serviceTypes: const [
        ForegroundServiceTypes.dataSync,
        ForegroundServiceTypes.remoteMessaging,
      ],
      notificationTitle: 'Vyana is running',
      notificationText: 'Ring vitals syncing in background',
      callback: ringForegroundServiceCallback,
    );

    if (result is ServiceRequestFailure) {
      debugPrint('RING_FOREGROUND_SERVICE_START_FAILED: ${result.error}');
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

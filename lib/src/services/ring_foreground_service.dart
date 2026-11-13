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
    // Record the heartbeat so the app can tell, on the next launch, whether
    // the system killed it mid-watch (bug 18(5)): a gap much larger than the
    // interval means the process was not running when it should have been.
    unawaited(RingForegroundService.recordHeartbeat(timestamp));
    // Bug 44 (2): the alerts run here, in the service isolate, not through
    // sendDataToMain. With the app closed the main isolate is suspended, so
    // those messages were queued and handled on resume — which is exactly
    // why the low-battery alert for a ring that died overnight only arrived
    // when the app was opened in the morning.
    unawaited(RingForegroundService.evaluateAlertsInIsolate(timestamp));
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

/// Wrapper around the `flutter_foreground_task` plugin for Android.
///
/// Bug 47: on iOS there is no equivalent service, and nothing here starts
/// one. What keeps the ring alive on iPhone is instead:
///
/// * `bluetooth-central` in `UIBackgroundModes` (ios/Runner/Info.plist), so
///   iOS does not tear the BLE connection down when Vyana is backgrounded;
/// * Core Bluetooth state restoration — a restore identifier on the SDK's
///   central manager — so iOS relaunches Vyana when the ring connects or
///   sends data. That lives in the ring SDK, not in this repo; see
///   docs/ios-background.md for what it needs;
/// * the time-based alerts handed to the OS in advance as local
///   notifications ([VitalsNotificationService.scheduleStaleRingAlert],
///   [VitalsNotificationService.scheduleRingOfflineAlert] and
///   [VitalsNotificationService.scheduleOvernightBattery]), because iOS gives
///   no background timer to evaluate them with.
class RingForegroundService {
  static bool _initialized = false;

  static const _heartbeatKey = 'vyana.ring.service.lastHeartbeat';
  static const _heartbeatLogKey = 'vyana.ring.service.heartbeatLog';

  /// How many heartbeats the Diagnostics screen keeps. At the default
  /// 20-minute cadence this is about two days — long enough to see whether
  /// the service survived a night (bug 44 (1)).
  static const int kHeartbeatLogLimit = 150;

  /// Stamps the time of a service heartbeat. Runs in the service isolate, so
  /// it talks to SharedPreferences directly rather than through a provider.
  static Future<void> recordHeartbeat(DateTime at) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_heartbeatKey, at.millisecondsSinceEpoch);
      // Bug 44 (1): one stamp cannot show a gap. The log can, so a tester can
      // see on the Diagnostics screen exactly when the OS stopped the service.
      final log = prefs.getStringList(_heartbeatLogKey) ?? const <String>[];
      final next = [...log, '${at.millisecondsSinceEpoch}'];
      await prefs.setStringList(
        _heartbeatLogKey,
        next.length <= kHeartbeatLogLimit
            ? next
            : next.sublist(next.length - kHeartbeatLogLimit),
      );
    } on Object catch (_) {
      // A missed stamp only costs us one data point of the gap detection.
    }
  }

  /// Every recorded heartbeat, oldest first. Read by Diagnostics.
  static Future<List<DateTime>> heartbeatLog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_heartbeatLogKey) ?? const <String>[];
      return [
        for (final entry in raw)
          if (int.tryParse(entry) case final ms?)
            DateTime.fromMillisecondsSinceEpoch(ms),
      ];
    } on Object catch (_) {
      return const [];
    }
  }

  /// Bug 44 (2): evaluates the ring alerts from inside the service isolate,
  /// against the snapshot the main isolate last stored. Nothing here needs
  /// Riverpod, the ring controller or the BLE stack — only SharedPreferences
  /// and the notifications plugin, both of which work in a background isolate.
  static Future<void> evaluateAlertsInIsolate(DateTime at) async {
    try {
      final snapshot = await RingAlertSnapshot.load();
      if (snapshot == null) return;
      final store = await SharedPreferences.getInstance();
      // This isolate's cache was filled when the service started; the user
      // may have changed the switches in the app since.
      await store.reload();
      await evaluateRingAlerts(
        snapshot: snapshot,
        prefs: await loadNotificationPrefs(store),
        store: store,
        notify: VitalsNotificationService.instance,
        now: at,
      );
    } on Object catch (error) {
      debugPrint('RING_SERVICE_ALERTS_FAILED: $error');
    }
  }

  static Future<DateTime?> lastHeartbeat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(_heartbeatKey);
      return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    } on Object catch (_) {
      return null;
    }
  }

  /// Bug 18(5): Android gives no warning before killing an app, so the only
  /// honest signal is a gap in heartbeats larger than twice the interval
  /// while a ring was paired. Returns the gap when one is found.
  static Future<Duration?> missedWatchGap({required int intervalMinutes}) async {
    final last = await lastHeartbeat();
    if (last == null) return null;
    final gap = DateTime.now().difference(last);
    final tolerance = Duration(minutes: intervalMinutes * 2);
    return gap > tolerance ? gap : null;
  }

  /// Whether the native service is alive right now. Bug 44 (1): with the app
  /// closed this is the first thing to check — no service, no heartbeats, no
  /// alerts.
  static Future<bool> isServiceRunning() async {
    if (!Platform.isAndroid) return false;
    try {
      return await FlutterForegroundTask.isRunningService;
    } on Object catch (_) {
      return false;
    }
  }

  static Future<bool> isExemptFromBatteryOptimisation() async {
    if (!Platform.isAndroid) return true;
    try {
      return await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    } on Object catch (_) {
      return true;
    }
  }

  /// Opens the OS screen where the user can let Vyana keep running. Never
  /// asked up front, and never during ring setup.
  static Future<void> requestBatteryExemption() async {
    if (!Platform.isAndroid) return;
    try {
      await FlutterForegroundTask.openIgnoreBatteryOptimizationSettings();
    } on Object catch (_) {}
  }

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
      // Bug 6 (3): without this the service never comes back after a
      // reboot, so a paired ring silently stops being watched until the user
      // happens to open the app.
      autoRunOnBoot: true,
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
      // Bug 44 (a): this was dataSync|remoteMessaging. From Android 15 a
      // dataSync service is stopped after six hours in any twenty-four, so it
      // could never last a night — the one thing it exists to do. A BLE
      // wearable is a connectedDevice service, which has no time limit.
      serviceTypes: const [ForegroundServiceTypes.connectedDevice],
      notificationTitle: 'Vyana is running',
      notificationText: 'Keeping your ring connected',
      // The one notification that is always on screen, so the one most
      // worth not being a white blob. flutter_foreground_task resolves the
      // drawable through a manifest meta-data name rather than taking a
      // resource directly.
      notificationIcon: const NotificationIcon(
        metaDataName: 'app.seeknirvana.vyana.FOREGROUND_NOTIFICATION_ICON',
        backgroundColor: kNotificationAccent,
      ),
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

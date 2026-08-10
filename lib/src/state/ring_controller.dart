part of '../../main.dart';

/// Phases of a hands-off "Monitor all vitals" run.
enum AllVitalsPhase { idle, reconnecting, running, syncing, done, failed }

/// Owns the PRANA ring connection lifecycle, live vitals, sync, measurements
/// and ECG — ported from the original `_RingDashboardState` so behaviour is
/// preserved. UI now reads it through [ringControllerProvider]; navigation and
/// dialogs live in the widgets, not here.
class RingController extends ChangeNotifier {
  RingController({RingHistoryCacheService? historyCache})
      : _historyCache = historyCache;

  final RingRepository _repo = RingRepository();
  final RingHistoryCacheService? _historyCache;

  SavedPranaRing? _pairedRing;
  bool _isReady = false;
  bool _isConnecting = false;
  bool _isAutoReconnecting = false;
  bool _isSyncing = false;
  bool _isMeasuring = false;
  bool _isConnected = false;
  String _status = 'Initializing SDK';
  String _testStatus = 'No measurement in progress';
  String? _activeMeasurementLabel;
  ParsedEcgResult? _ecgResult;
  Timer? _measurementTimeout;
  Timer? _connectionStateTimer;
  Timer? _ecgPreparationTimer;
  Timer? _ecgContactTimeout;
  Timer? _ecgSnapshotTicker;
  DateTime? _lastReconnectAttempt;
  DateTime? _lastConnectionConfirmedAt;
  DateTime? _lastBatteryPoll;
  DateTime? _lastPeriodicSync;
  bool _isBatteryPolling = false;
  int? _ecgPreStartRemainingSeconds;
  bool _ecgWaitingForContact = false;
  bool _ecgSdkStarted = false;
  bool _ecgSuccessful = false;
  bool _readingEcgResult = false;
  DateTime? _ecgStartedAt;
  DateTime? _ecgEndedAt;
  final List<double> _ecgRawSamples = [];
  final List<double> _ecgFilteredSamples = [];
  int? _ecgRr;
  int? _ecgHrv;
  int? _ecgHeartRate;
  String? _ecgBloodPressure;
  bool? _ecgContactAttached;
  String? _ecgEndReason;
  String? _ecgFailureReason;

  dynamic _selectedDevice;
  DeviceBasicSnapshot? _basicInfo;
  DeviceFeatureSnapshot? _features;
  RingVitals _vitals = RingVitals.empty();
  RingHistory _history = RingHistory.empty();
  bool _historyHydratedFromCache = false;
  DateTime? _cachedHistorySyncedAt;
  HistoryLogStatus _historyLogStatus = HistoryLogStatus.empty();
  final HistorySyncLogger _historyLogger = HistorySyncLogger();
  late final ValueNotifier<MeasurementPageSnapshot> measurementSnapshot =
      ValueNotifier(_currentMeasurementSnapshot());
  final List<String> _eventLog = [];

  // ── Monitor-all-vitals run state ──────────────────────────────────────────
  AllVitalsPhase _allVitalsPhase = AllVitalsPhase.idle;
  int _allVitalsTotal = 0;
  int _allVitalsDone = 0;
  String? _allVitalsCurrentLabel;
  String? _allVitalsMessage;
  DateTime? _allVitalsFinishedAt;
  Completer<void>? _allVitalsStepCompleter;
  final List<String> _allVitalsRetakes = [];

  /// The metric being actively measured, and whether a fresh *plausible* value
  /// arrived for it this attempt — the contact/quality signal that drives
  /// retries (batch) and the "retake" hint (single test).
  DeviceAppControlMeasureHealthDataType? _activeMeasureType;
  bool _measureCaptured = false;
  static const _kMaxVitalRetries = 2;

  static const _healthMonitoringEnabledKey = 'health_monitoring_enabled_v1';
  static const _healthMonitoringIntervalKey = 'health_monitoring_interval_v1';
  static const _healthMonitoringAckKey = 'health_monitoring_ring_ack_v1';
  static const _periodicSyncIntervalMinutesKey = 'ring_sync_interval_minutes_v1';
  static const _ringOnboardingCompletedKey = 'ring_onboarding_completed_v1';
  static const _foregroundServiceEnabledKey = 'foreground_service_enabled_v1';
  static const _foregroundServiceAllowedKey = 'foreground_service_allowed_v1';

  HealthMonitoringSettings _healthMonitoring = const HealthMonitoringSettings(
    enabled: true,
    intervalMinutes: kHealthMonitoringDefaultInterval,
    ringAcknowledged: false,
  );
  bool _healthMonitoringApplying = false;
  int _periodicSyncIntervalMinutes = kPeriodicSyncDefaultIntervalMinutes;
  bool _ringOnboardingCompleted = false;
  bool _foregroundServiceEnabled = false;
  bool _foregroundServiceAllowed = true;

  bool _disposed = false;

  /// Scheduler flag: true while an activity session owns the ring, so one-shot
  /// measurements/ECG are serialized behind it.
  bool _sessionActive = false;
  bool get sessionActive => _sessionActive;
  void setSessionActive(bool value) => _sessionActive = value;

  /// While set, every native ring event is also forwarded here so the active
  /// session can persist raw frames.
  void Function(Map<dynamic, dynamic> event)? sessionEventSink;

  // ── Public state getters ──────────────────────────────────────────────────
  RingRepository get repo => _repo;
  SavedPranaRing? get pairedRing => _pairedRing;
  bool get isReady => _isReady;
  bool get isConnecting => _isConnecting;
  bool get isSyncing => _isSyncing;
  bool get isMeasuring => _isMeasuring;
  bool get isConnected => _isConnected;
  String get status => _status;
  String get testStatus => _testStatus;
  String? get activeMeasurementLabel => _activeMeasurementLabel;
  dynamic get selectedDevice => _selectedDevice;
  DeviceBasicSnapshot? get basicInfo => _basicInfo;
  DeviceFeatureSnapshot? get features => _features;
  RingVitals get vitals => _vitals;
  RingHistory get history => _history;
  bool get historyHydratedFromCache => _historyHydratedFromCache;
  DateTime? get cachedHistorySyncedAt => _cachedHistorySyncedAt;
  HistoryLogStatus get historyLogStatus => _historyLogStatus;
  List<String> get eventLog => List.unmodifiable(_eventLog);

  // ── Monitor-all-vitals getters ────────────────────────────────────────────
  AllVitalsPhase get allVitalsPhase => _allVitalsPhase;
  bool get allVitalsRunning =>
      _allVitalsPhase == AllVitalsPhase.reconnecting ||
      _allVitalsPhase == AllVitalsPhase.running ||
      _allVitalsPhase == AllVitalsPhase.syncing;
  int get allVitalsTotal => _allVitalsTotal;
  int get allVitalsDone => _allVitalsDone;
  String? get allVitalsCurrentLabel => _allVitalsCurrentLabel;
  String? get allVitalsMessage => _allVitalsMessage;
  DateTime? get allVitalsFinishedAt => _allVitalsFinishedAt;

  /// Current felt "state of being" from the latest vitals + readiness.
  WellnessState currentWellnessState() {
    final dashboard = HomeDashboard.from(this);
    return WellnessState.from(
      heartRate: _vitals.heartRate,
      bloodOxygen: _vitals.bloodOxygen,
      hrv: _vitals.hrv,
      temperature: _vitals.temperature,
      stressIndex: _vitals.pressure,
      readinessScore: dashboard.readinessScore,
    );
  }

  /// Paired device, live connection, synced records, or hydrated cache.
  bool get hasRingContext =>
      _pairedRing != null ||
      _isConnected ||
      _history.totalRecords > 0 ||
      _historyHydratedFromCache;

  bool get supportsFindRing =>
      _features?.supports('isSupportFindDevice') ?? false;

  bool get supportsFactoryReset =>
      _features?.supports('isSupportFactorySettings') ?? false;

  bool get supportsHealthMonitoring =>
      _features?.supportsAny(const [
        'isSupportHeartRate',
        'isSupportBloodOxygen',
        'isSupportBloodPressure',
        'isSupportTemperature',
        'isSupportRealTimeDataUpload',
      ]) ??
      false;

  HealthMonitoringSettings get healthMonitoring => _healthMonitoring;

  bool get healthMonitoringApplying => _healthMonitoringApplying;

  int get periodicSyncIntervalMinutes => _periodicSyncIntervalMinutes;

  bool get ringOnboardingCompleted => _ringOnboardingCompleted;

  bool get foregroundServiceEnabled => _foregroundServiceEnabled;

  bool get foregroundServiceAllowed => _foregroundServiceAllowed;

  void _set(VoidCallback fn) {
    fn();
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _connectionStateTimer?.cancel();
    _measurementTimeout?.cancel();
    _ecgPreparationTimer?.cancel();
    _ecgContactTimeout?.cancel();
    _ecgSnapshotTicker?.cancel();
    measurementSnapshot.dispose();
    super.dispose();
  }

  /// Call when the app returns to the foreground.
  void onAppResumed() => unawaited(_refreshConnectionState());

  Future<void> initialize() async {
    try {
      final pairedRing = await PranaRingStore.load();
      await _loadHealthMonitoringPrefs();
      await _loadPeriodicSyncIntervalPrefs();
      await _loadRingOnboardingPrefs();
      await _repo.initialize(_handleNativeEvent);
      final connected = await _repo.isConnected();
      if (_disposed) return;
      _set(() {
        _pairedRing = pairedRing;
        _selectedDevice ??= pairedRing?.toDeviceMap();
        _isReady = true;
        _isConnected = connected;
        _status = connected
            ? 'PRANA ring connected'
            : pairedRing == null
            ? 'Ready to scan'
            : 'Ready to reconnect PRANA ring';
      });
      _startConnectionStateWatcher();
      _publishMeasurementSnapshot();
      _syncForegroundService();
      unawaited(_refreshHistoryLogStatus());
      await _hydrateHistoryFromCache();
      if (connected) {
        _lastConnectionConfirmedAt = DateTime.now();
        unawaited(_syncDeviceData());
      } else if (pairedRing != null) {
        unawaited(reconnectSavedRing(force: true));
      }
    } on Object catch (error) {
      if (_disposed) return;
      _set(() => _status = 'SDK unavailable: $error');
    }
  }

  void _startConnectionStateWatcher() {
    _connectionStateTimer?.cancel();
    _connectionStateTimer = Timer.periodic(_connectionStatePollInterval, (_) {
      unawaited(_refreshConnectionState());
    });
    unawaited(_refreshConnectionState());
  }

  Future<void> _refreshConnectionState() async {
    if (!_isReady) return;
    final bluetoothState = await _repo.bluetoothState();
    if (_disposed || bluetoothState == null) return;

    var shouldSyncAfterConnection = false;
    _set(() {
      shouldSyncAfterConnection =
          _applyBluetoothStateToModel(bluetoothState, fromPoll: true);
    });
    _publishMeasurementSnapshot();
    _maybeSignalStepFromState();

    if (shouldSyncAfterConnection) {
      unawaited(_syncDeviceData());
    } else if (!_isConnected &&
        _pairedRing != null &&
        bluetoothState != BluetoothState.off) {
      unawaited(reconnectSavedRing());
    }

    unawaited(_maybeRefreshBattery());
    unawaited(_maybePeriodicSync());
  }

  Future<void> _maybeRefreshBattery() async {
    if (!_isReady || !_isConnected || _isSyncing || _isBatteryPolling) return;
    final now = DateTime.now();
    if (_lastBatteryPoll != null &&
        now.difference(_lastBatteryPoll!) < _batteryPollInterval) {
      return;
    }
    _isBatteryPolling = true;
    _lastBatteryPoll = now;
    try {
      final basicInfo = await _repo.probeConnectedBasicInfo();
      if (_disposed || basicInfo == null) return;
      final battery = basicInfo.batteryPower;
      if (_basicInfo?.batteryPower == battery &&
          _vitals.battery == battery &&
          _basicInfo != null) {
        return;
      }
      _set(() {
        _basicInfo = basicInfo;
        _vitals = RingVitals(battery: battery).merge(_vitals);
      });
    } on Object catch (error) {
      debugPrint('Battery poll failed: $error');
    } finally {
      _isBatteryPolling = false;
    }
  }

  Future<void> _maybePeriodicSync() async {
    if (!_isReady ||
        !_isConnected ||
        _isSyncing ||
        _isAutoReconnecting ||
        _isMeasuring) {
      return;
    }
    final now = DateTime.now();
    if (_lastPeriodicSync != null &&
        now.difference(_lastPeriodicSync!) <
            Duration(minutes: _periodicSyncIntervalMinutes)) {
      return;
    }
    unawaited(_syncDeviceData());
  }

  bool _applyBluetoothStateToModel(
    int bluetoothState, {
    dynamic deviceInfo,
    bool fromPoll = false,
  }) {
    final wasConnected = _isConnected;
    final connectedEvent = bluetoothState == BluetoothState.connected;
    final failedConnectionEvent =
        bluetoothState == BluetoothState.connectFailed;
    final bluetoothOffEvent = bluetoothState == BluetoothState.off;
    final disconnectedEvent =
        bluetoothState == BluetoothState.disconnected || bluetoothOffEvent;
    final bluetoothOnEvent = bluetoothState == BluetoothState.on;
    final recentlyConfirmed = _lastConnectionConfirmedAt != null &&
        DateTime.now().difference(_lastConnectionConfirmedAt!) <
            _connectionStateGracePeriod;

    if (connectedEvent) {
      _isConnected = true;
      _isConnecting = false;
      _lastConnectionConfirmedAt = DateTime.now();
      if (deviceInfo != null) {
        _selectedDevice = deviceInfo;
      }
      if (!wasConnected ||
          _status == 'Disconnected' ||
          _status == 'Bluetooth is off' ||
          _status == 'Ready to scan' ||
          _status == 'Connection failed') {
        _status = 'Connected to ${deviceLabel(_selectedDevice)}';
      }
      return !wasConnected;
    }

    if (!bluetoothOffEvent &&
        !failedConnectionEvent &&
        wasConnected &&
        recentlyConfirmed &&
        (disconnectedEvent || bluetoothOnEvent)) {
      return false;
    }

    if (failedConnectionEvent || disconnectedEvent) {
      _isConnected = false;
      _isConnecting = false;
      _isSyncing = false;
      _measurementTimeout?.cancel();
      _isMeasuring = false;
      _activeMeasurementLabel = null;

      final message = bluetoothOffEvent
          ? 'Bluetooth is off'
          : failedConnectionEvent
          ? 'Connection failed'
          : 'Disconnected';
      final shouldReportState = bluetoothOffEvent ||
          failedConnectionEvent ||
          wasConnected ||
          fromPoll && _selectedDevice != null ||
          _status.startsWith('Connected') ||
          _status.startsWith('Connecting') ||
          _status.startsWith('Syncing');
      if (shouldReportState) {
        _status = message;
      }
      return false;
    }

    if (bluetoothOnEvent) {
      if (wasConnected && !_isConnecting) {
        _isConnected = false;
        _isSyncing = false;
        _status = 'Disconnected';
      } else if (fromPoll && _status == 'Bluetooth is off') {
        _status = 'Ready to scan';
      }
    }

    return false;
  }

  void _handleNativeEvent(dynamic event) {
    if (_disposed) return;
    final map = event is Map ? event : <dynamic, dynamic>{};
    final eventText = map.isEmpty ? event.toString() : _compactEvent(map);
    final bluetoothState =
        readInt(map, const [NativeEventType.bluetoothStateChange]);
    final deviceInfo = map[NativeEventType.deviceInfo];
    final connectedEvent = bluetoothState == BluetoothState.connected;
    final shouldSyncAfterConnection = connectedEvent && !_isConnected;
    final measureStateInfo =
        map[NativeEventType.deviceHealthDataMeasureStateChange];
    final measureState = readInt(measureStateInfo, const ['state']);
    final measureType = readInt(measureStateInfo, const ['healthDataType']);
    final ecgIsActive = _activeMeasurementLabel == 'ECG';
    final deviceEndedEcg = map.containsKey(NativeEventType.deviceEndECG);
    final ecgUpdate = _EcgEventUpdate.fromMap(map);
    var shouldStopEcgAfterEvent = false;
    var shouldReadEcgAfterEvent = false;
    final hasMeasurementValue = _activeMeasurementLabel != null &&
        !ecgIsActive &&
        containsLiveMeasurementValue(map);
    final shouldFinishMeasurement = !ecgIsActive &&
        ((measureState != null && measureState != 3) || hasMeasurementValue);
    final measurementMessage = ecgIsActive
        ? deviceEndedEcg
              ? 'ECG ended by ring'
              : ecgUpdate.statusText
        : measureState == null
        ? hasMeasurementValue
              ? '${_activeMeasurementLabel!} updated from ring'
              : null
        : 'Measurement ${measurementStateLabel(measureState)}'
              '${measureType == null ? '' : ' for ${measureTypeIndexLabel(measureType)}'}';

    _set(() {
      _eventLog.insert(0, '${DateTime.now().toIso8601String()}  $eventText');
      if (_eventLog.length > 30) {
        _eventLog.removeLast();
      }
      _vitals = _vitals.mergeLiveEvent(map);
      if (_activeMeasureType != null &&
          _eventCarriesPlausibleValue(map, _activeMeasureType!)) {
        _measureCaptured = true;
      }
      if (measurementMessage != null) {
        _testStatus = measurementMessage;
      }
      if (shouldFinishMeasurement) {
        _measurementTimeout?.cancel();
        _isMeasuring = false;
        _activeMeasurementLabel = null;
      }
      if (ecgIsActive) {
        _mergeEcgUpdate(ecgUpdate);
        if (_ecgStartedAt != null && ecgUpdate.contactAttached == false) {
          shouldStopEcgAfterEvent = _ecgSdkStarted;
          _finishEcgAttempt(
            'ECG contact was lost. Please try again.',
            successful: false,
          );
        } else if (deviceEndedEcg) {
          final success = _ecgRecordingIsSuccessful();
          _finishEcgAttempt(
            success
                ? 'ECG recording complete'
                : 'ECG ended before a clean recording. Please try again.',
            successful: success,
          );
          shouldReadEcgAfterEvent = success;
        }
      }
      if (bluetoothState != null) {
        _applyBluetoothStateToModel(bluetoothState, deviceInfo: deviceInfo);
      }
    });
    _publishMeasurementSnapshot();
    _maybeSignalStepFromState();
    // Single-test contact hint: the reading finished but no plausible value came
    // through (loose contact). Don't leave the user with a scary blank/zero.
    if (shouldFinishMeasurement &&
        !ecgIsActive &&
        !allVitalsRunning &&
        _activeMeasureType != null &&
        !_measureCaptured) {
      _set(() => _testStatus =
          "Couldn't get a clean reading — keep the ring snug on your "
          'finger and try again.');
      _publishMeasurementSnapshot();
    }
    if (sessionEventSink != null && map.isNotEmpty) {
      sessionEventSink!(map);
    }
    if (shouldStopEcgAfterEvent) {
      unawaited(_repo.stopEcg());
    }
    if (connectedEvent && deviceInfo != null) {
      unawaited(savePairedRingFromDevice(deviceInfo));
    }
    if (shouldReadEcgAfterEvent) {
      unawaited(_readEcgResultAfterCompletion());
    }
    if (shouldSyncAfterConnection || shouldFinishMeasurement && !ecgIsActive) {
      unawaited(_syncDeviceData());
    }
  }

  Future<bool> reconnectSavedRing({bool force = false}) async {
    final pairedRing = _pairedRing;
    if (!_isReady ||
        pairedRing == null ||
        _isConnected ||
        _isConnecting ||
        _isAutoReconnecting) {
      return _isConnected;
    }

    final now = DateTime.now();
    final previousAttempt = _lastReconnectAttempt;
    if (!force &&
        previousAttempt != null &&
        now.difference(previousAttempt) < _reconnectAttemptInterval) {
      return false;
    }

    _lastReconnectAttempt = now;
    _set(() {
      _isAutoReconnecting = true;
      _status = 'Checking paired PRANA ring';
    });

    try {
      if (await _restoreResponsiveSdkConnection()) {
        return true;
      }
      final scanAccess = await _repo.ensureScanAccess();
      if (!scanAccess.granted) {
        if (_disposed) return false;
        _set(() => _status = scanAccess.message);
        return false;
      }
      final devices = await _repo.scanDevices(seconds: 6);
      final matchingDevice = pairedRing.matchingDevice(devices);
      if (matchingDevice == null) {
        if (_disposed) return false;
        _set(() => _status = 'Paired PRANA ring not found by scan');
        return false;
      }
      return connect(matchingDevice);
    } on Object catch (error) {
      if (_disposed) return false;
      _set(() => _status = 'Reconnect failed: $error');
      return false;
    } finally {
      if (!_disposed) {
        _set(() => _isAutoReconnecting = false);
      }
    }
  }

  Future<bool> _restoreResponsiveSdkConnection() async {
    final pairedRing = _pairedRing;
    if (pairedRing == null) return false;

    final basicInfo = await _repo.probeConnectedBasicInfo();
    if (basicInfo == null || _disposed) return false;

    final device = _selectedDevice ?? pairedRing.toDeviceMap();
    _set(() {
      _selectedDevice = device;
      _basicInfo = basicInfo;
      _isConnected = true;
      _isConnecting = false;
      _status = 'Connected to ${deviceLabel(device)}';
      _lastConnectionConfirmedAt = DateTime.now();
    });
    _publishMeasurementSnapshot();
    await savePairedRingFromDevice(device, basicInfo: basicInfo);
    unawaited(_syncDeviceData());
    return true;
  }

  Future<bool> connect(dynamic device) async {
    if (_isConnecting) return false;
    _set(() {
      _selectedDevice = device;
      _isConnecting = true;
      _status = 'Connecting to ${deviceLabel(device)}';
    });

    try {
      final connected = await _repo.connect(device);
      if (_disposed) return false;
      _set(() {
        _isConnected = connected;
        _status = connected
            ? 'Connected to ${deviceLabel(device)}'
            : 'Connection failed';
        if (connected) {
          _lastConnectionConfirmedAt = DateTime.now();
        }
      });
      if (connected) {
        await savePairedRingFromDevice(device);
        await _syncDeviceData();
      }
      return connected;
    } on Object catch (error) {
      if (_disposed) return false;
      _set(() => _status = 'Connection failed: $error');
      return false;
    } finally {
      if (!_disposed) {
        _set(() => _isConnecting = false);
      }
    }
  }

  void handleScannerDetectedConnection(dynamic device) {
    if (_disposed) return;
    final shouldSync = !_isConnected;
    _set(() {
      _selectedDevice = device;
      _isConnected = true;
      _status = 'Connected to ${deviceLabel(device)}';
      _lastConnectionConfirmedAt = DateTime.now();
    });
    unawaited(savePairedRingFromDevice(device));
    if (shouldSync) {
      unawaited(_syncDeviceData());
    }
  }

  Future<void> disconnect() async {
    _set(() => _status = 'Disconnecting');
    final ok = await _repo.disconnect();
    if (_disposed) return;
    _set(() {
      _isConnected = !ok;
      _status = ok ? 'Disconnected' : 'Disconnect failed';
      if (ok) {
        _lastConnectionConfirmedAt = null;
      }
    });
  }

  Future<void> savePairedRingFromDevice(
    dynamic device, {
    DeviceBasicSnapshot? basicInfo,
    RingVitals? vitals,
  }) async {
    final next = SavedPranaRing.fromDevice(
      device,
      basicInfo: basicInfo ?? _basicInfo,
      vitals: vitals ?? _vitals,
      previous: _pairedRing,
    );
    await PranaRingStore.save(next);
    if (_disposed) return;
    _set(() {
      _pairedRing = next;
      _selectedDevice = device;
    });
  }

  Future<bool> unpairCurrentRing() async {
    _set(() => _status = 'Unpairing PRANA ring');
    final ok = await _repo.unpair();
    if (_disposed) return false;

    if (ok) {
      await _clearAllLocalRingData();
      if (_disposed) return false;
      _applyUnpairedRingState(status: 'PRANA ring unpaired');
      return true;
    }

    _set(() => _status = 'Unpair failed');
    return false;
  }

  Future<RingResetResult> resetPranaRingToFactory() async {
    if (!_isConnected) {
      return const RingResetResult(
        success: false,
        message: 'Connect your ring first.',
      );
    }
    if (_sessionActive) {
      return const RingResetResult(
        success: false,
        message: 'Finish your practice session before resetting the ring.',
      );
    }
    if (_isSyncing) {
      return const RingResetResult(
        success: false,
        message: 'Wait for the current sync to finish.',
      );
    }
    if (_isMeasuring || _activeMeasurementLabel != null) {
      return const RingResetResult(
        success: false,
        message: 'Finish the current measurement before resetting.',
      );
    }

    final useFactoryReset = supportsFactoryReset;
    _set(() => _status = useFactoryReset
        ? 'Factory-resetting PRANA ring…'
        : 'Erasing ring health data…');

    final ringOk = useFactoryReset
        ? await _repo.restoreFactorySettings()
        : await _repo.deleteAllSupportedRingHealthData(_features);
    if (_disposed) {
      return const RingResetResult(success: false, message: 'Reset cancelled.');
    }

    if (!ringOk) {
      _set(() => _status = useFactoryReset
          ? 'Factory reset failed — stay close and try again'
          : 'Ring data erase failed — stay close and try again');
      return RingResetResult(
        success: false,
        message: useFactoryReset
            ? 'The ring did not confirm factory reset. Stay nearby and try again.'
            : 'The ring did not confirm data erase. Stay nearby and try again.',
      );
    }

    await _repo.unpair();
    await _clearAllLocalRingData();
    if (_disposed) {
      return const RingResetResult(success: false, message: 'Reset cancelled.');
    }

    _applyUnpairedRingState(status: 'PRANA ring reset — pair again from You');
    return const RingResetResult(
      success: true,
      message: 'Ring and local vitals cleared. Pair again from You when ready.',
    );
  }

  void _applyUnpairedRingState({required String status}) {
    _set(() {
      _pairedRing = null;
      _selectedDevice = null;
      _basicInfo = null;
      _features = null;
      _vitals = RingVitals.empty();
      _history = RingHistory.empty();
      _historyHydratedFromCache = false;
      _cachedHistorySyncedAt = null;
      _historyLogStatus = HistoryLogStatus.empty();
      _isConnected = false;
      _isConnecting = false;
      _isAutoReconnecting = false;
      _status = status;
      _lastConnectionConfirmedAt = null;
      _eventLog.clear();
    });
    _publishMeasurementSnapshot();
  }

  Future<void> _clearAllLocalRingData() async {
    await PranaRingStore.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_healthMonitoringEnabledKey);
    await prefs.remove(_healthMonitoringIntervalKey);
    await prefs.remove(_healthMonitoringAckKey);
    await _historyCache?.clearAll();
    await _historyLogger.clear();
    if (_disposed) return;
    _set(() {
      _basicInfo = null;
      _features = null;
      _history = RingHistory.empty();
      _historyHydratedFromCache = false;
      _cachedHistorySyncedAt = null;
      _historyLogStatus = HistoryLogStatus.empty();
      _vitals = RingVitals.empty();
      _healthMonitoring = const HealthMonitoringSettings(
        enabled: true,
        intervalMinutes: kHealthMonitoringDefaultInterval,
        ringAcknowledged: false,
      );
    });
    _publishMeasurementSnapshot();
  }

  Future<RingSyncFeedback?> syncDeviceData() => _syncDeviceData();

  String? _resolveCacheDeviceId() {
    final basicId = _basicInfo?.deviceId;
    if (basicId != null && basicId != '-') return basicId;
    final pairedId = _pairedRing?.deviceId;
    if (pairedId != null && pairedId.isNotEmpty) return pairedId;
    final address = _pairedRing?.displayAddress;
    if (address != null && address != 'Unknown address') return address;
    return null;
  }

  Future<void> _hydrateHistoryFromCache() async {
    final cache = _historyCache;
    if (cache == null || _history.totalRecords > 0) return;

    final deviceId = _resolveCacheDeviceId();
    final snapshot = deviceId == null
        ? await cache.loadLatest()
        : await cache.loadForDevice(deviceId);
    if (snapshot == null || snapshot.history.totalRecords == 0 || _disposed) {
      return;
    }

    _set(() {
      _history = snapshot.history.sanitized();
      _historyHydratedFromCache = true;
      _cachedHistorySyncedAt = snapshot.syncedAt;
      if (snapshot.vitals != null) {
        _vitals = snapshot.vitals!.merge(_vitals);
      }
      if (snapshot.basicInfo != null) {
        _basicInfo = snapshot.basicInfo;
      }
      if (!_isConnected) {
        _status =
            'Showing cached ring data · connect to refresh (${snapshot.recordCount} records)';
      }
    });
    _publishMeasurementSnapshot();
  }

  Future<void> _persistHistoryToCache(RingSyncResult result) async {
    final cache = _historyCache;
    final deviceId = _resolveCacheDeviceId();
    if (cache == null || deviceId == null) return;

    try {
      await cache.save(
        deviceId: deviceId,
        history: result.history.sanitized(),
        vitals: result.vitals.merge(_vitals),
        basicInfo: result.basicInfo,
      );
    } on Object catch (error) {
      debugPrint('RING_HISTORY_CACHE save failed: $error');
    }
  }

  Future<RingSyncFeedback?> _syncDeviceData() async {
    if (!_isReady || !_isConnected || _isSyncing) return null;
    _lastPeriodicSync = DateTime.now();
    _set(() {
      _isSyncing = true;
      _status = _historyHydratedFromCache
          ? 'Updating ring data…'
          : 'Updating your health data…';
    });

    RingSyncFeedback? feedback;
    try {
      final result = await _repo.sync().timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          throw TimeoutException('Ring sync timed out after 90 seconds.');
        },
      );
      HistoryLogStatus? logStatus;
      Object? logError;
      try {
        logStatus = await _historyLogger.appendSync(
          device: _selectedDevice,
          basicInfo: result.basicInfo,
          features: result.features,
          history: result.history,
        );
      } on Object catch (error) {
        logError = error;
      }
      final mergedVitals = result.vitals.merge(_vitals);
      if (_disposed) return null;
      feedback = RingSyncFeedback(
        success: true,
        recordCount: result.history.totalRecords,
        logSaved: logError == null,
      );
      _set(() {
        _lastConnectionConfirmedAt = DateTime.now();
        _basicInfo = result.basicInfo;
        _features = result.features;
        _history = result.history.sanitized();
        _historyHydratedFromCache = false;
        _cachedHistorySyncedAt = DateTime.now();
        if (logStatus != null) {
          _historyLogStatus = logStatus;
        }
        _vitals = mergedVitals;
        if (_isConnected) {
          _status = logError == null
              ? 'Synced and logged ${result.history.totalRecords} records'
              : 'Synced ${result.history.totalRecords} records; log failed: $logError';
        }
      });
      unawaited(_persistHistoryToCache(result));
      final deviceForStore = _selectedDevice ?? _pairedRing?.toDeviceMap();
      if (deviceForStore != null) {
        unawaited(
          savePairedRingFromDevice(
            deviceForStore,
            basicInfo: result.basicInfo,
            vitals: mergedVitals,
          ),
        );
      }
      _publishMeasurementSnapshot();
      unawaited(_pushWidgetState());
    } on Object catch (error) {
      if (_disposed) return null;
      feedback = RingSyncFeedback(
        success: false,
        recordCount: 0,
        errorMessage: 'We couldn’t update your ring data. Try again.',
      );
      _set(() {
        if (_isConnected) {
          _status = 'Sync failed: $error';
        }
      });
      _publishMeasurementSnapshot();
    } finally {
      if (!_disposed) {
        _set(() => _isSyncing = false);
      }
    }
    return feedback;
  }

  Future<void> refreshHistoryLogStatus() => _refreshHistoryLogStatus();

  Future<void> _refreshHistoryLogStatus() async {
    final status = await _historyLogger.status();
    if (_disposed) return;
    _set(() => _historyLogStatus = status);
  }

  Future<void> _loadHealthMonitoringPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_healthMonitoringEnabledKey) ?? true;
    final interval = clampHealthMonitoringInterval(
      prefs.getInt(_healthMonitoringIntervalKey) ??
          kHealthMonitoringDefaultInterval,
    );
    final acked = prefs.getBool(_healthMonitoringAckKey) ?? false;
    if (_disposed) return;
    _set(() {
      _healthMonitoring = HealthMonitoringSettings(
        enabled: enabled,
        intervalMinutes: interval,
        ringAcknowledged: acked,
      );
    });
  }

  Future<void> _loadPeriodicSyncIntervalPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final interval = clampPeriodicSyncIntervalMinutes(
      prefs.getInt(_periodicSyncIntervalMinutesKey) ??
          kPeriodicSyncDefaultIntervalMinutes,
    );
    if (_disposed) return;
    _set(() => _periodicSyncIntervalMinutes = interval);
  }

  Future<void> _loadRingOnboardingPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingCompleted =
        prefs.getBool(_ringOnboardingCompletedKey) ?? false;
    final foregroundEnabled =
        prefs.getBool(_foregroundServiceEnabledKey) ?? false;
    final foregroundAllowed =
        prefs.getBool(_foregroundServiceAllowedKey) ?? true;
    if (_disposed) return;
    _set(() {
      _ringOnboardingCompleted = onboardingCompleted;
      _foregroundServiceEnabled = foregroundEnabled;
      _foregroundServiceAllowed = foregroundAllowed;
    });
  }

  Future<void> _persistRingOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ringOnboardingCompletedKey, _ringOnboardingCompleted);
    await prefs.setBool(
        _foregroundServiceEnabledKey, _foregroundServiceEnabled);
    await prefs.setBool(
        _foregroundServiceAllowedKey, _foregroundServiceAllowed);
  }

  Future<void> completeRingOnboarding({
    required bool enableForegroundService,
  }) async {
    _ringOnboardingCompleted = true;
    _foregroundServiceEnabled = enableForegroundService;
    _foregroundServiceAllowed = enableForegroundService;
    await _persistRingOnboarding();
    _set(() {});
    _syncForegroundService();
  }

  Future<void> setForegroundServiceEnabled(bool enabled) async {
    if (!_foregroundServiceAllowed) return;
    _foregroundServiceEnabled = enabled;
    await _persistRingOnboarding();
    _set(() {});
    _syncForegroundService();
  }

  Future<void> applyPeriodicSyncInterval(int minutes) async {
    final clamped = clampPeriodicSyncIntervalMinutes(minutes);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_periodicSyncIntervalMinutesKey, clamped);
    _set(() => _periodicSyncIntervalMinutes = clamped);
  }

  Future<void> _persistHealthMonitoring(HealthMonitoringSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_healthMonitoringEnabledKey, settings.enabled);
    await prefs.setInt(
      _healthMonitoringIntervalKey,
      settings.intervalMinutes,
    );
    await prefs.setBool(_healthMonitoringAckKey, settings.ringAcknowledged);
  }

  Future<HealthMonitoringApplyResult> applyHealthMonitoring({
    required bool enabled,
    required int intervalMinutes,
  }) async {
    if (!_isConnected) {
      return HealthMonitoringApplyResult(
        successful: false,
        message: 'Connect your ring first.',
        settings: _healthMonitoring,
      );
    }

    final interval = clampHealthMonitoringInterval(intervalMinutes);
    _set(() {
      _healthMonitoringApplying = true;
      _healthMonitoring = _healthMonitoring.copyWith(
        enabled: enabled,
        intervalMinutes: interval,
        ringAcknowledged: false,
        lastMessage: enabled
            ? 'Sending every $interval min to ring…'
            : 'Turning monitoring off on ring…',
      );
      _status = _healthMonitoring.lastMessage!;
    });

    final result = await _repo.setHealthMonitoring(
      enabled: enabled,
      intervalMinutes: interval,
    );
    if (_disposed) return result;

    await _persistHealthMonitoring(result.settings);
    _set(() {
      _healthMonitoring = result.settings;
      _healthMonitoringApplying = false;
      _status = result.message;
    });
    return result;
  }

  String get ringNameSuffix {
    String? id = _pairedRing?.macAddress ??
        _pairedRing?.deviceId ??
        _pairedRing?.deviceIdentifier ??
        _pairedRing?.address;
    if (id == null && _selectedDevice != null) {
      id = readAny(_selectedDevice, const [
        'mac',
        'macAddress',
        'address',
        'deviceIdentifier',
        'deviceId',
        'id',
      ])?.toString();
    }
    final clean = _cleanText(id);
    if (clean == null || clean.isEmpty) return '????';
    return clean.length > 4 ? clean.substring(clean.length - 4) : clean;
  }

  Future<RingResetResult> deleteRingHealthData() async {
    if (!_isConnected) {
      return const RingResetResult(
        success: false,
        message: 'Connect your ring first.',
      );
    }
    if (_sessionActive) {
      return const RingResetResult(
        success: false,
        message: 'Finish your practice session before erasing ring data.',
      );
    }
    if (_isSyncing) {
      return const RingResetResult(
        success: false,
        message: 'Wait for the current sync to finish.',
      );
    }
    if (_isMeasuring || _activeMeasurementLabel != null) {
      return const RingResetResult(
        success: false,
        message: 'Finish the current measurement before erasing ring data.',
      );
    }

    _set(() => _status = 'Erasing ring health data…');
    final ringOk = await _repo.deleteAllSupportedRingHealthData(_features);
    if (_disposed) {
      return const RingResetResult(success: false, message: 'Erase cancelled.');
    }

    if (!ringOk) {
      _set(() => _status = 'Ring data erase failed — stay close and try again');
      return const RingResetResult(
        success: false,
        message: 'The ring did not confirm data erase. Stay nearby and try again.',
      );
    }

    await _historyCache?.clearAll();
    await _historyLogger.clear();
    if (_disposed) {
      return const RingResetResult(success: false, message: 'Erase cancelled.');
    }

    _set(() {
      _history = RingHistory.empty();
      _historyHydratedFromCache = false;
      _cachedHistorySyncedAt = null;
      _historyLogStatus = HistoryLogStatus.empty();
    });
    _publishMeasurementSnapshot();
    return const RingResetResult(
      success: true,
      message: 'Ring data erased and local history cleared.',
    );
  }

  Future<void> findRing() async {
    _set(() => _status = 'Sending find ring command');
    final response = await _repo.findDevice();
    if (_disposed) return;
    _set(() => _status = response);
  }

  Future<void> renameRing(String name) async {
    if (!_isConnected) return;
    final validationError = validateRingName(name);
    if (validationError != null) {
      _set(() => _status = validationError);
      return;
    }
    _set(() => _status = 'Updating ring name');
    final result = await _repo.renameConnectedRing(name);
    if (_disposed) return;
    if (result.successful && _pairedRing != null) {
      final updated = _pairedRing!.copyWith(name: result.name);
      await PranaRingStore.save(updated);
      _set(() => _pairedRing = updated);
    }
    _set(() => _status = result.message);
  }

  // ── Measurements & ECG ────────────────────────────────────────────────────
  Future<void> runMeasurement(MeasurementAction action) async {
    if (_sessionActive) {
      _set(() => _testStatus =
          'A session is recording — finish it before a one-shot test.');
      _publishMeasurementSnapshot();
      return;
    }
    _activeMeasureType = action.type;
    _measureCaptured = false;
    await _beginMeasurement(action.label, () => _repo.measure(action.type, true));
  }

  /// Whether [map] delivers an in-range value for [type] — mirrors the keys
  /// `RingVitals.mergeLiveEvent` reads, so it is the true "we got a reading"
  /// signal (loose contact yields zeros, which fail these gates).
  bool _eventCarriesPlausibleValue(
    Map<dynamic, dynamic> map,
    DeviceAppControlMeasureHealthDataType type,
  ) {
    switch (type) {
      case DeviceAppControlMeasureHealthDataType.heartRate:
        return plausibleHeartRate(
              readInt(map['deviceRealHeartRate'], const ['heartRate', 'value']) ??
                  readInt(map['deviceRealSport'], const ['heartRate']),
            ) !=
            null;
      case DeviceAppControlMeasureHealthDataType.bloodOxygen:
        return plausibleSpo2(
              readInt(map['deviceRealBloodOxygen'], const [
                'bloodOxygen',
                'value',
              ]),
            ) !=
            null;
      case DeviceAppControlMeasureHealthDataType.hrv:
        return plausibleHrv(
              readInt(map['deviceRealECGAlgorithmHRV'], const ['hrv', 'value']),
            ) !=
            null;
      case DeviceAppControlMeasureHealthDataType.bodyTemperature:
        return validTemperature(
              readDouble(map['deviceRealTemperature'], const [
                'temperature',
                'value',
              ]),
            ) !=
            null;
      case DeviceAppControlMeasureHealthDataType.bloodPressure:
        return plausibleBloodPressure(
              pressureText(map['deviceRealBloodPressure']),
            ) !=
            null;
      case DeviceAppControlMeasureHealthDataType.bloodGlucose:
        return plausibleGlucose(
              readDouble(map['deviceRealBloodGlucose'], const [
                'bloodGlucose',
                'value',
              ]),
            ) !=
            null;
      case DeviceAppControlMeasureHealthDataType.pressure:
        return readDouble(map['deviceRealPressure'], const [
              'pressure',
              'value',
            ]) !=
            null;
      default:
        return false;
    }
  }

  /// Current plausible value already held for [type] (null when we have none).
  double? _plausibleVitalForType(DeviceAppControlMeasureHealthDataType type) {
    switch (type) {
      case DeviceAppControlMeasureHealthDataType.heartRate:
        return _vitals.heartRate?.toDouble();
      case DeviceAppControlMeasureHealthDataType.bloodOxygen:
        return _vitals.bloodOxygen?.toDouble();
      case DeviceAppControlMeasureHealthDataType.hrv:
        return _vitals.hrv?.toDouble();
      case DeviceAppControlMeasureHealthDataType.bodyTemperature:
        return _vitals.temperature;
      case DeviceAppControlMeasureHealthDataType.bloodPressure:
        return _vitals.bloodPressure != null ? 1 : null;
      case DeviceAppControlMeasureHealthDataType.bloodGlucose:
        return _vitals.bloodGlucose;
      case DeviceAppControlMeasureHealthDataType.pressure:
        return _vitals.pressure;
      default:
        return 1; // metrics we don't range-check — never block on them
    }
  }

  /// Hands-off "Monitor all vitals": reconnect if needed, then run every
  /// supported realtime measurement one after the other (ECG is intentionally
  /// excluded — it needs deliberate finger contact), sync so the readings land
  /// on the phone, and report the result as a felt state of being. Designed so
  /// the user can tap once, set the phone aside, and get a notification.
  Future<void> runAllVitals() async {
    if (allVitalsRunning) return;
    if (_sessionActive) {
      _set(() {
        _allVitalsPhase = AllVitalsPhase.failed;
        _allVitalsMessage =
            'Finish your active session before a full check-in.';
      });
      return;
    }

    _allVitalsRetakes.clear();
    _set(() {
      _allVitalsPhase = AllVitalsPhase.reconnecting;
      _allVitalsDone = 0;
      _allVitalsTotal = 0;
      _allVitalsCurrentLabel = null;
      _allVitalsFinishedAt = null;
      _allVitalsMessage = 'Connecting to your ring…';
    });
    unawaited(VitalsNotificationService.instance.requestPermissions());
    unawaited(VitalsNotificationService.instance.showProgress(done: 0, total: 0));

    // 1) Make sure the ring is live, auto-reconnecting if it dropped.
    if (!_isConnected) {
      await reconnectSavedRing(force: true);
    }
    if (_disposed) return;
    if (!_isConnected) {
      _failAllVitals(
        'Could not reach your ring. Make sure it is worn, charged, and nearby, '
        'then try again.',
      );
      return;
    }

    // 2) Supported realtime measurements only — skip ECG.
    final feature = _features;
    final actions = realtimeMeasurementActions
        .where((a) => feature?.supportsAny(a.featureKeys) ?? false)
        .toList();

    if (actions.isEmpty) {
      // Nothing to measure on demand; still sync so Home refreshes.
      _set(() {
        _allVitalsPhase = AllVitalsPhase.syncing;
        _allVitalsMessage = 'Syncing your latest data…';
      });
      await _syncDeviceData();
      _finishAllVitals();
      return;
    }

    _set(() {
      _allVitalsPhase = AllVitalsPhase.running;
      _allVitalsTotal = actions.length;
      _allVitalsMessage = 'Reading your vitals…';
    });

    // 3) Run each measurement serially, retrying on loose contact so we never
    //    record a zero/garbage reading, and noting anything that won't settle.
    for (var i = 0; i < actions.length; i++) {
      if (_disposed) return;
      final action = actions[i];
      var captured = false;
      for (var attempt = 0; attempt <= _kMaxVitalRetries; attempt++) {
        if (_disposed) return;
        if (!_isConnected) {
          _failAllVitals(
            'Your ring disconnected partway through. Try again once it settles.',
          );
          return;
        }
        _set(() {
          _allVitalsDone = i;
          _allVitalsCurrentLabel = action.label;
          _allVitalsMessage = attempt == 0
              ? 'Reading ${action.label.toLowerCase()}…'
              : 'Retrying ${action.label.toLowerCase()} — keep the ring snug…';
        });
        unawaited(
          VitalsNotificationService.instance
              .showProgress(done: i, total: actions.length),
        );
        await _runMeasurementAndWait(action);
        // Captured a fresh reading, or we already hold a good value for it.
        if (_measureCaptured || _plausibleVitalForType(action.type) != null) {
          captured = true;
          break;
        }
      }
      if (!captured) _allVitalsRetakes.add(action.label);
    }

    if (_disposed) return;

    // 4) Persist everything and refresh Home / widgets.
    _set(() {
      _allVitalsDone = actions.length;
      _allVitalsCurrentLabel = null;
      _allVitalsPhase = AllVitalsPhase.syncing;
      _allVitalsMessage = 'Saving to your phone…';
    });
    unawaited(
      VitalsNotificationService.instance
          .showProgress(done: actions.length, total: actions.length),
    );
    await _syncDeviceData();
    _finishAllVitals();
  }

  /// Starts [action] and awaits the ring reporting completion (or a backstop
  /// timeout). Completion is signalled from the native-event/timeout paths via
  /// [_maybeSignalStepFromState].
  Future<void> _runMeasurementAndWait(MeasurementAction action) async {
    final completer = Completer<void>();
    _allVitalsStepCompleter = completer;
    await runMeasurement(action);
    // If the command never actually started measuring, don't wait on it.
    if (!_isMeasuring) {
      if (identical(_allVitalsStepCompleter, completer)) {
        _allVitalsStepCompleter = null;
      }
      return;
    }
    try {
      await completer.future.timeout(const Duration(seconds: 75));
    } on TimeoutException {
      // Keep whatever we captured and move to the next reading.
    } finally {
      if (identical(_allVitalsStepCompleter, completer)) {
        _allVitalsStepCompleter = null;
      }
    }
  }

  /// Completes the in-flight all-vitals step once the controller is no longer
  /// measuring (the reading finished, failed, or the ring disconnected).
  void _maybeSignalStepFromState() {
    if (_isMeasuring) return;
    final completer = _allVitalsStepCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  void _failAllVitals(String message) {
    _set(() {
      _allVitalsPhase = AllVitalsPhase.failed;
      _allVitalsCurrentLabel = null;
      _allVitalsMessage = message;
      _allVitalsFinishedAt = DateTime.now();
    });
    unawaited(VitalsNotificationService.instance.showFailure(message));
    unawaited(_pushWidgetState());
  }

  void _finishAllVitals() {
    final state = currentWellnessState();
    final retakes = List<String>.of(_allVitalsRetakes);
    final retakeNote = retakes.isEmpty
        ? null
        : '${_joinLabels(retakes)} needed a retake — keep the ring snug.';
    _set(() {
      _allVitalsPhase = AllVitalsPhase.done;
      _allVitalsCurrentLabel = null;
      _allVitalsFinishedAt = DateTime.now();
      _allVitalsMessage = state.hasData
          ? "You're feeling ${state.title.toLowerCase()}."
              '${retakeNote == null ? '' : ' $retakeNote'}'
          : retakeNote ??
              'No clean readings came through. Make sure the ring is snug and '
                  'try again.';
    });
    unawaited(
      VitalsNotificationService.instance.showResult(state, retakeNote: retakeNote),
    );
    unawaited(_pushWidgetState());
  }

  static String _joinLabels(List<String> labels) {
    if (labels.length == 1) return labels.first;
    if (labels.length == 2) return '${labels[0]} and ${labels[1]}';
    return '${labels.sublist(0, labels.length - 1).join(', ')}, '
        'and ${labels.last}';
  }

  /// Push the latest state of being + biomarker readings to the widgets.
  Future<void> _pushWidgetState() async {
    try {
      await HomeWidgetService.instance.pushState(
        state: currentWellnessState(),
        connected: _isConnected,
        updatedAt: _vitals.updatedAt ?? DateTime.now(),
        biomarkers: _widgetBiomarkers(),
      );
    } on Object catch (error) {
      debugPrint('RING_WIDGET_PUSH failed: $error');
    }
  }

  /// The biomarker readings shown as a grid on the home-screen widget.
  List<(String, String)> _widgetBiomarkers() {
    final v = _vitals;
    final out = <(String, String)>[];
    if (v.heartRate != null) out.add(('Heart', '${v.heartRate} bpm'));
    if (v.bloodOxygen != null) out.add(('Oxygen', '${v.bloodOxygen}%'));
    if (v.hrv != null) out.add(('HRV', '${v.hrv} ms'));
    if (v.pressure != null) {
      out.add((
        'Stress',
        stressZoneLabel(stressZoneForLevel((v.pressure! / 100).clamp(0.0, 1.0))),
      ));
    }
    if (v.bloodGlucose != null) {
      out.add(('Glucose', v.bloodGlucose!.toStringAsFixed(1)));
    }
    final steps = HomeDashboard.from(this).todaySteps;
    if (steps > 0) out.add(('Steps', '$steps'));
    if (v.temperature != null) {
      out.add(('Temp', '${v.temperature!.toStringAsFixed(1)}°'));
    }
    return out.take(HomeWidgetService.biomarkerSlots).toList();
  }

  Future<void> startEcg() async {
    if (_sessionActive) {
      _set(() => _testStatus =
          'A session is recording — finish it before an ECG.');
      _publishMeasurementSnapshot();
      return;
    }
    if (_isMeasuring) return;
    _cancelEcgTimers();
    _set(() {
      _isMeasuring = true;
      _activeMeasurementLabel = 'ECG';
      _resetEcgSession();
      _ecgPreStartRemainingSeconds =
          EcgSessionSnapshot.preparationDuration.inSeconds;
      _testStatus = 'Get ready for ECG';
    });
    _publishMeasurementSnapshot();

    _ecgPreparationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed || _activeMeasurementLabel != 'ECG') {
        timer.cancel();
        return;
      }
      final remaining = (_ecgPreStartRemainingSeconds ?? 0) - 1;
      _set(() {
        _ecgPreStartRemainingSeconds = remaining <= 0 ? null : remaining;
        _testStatus = remaining <= 0
            ? 'Starting ECG contact detection'
            : 'Place your finger on the ring ECG contact';
      });
      _publishMeasurementSnapshot();
      if (remaining <= 0) {
        timer.cancel();
        _ecgPreparationTimer = null;
        unawaited(_beginEcgContactDetection());
      }
    });
  }

  Future<void> _beginEcgContactDetection() async {
    if (_disposed || _activeMeasurementLabel != 'ECG') return;
    try {
      final message = await _repo.startEcg();
      if (_disposed || _activeMeasurementLabel != 'ECG') return;
      final waitingForRing = !message.toLowerCase().contains('failed') &&
          !message.toLowerCase().contains('does not support');
      _set(() {
        if (waitingForRing) {
          _ecgSdkStarted = true;
          _ecgWaitingForContact = true;
          _testStatus = 'Touch and hold the ECG contact';
        } else {
          _finishEcgAttempt(message, successful: false);
        }
      });
      _publishMeasurementSnapshot();
      if (waitingForRing) {
        _startEcgSnapshotTicker();
        _ecgContactTimeout = Timer(_ecgContactDetectionTimeout, () {
          if (_disposed ||
              _activeMeasurementLabel != 'ECG' ||
              !_ecgWaitingForContact) {
            return;
          }
          unawaited(
            _stopEcgForReason(
              'No ECG contact detected. Please try again.',
              allowResult: false,
            ),
          );
        });
      }
    } on Object catch (error) {
      if (_disposed) return;
      _set(() {
        _testStatus = 'ECG failed: $error';
        _finishEcgAttempt('Start failed. Please try again.', successful: false);
      });
      _publishMeasurementSnapshot();
    }
  }

  Future<void> stopEcg() async {
    await _stopEcgForReason(
      'ECG stopped before completion. Please try again.',
      allowResult: false,
    );
  }

  Future<void> _stopEcgForReason(
    String reason, {
    required bool allowResult,
  }) async {
    if (_activeMeasurementLabel != 'ECG') return;
    final shouldStopSdk = _ecgSdkStarted;
    _cancelEcgTimers(keepSnapshotTicker: true);
    _set(() => _testStatus = shouldStopSdk ? 'Stopping ECG' : reason);
    final message = shouldStopSdk ? await _repo.stopEcg() : reason;
    if (_disposed) return;
    final success = allowResult && _ecgRecordingIsSuccessful();
    _set(() {
      _testStatus = success ? '$message. Reading ECG result...' : reason;
      _finishEcgAttempt(
        success ? 'ECG recording complete' : reason,
        successful: success,
      );
    });
    _publishMeasurementSnapshot();
    if (success) {
      await _readEcgResultAfterCompletion();
    }
  }

  Future<void> getEcgResult() async {
    if (_isMeasuring) return;
    await _readEcgResultAfterCompletion();
  }

  Future<void> _readEcgResultAfterCompletion() async {
    if (_readingEcgResult) return;
    // Already have a good diagnosis — just surface it (e.g. tapping "Result"
    // again after an automatic read already succeeded).
    if (_ecgResult != null && _ecgResult!.isMeasurementSuccessful) {
      _set(() => _testStatus = 'ECG result ready');
      _publishMeasurementSnapshot();
      return;
    }
    if (!_ecgSuccessful) {
      _set(() =>
          _testStatus = 'ECG was not completed successfully. Please try again.');
      _publishMeasurementSnapshot();
      return;
    }
    _readingEcgResult = true;
    _set(() => _testStatus = 'Reading ECG result');
    // The on-device AI diagnosis is computed asynchronously and is often not
    // ready the instant the recording ends — poll until a valid (non-noise)
    // diagnosis lands.
    ParsedEcgResult? result;
    for (var attempt = 0; attempt < 8; attempt++) {
      result = await _repo.getEcgResult(
        liveHeartRate: _ecgHeartRate,
        liveHrv: _ecgHrv,
      );
      if (_disposed) {
        _readingEcgResult = false;
        return;
      }
      if (result != null && result.isMeasurementSuccessful) break;
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (_disposed) {
        _readingEcgResult = false;
        return;
      }
    }
    _readingEcgResult = false;
    _set(() {
      if (result != null && result.isMeasurementSuccessful) {
        _testStatus = 'ECG result ready';
        _ecgResult = result;
      } else if (_ecgResult == null) {
        // Only report failure if we never captured a good result; never wipe a
        // previously-successful one on a late re-read.
        _testStatus = 'ECG result was unavailable or noisy. Please try again.';
      }
    });
    _publishMeasurementSnapshot();
  }

  Future<void> _beginMeasurement(
    String label,
    Future<String> Function() command, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    if (_isMeasuring) return;
    _measurementTimeout?.cancel();
    _set(() {
      _isMeasuring = true;
      _activeMeasurementLabel = label;
      _testStatus = 'Starting $label';
    });
    _publishMeasurementSnapshot();

    try {
      final message = await command();
      if (_disposed) return;
      final waitingForRing = !message.toLowerCase().contains('failed') &&
          !message.toLowerCase().contains('does not support');
      _set(() {
        _testStatus = waitingForRing
            ? '$message. Waiting for ring result...'
            : message;
        if (!waitingForRing) {
          _isMeasuring = false;
          _activeMeasurementLabel = null;
        }
      });
      _publishMeasurementSnapshot();
      if (waitingForRing) {
        _measurementTimeout = Timer(timeout, () {
          if (_disposed || !_isMeasuring) return;
          _completeMeasurement(
            '$label did not report completion within ${timeout.inSeconds}s',
            sync: true,
          );
        });
      }
    } on Object catch (error) {
      if (_disposed) return;
      _set(() {
        _isMeasuring = false;
        _activeMeasurementLabel = null;
        _testStatus = '$label failed: $error';
      });
      _publishMeasurementSnapshot();
    }
  }

  void _completeMeasurement(String message, {required bool sync}) {
    _measurementTimeout?.cancel();
    if (_disposed) return;
    _set(() {
      _isMeasuring = false;
      _activeMeasurementLabel = null;
      _testStatus = message;
    });
    _publishMeasurementSnapshot();
    _maybeSignalStepFromState();
    if (sync) {
      unawaited(_syncDeviceData());
    }
  }

  void _resetEcgSession() {
    _ecgPreStartRemainingSeconds = null;
    _ecgWaitingForContact = false;
    _ecgSdkStarted = false;
    _ecgSuccessful = false;
    _readingEcgResult = false;
    _ecgStartedAt = null;
    _ecgEndedAt = null;
    _ecgRawSamples.clear();
    _ecgFilteredSamples.clear();
    _ecgRr = null;
    _ecgHrv = null;
    _ecgHeartRate = null;
    _ecgBloodPressure = null;
    _ecgContactAttached = null;
    _ecgEndReason = null;
    _ecgFailureReason = null;
    _ecgResult = null;
  }

  void _cancelEcgTimers({bool keepSnapshotTicker = false}) {
    _measurementTimeout?.cancel();
    _measurementTimeout = null;
    _ecgPreparationTimer?.cancel();
    _ecgPreparationTimer = null;
    _ecgContactTimeout?.cancel();
    _ecgContactTimeout = null;
    if (!keepSnapshotTicker) {
      _ecgSnapshotTicker?.cancel();
      _ecgSnapshotTicker = null;
    }
  }

  void _beginEcgRecording(DateTime startedAt) {
    _ecgContactTimeout?.cancel();
    _ecgContactTimeout = null;
    _measurementTimeout?.cancel();
    _ecgStartedAt = startedAt;
    _ecgEndedAt = null;
    _ecgWaitingForContact = false;
    _ecgPreStartRemainingSeconds = null;
    _ecgRawSamples.clear();
    _ecgFilteredSamples.clear();
    _ecgEndReason = null;
    _ecgFailureReason = null;
    _ecgSuccessful = false;
    _testStatus = 'ECG recording started. Hold still.';
    _measurementTimeout = Timer(EcgSessionSnapshot.recommendedDuration, () {
      if (_disposed || _activeMeasurementLabel != 'ECG') return;
      unawaited(
        _stopEcgForReason('60-second ECG complete.', allowResult: true),
      );
    });
  }

  void _finishEcgAttempt(String reason, {required bool successful}) {
    _cancelEcgTimers();
    _ecgEndedAt ??= DateTime.now();
    _ecgEndReason = reason;
    _ecgFailureReason = successful ? null : reason;
    _ecgSuccessful = successful;
    _ecgWaitingForContact = false;
    _ecgPreStartRemainingSeconds = null;
    _ecgSdkStarted = false;
    if (!successful) {
      _ecgResult = null;
    }
    _isMeasuring = false;
    _activeMeasurementLabel = null;
  }

  void _startEcgSnapshotTicker() {
    _ecgSnapshotTicker?.cancel();
    _ecgSnapshotTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed || _activeMeasurementLabel != 'ECG') {
        timer.cancel();
        return;
      }
      _publishMeasurementSnapshot();
    });
  }

  void _mergeEcgUpdate(_EcgEventUpdate update) {
    if (!update.hasData) return;

    if (update.contactAttached != null) {
      _ecgContactAttached = update.contactAttached;
    } else if (_ecgWaitingForContact && update.hasWaveform) {
      _ecgContactAttached = true;
    }

    if (_ecgWaitingForContact && update.detectsContact) {
      _beginEcgRecording(DateTime.now());
    }

    if (_ecgStartedAt == null) return;

    if (update.rawSamples.isNotEmpty) {
      _ecgRawSamples.addAll(update.rawSamples);
    }
    if (update.filteredSamples.isNotEmpty) {
      _ecgFilteredSamples.addAll(update.filteredSamples);
    }
    _ecgRr = update.rr ?? _ecgRr;
    _ecgHrv = update.hrv ?? _ecgHrv;
    _ecgHeartRate = update.heartRate ?? _ecgHeartRate;
    _ecgBloodPressure = update.bloodPressure ?? _ecgBloodPressure;
  }

  bool _ecgRecordingIsSuccessful() {
    final startedAt = _ecgStartedAt;
    final endedAt = _ecgEndedAt ?? DateTime.now();
    if (startedAt == null || _ecgFailureReason != null) return false;
    final elapsed = endedAt.difference(startedAt);
    return elapsed >= EcgSessionSnapshot.recommendedDuration &&
        (_ecgFilteredSamples.isNotEmpty || _ecgRawSamples.isNotEmpty);
  }

  EcgSessionSnapshot _currentEcgSessionSnapshot() {
    return EcgSessionSnapshot(
      startedAt: _ecgStartedAt,
      endedAt: _ecgEndedAt,
      capturedAt: DateTime.now(),
      preStartRemainingSeconds: _ecgPreStartRemainingSeconds,
      waitingForContact: _ecgWaitingForContact,
      rawSamples: List<double>.unmodifiable(_ecgRawSamples),
      filteredSamples: List<double>.unmodifiable(_ecgFilteredSamples),
      rr: _ecgRr,
      hrv: _ecgHrv,
      heartRate: _ecgHeartRate,
      bloodPressure: _ecgBloodPressure,
      contactAttached: _ecgContactAttached,
      endReason: _ecgEndReason,
      failureReason: _ecgFailureReason,
      successful: _ecgSuccessful,
    );
  }

  MeasurementPageSnapshot _currentMeasurementSnapshot() {
    return MeasurementPageSnapshot(
      connected: _isConnected,
      busy: _isMeasuring,
      activeMeasurement: _activeMeasurementLabel,
      status: _testStatus,
      ecgResult: _ecgResult,
      ecgSession: _currentEcgSessionSnapshot(),
      features: _features,
      history: _history,
      vitals: _vitals,
    );
  }

  void _publishMeasurementSnapshot() {
    measurementSnapshot.value = _currentMeasurementSnapshot();
    _syncForegroundService();
  }

  void _syncForegroundService() {
    if (!Platform.isAndroid) return;
    if (_foregroundServiceEnabled && _isConnected) {
      unawaited(
        RingForegroundService.start().then((_) => _updateForegroundNotification()),
      );
    } else {
      unawaited(RingForegroundService.stop());
    }
  }

  void _updateForegroundNotification() {
    if (!Platform.isAndroid || !_foregroundServiceEnabled || !_isConnected) return;
    final battery = _vitals.battery != null && _vitals.battery! > 0
        ? _vitals.battery
        : _basicInfo?.batteryPower;
    final heartRate = _vitals.heartRate != null && _vitals.heartRate! > 0 ? _vitals.heartRate : null;
    final spO2 = _vitals.bloodOxygen != null && _vitals.bloodOxygen! > 0 ? _vitals.bloodOxygen : null;
    final hrv = _vitals.hrv != null && _vitals.hrv! > 0 ? _vitals.hrv : null;

    final parts = <String>[
      if (battery != null && battery > 0) 'Battery $battery%',
      if (heartRate != null) 'HR $heartRate',
      if (spO2 != null) 'SpO₂ $spO2%',
      if (hrv != null) 'HRV $hrv',
    ];
    final body = parts.isEmpty ? 'Ring connected' : parts.join(' · ');

    unawaited(
      RingForegroundService.update(
        title: _pairedRing?.displayName ?? 'Vyana',
        body: body,
      ),
    );
  }
}

/// Single owner of the ring connection for the whole app.
final ringControllerProvider = ChangeNotifierProvider<RingController>((ref) {
  final controller = RingController(
    historyCache: ref.watch(ringHistoryCacheServiceProvider),
  );
  controller.initialize();
  ref.onDispose(controller.dispose);
  return controller;
});

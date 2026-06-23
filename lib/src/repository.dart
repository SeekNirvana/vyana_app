part of '../main.dart';

class RingRepository {
  final VyanaSdk _plugin = VyanaSdk();
  static const MethodChannel _permissionChannel = MethodChannel(
    'vyana/permissions',
  );
  static const MethodChannel _deviceChannel = MethodChannel(
    'vyana/ring_device',
  );

  Future<void> initialize(void Function(dynamic event) onEvent) async {
    await _plugin.initPlugin(isReconnectEnable: true, isLogEnable: true);
    _plugin.onListening(onEvent);
  }

  String get sdkVersion => _plugin.getPluginVersion();

  Future<bool> isConnected() async {
    final state = await bluetoothState();
    return state == BluetoothState.connected;
  }

  Future<DeviceBasicSnapshot?> probeConnectedBasicInfo() async {
    try {
      final response = await _plugin.queryDeviceBasicInfo().timeout(
        const Duration(seconds: 5),
      );
      if (response?.statusCode != PluginState.succeed) return null;
      return DeviceBasicSnapshot.fromDynamic(response?.data);
    } on Object catch (error) {
      debugPrint('PRANA_CONNECTION_PROBE_FAILED $error');
      return null;
    }
  }

  Future<int?> bluetoothState() async {
    final adapterEnabled = await _androidBluetoothEnabled();
    if (adapterEnabled == false) return BluetoothState.off;

    try {
      final state = await _plugin.getBluetoothState();
      return state;
    } on MissingPluginException {
      return null;
    }
  }

  Future<bool?> _androidBluetoothEnabled() async {
    if (!Platform.isAndroid) return null;

    try {
      return await _deviceChannel.invokeMethod<bool>('isBluetoothEnabled');
    } on MissingPluginException {
      return null;
    } on Object catch (error) {
      debugPrint('ANDROID_BLUETOOTH_STATE_FAILED $error');
      return null;
    }
  }

  Future<ScanAccess> ensureScanAccess() async {
    if (!Platform.isAndroid) return const ScanAccess.granted();

    try {
      final payload = await _permissionChannel.invokeMapMethod<String, dynamic>(
        'requestBleScanAccess',
      );
      return ScanAccess.fromMap(payload ?? const {});
    } on MissingPluginException {
      return const ScanAccess.granted();
    }
  }

  Future<List<dynamic>> scanDevices({int seconds = 6}) async {
    final devices = await _plugin.scanDevice(time: seconds);
    final list = List<dynamic>.from(devices ?? const []);
    list.sort((a, b) => deviceRssi(b).compareTo(deviceRssi(a)));
    return list;
  }

  Future<bool> connect(dynamic device) async {
    if (await isConnected()) return true;

    final stateReady = _waitForConnected(timeout: const Duration(seconds: 12));
    final sdkResult = _plugin
        .connectDevice(device)
        .then((connected) => connected == true)
        .timeout(const Duration(seconds: 12), onTimeout: () => false)
        .catchError((Object _) => false);

    final ready = await stateReady;
    if (ready) return true;

    await sdkResult;
    return isConnected();
  }

  Future<bool> _waitForConnected({
    required Duration timeout,
    Duration interval = const Duration(milliseconds: 350),
  }) async {
    final watch = Stopwatch()..start();
    while (watch.elapsed < timeout) {
      if (await isConnected()) return true;
      await Future<void>.delayed(interval);
    }
    return isConnected();
  }

  Future<bool> disconnect() async {
    final disconnected = await _plugin.disconnectDevice();
    return disconnected == true;
  }

  Future<bool> unpair() async {
    if (await isConnected()) {
      final disconnected = await disconnect();
      if (!disconnected) return false;
    }

    try {
      await _plugin.resetBond();
      return true;
    } on MissingPluginException {
      return true;
    } on Object catch (error) {
      debugPrint('PRANA_UNPAIR_FAILED $error');
      return false;
    }
  }

  Future<RingSyncResult> sync() async {
    final basic = await _safePluginCall<DeviceBasicSnapshot?>(() async {
      final response = await _plugin
          .queryDeviceBasicInfo()
          .timeout(const Duration(seconds: 8));
      return response?.statusCode == PluginState.succeed
          ? DeviceBasicSnapshot.fromDynamic(response?.data)
          : null;
    });

    final readyForFeatureQuery = await _waitForConnected(
      timeout: const Duration(seconds: 4),
      interval: const Duration(milliseconds: 250),
    );
    final features = readyForFeatureQuery ? await _resolveDeviceFeatures() : null;
    if (!readyForFeatureQuery) {
      debugPrint('RING_FEATURES skipped until Bluetooth ReadWriteOK');
    }

    final supportsInvasiveHistory =
        features?.supportsAny(const [
          'isSupportBloodGlucose',
          'isSupportUricAcid',
          'isSupportBloodKetone',
          'isSupportBloodFat',
        ]) ??
        true;
    final history = RingHistory(
      steps: await _queryHistorySafely(HealthDataType.step, 'steps'),
      sleep: await _queryHistorySafely(HealthDataType.sleep, 'sleep'),
      heartRate: await _queryHistorySafely(
        HealthDataType.heartRate,
        'heartRate',
      ),
      bloodPressure: await _queryHistorySafely(
        HealthDataType.bloodPressure,
        'bloodPressure',
      ),
      combined: await _queryHistorySafely(
        HealthDataType.combinedData,
        'combined',
      ),
      invasive: await _queryHistorySafely(
        HealthDataType.invasiveComprehensiveData,
        'invasive',
        enabled: supportsInvasiveHistory,
      ),
      sport: await _queryHistorySafely(
        HealthDataType.sportHistoryData,
        'sport',
        enabled: features?.supports('isSupportSport') ?? true,
      ),
    );

    debugPrint('RING_BASIC ${basic?.toLogString() ?? 'unavailable'}');
    debugPrint('RING_FEATURES ${features?.toLogString() ?? 'unavailable'}');
    debugPrint('RING_HISTORY records=${history.totalRecords}');
    return RingSyncResult(
      basicInfo: basic,
      features: features,
      history: history,
      vitals: RingVitals.fromHistory(history, basic),
    );
  }

  /// Fetches the capability bitmap, retrying when it comes back empty.
  ///
  /// Android answers from a live `isSupportFunction` query, but iOS derives the
  /// bitmap from advertisement/scan data plus the post-connect handshake. After
  /// an auto-reconnect (no fresh scan) the SDK can briefly report no
  /// capabilities, which would otherwise hide every measurement. We retry across
  /// a few seconds and, as a last resort on iOS, refresh advertisement data with
  /// a short scan before giving up.
  Future<DeviceFeatureSnapshot?> _resolveDeviceFeatures() async {
    Future<DeviceFeatureSnapshot?> query() {
      return _safePluginCall<DeviceFeatureSnapshot?>(() async {
        final feature = await _plugin.getDeviceFeature();
        return feature == null
            ? null
            : DeviceFeatureSnapshot.fromDynamic(feature);
      });
    }

    // The iOS SDK already polls the peripheral's supportItems for a few seconds
    // internally, so a null here means the bitmap is genuinely absent — most
    // often because the ring was auto-reconnected without a fresh scan. Refresh
    // advertisement data with a short scan and re-query before giving up.
    var snapshot = await query();
    if (snapshot != null || !Platform.isIOS) return snapshot;

    debugPrint('RING_FEATURES empty on iOS, refreshing via scan');
    await _safePluginCall(() => _plugin.scanDevice(time: 3));
    for (var attempt = 0; snapshot == null && attempt < 2; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      snapshot = await query();
    }
    return snapshot;
  }

  Future<List<dynamic>> _queryHistorySafely(
    int type,
    String label, {
    bool enabled = true,
  }) async {
    if (!enabled) {
      debugPrint('RING_HISTORY $label skipped by feature flags');
      return const [];
    }

    final records = await _safePluginCall<List<dynamic>>(
      () => _queryHistory(type),
    );
    final safeRecords = records ?? const <dynamic>[];
    debugPrint('RING_HISTORY $label=${safeRecords.length}');
    return safeRecords;
  }

  Future<List<dynamic>> _queryHistory(int type) async {
    final response = await _plugin.queryDeviceHealthData(type);
    if (response?.statusCode != PluginState.succeed) return [];
    return List<dynamic>.from(response?.data ?? const []);
  }

  Future<HealthMonitoringApplyResult> setHealthMonitoring({
    required bool enabled,
    required int intervalMinutes,
  }) async {
    final interval = clampHealthMonitoringInterval(intervalMinutes);
    final response = await _safePluginCall(() {
      return _plugin.setDeviceHealthMonitoringMode(
        isEnable: enabled,
        interval: interval,
      );
    });

    final code = readInt(response, const ['statusCode', 'code']);
    final successful = code == PluginState.succeed;
    debugPrint(
      'HEALTH_MONITORING_APPLY enabled=$enabled interval=${interval}m '
      'status=$code ok=$successful',
    );
    final message = successful
        ? enabled
            ? 'Ring confirmed · every $interval min'
            : 'Ring confirmed · monitoring off'
        : response == null
            ? 'Ring did not respond. Stay close and try again.'
            : _statusMessage(response, 'Health monitoring updated');

    return HealthMonitoringApplyResult(
      successful: successful,
      message: message,
      settings: HealthMonitoringSettings(
        enabled: enabled,
        intervalMinutes: interval,
        ringAcknowledged: successful,
        lastMessage: message,
      ),
    );
  }

  Future<String> findDevice() async {
    final response = await _safePluginCall(() {
      return _plugin.findDevice();
    });
    return _statusMessage(response, 'Find ring command sent');
  }

  Future<bool> restoreFactorySettings() async {
    final response = await _safePluginCall(() => _plugin.restoreFactorySettings());
    final ok = response?.statusCode == PluginState.succeed;
    debugPrint('PRANA_FACTORY_RESET status=${response?.statusCode} ok=$ok');
    return ok;
  }

  Future<bool> deleteRingHealthData(int type, String label) async {
    final response = await _safePluginCall(
      () => _plugin.deleteDeviceHealthData(type),
    );
    final ok = response?.statusCode == PluginState.succeed;
    debugPrint('PRANA_DELETE_HISTORY $label status=${response?.statusCode} ok=$ok');
    return ok;
  }

  Future<bool> deleteAllSupportedRingHealthData(
    DeviceFeatureSnapshot? features,
  ) async {
    final targets = ringHealthDeleteTargets(features);
    var allOk = true;
    for (final target in targets) {
      final ok = await deleteRingHealthData(target.type, target.label);
      if (!ok) allOk = false;
    }
    debugPrint('PRANA_DELETE_HISTORY allOk=$allOk types=${targets.length}');
    return allOk;
  }

  Future<RingNameUpdateResult> renameConnectedRing(String name) async {
    final cleanName = normalizeRingName(name);
    if (cleanName == null) {
      return const RingNameUpdateResult(
        successful: false,
        name: '',
        message: 'Ring name is required',
      );
    }

    final response = await _safePluginCall<Map<dynamic, dynamic>>(() async {
      final payload = await _deviceChannel.invokeMapMethod<String, dynamic>(
        'setDeviceName',
        {'name': cleanName},
      );
      return Map<dynamic, dynamic>.from(payload ?? const {});
    });
    debugPrint('RING_RENAME_RESPONSE $response');
    final code = readInt(response, const ['statusCode', 'code']);
    if (code == PluginState.succeed) {
      return RingNameUpdateResult(
        successful: true,
        name: cleanName,
        message: 'Ring renamed to $cleanName',
      );
    }
    if (code == PluginState.unavailable) {
      return RingNameUpdateResult(
        successful: false,
        name: cleanName,
        message: 'Ring does not support BLE name changes',
      );
    }
    if (response == null) {
      return RingNameUpdateResult(
        successful: false,
        name: cleanName,
        message: 'Ring rename command is unavailable on this platform',
      );
    }
    return RingNameUpdateResult(
      successful: false,
      name: cleanName,
      message: 'Ring name change failed${_ringRenameDetails(response)}',
    );
  }

  Future<String> measure(
    DeviceAppControlMeasureHealthDataType type,
    bool isEnable,
  ) async {
    final response = await _safePluginCall(() {
      return _plugin.appControlMeasureHealthData(isEnable, type);
    });
    return _statusMessage(
      response,
      '${measureTypeLabel(type)} measurement started',
    );
  }

  // ── Activity sessions (Sadhana) ──────────────────────────────────────────
  /// Drives the ring's sport mode. State is one of DeviceSportState; sportType
  /// is a DeviceSportType code.
  Future<bool> controlSport(DeviceSportState state, int sportType) async {
    final response = await _safePluginCall(
      () => _plugin.appControlSport(state, sportType),
    );
    return response?.statusCode == PluginState.succeed;
  }

  Future<bool> startSport(int sportType) =>
      controlSport(DeviceSportState.start, sportType);
  Future<bool> pauseSport(int sportType) =>
      controlSport(DeviceSportState.pause, sportType);
  Future<bool> resumeSport(int sportType) =>
      controlSport(DeviceSportState.continueSport, sportType);
  Future<bool> stopSport(int sportType) =>
      controlSport(DeviceSportState.stop, sportType);

  /// Toggles realtime data streaming (used to capture live HR during a session).
  Future<bool> setRealtimeData(
    bool enable, {
    DeviceRealTimeDataType dataType = DeviceRealTimeDataType.heartRate,
  }) async {
    final response = await _safePluginCall(
      () => _plugin.realTimeDataUpload(enable, dataType: dataType),
    );
    return response?.statusCode == PluginState.succeed;
  }

  Future<String> startEcg() async {
    final response = await _safePluginCall(() => _plugin.startECGMeasurement());
    return _statusMessage(response, 'ECG measurement started');
  }

  Future<String> stopEcg() async {
    final response = await _safePluginCall(() => _plugin.stopECGMeasurement());
    return _statusMessage(response, 'ECG measurement stopped');
  }

  Future<ParsedEcgResult?> getEcgResult({
    int? liveHeartRate,
    int? liveHrv,
  }) async {
    final response = await _safePluginCall(() => _plugin.getECGResult());
    if (response?.statusCode != PluginState.succeed || response?.data == null) {
      return null;
    }
    return ParsedEcgResult.fromDynamic(
      response!.data,
      liveHeartRate: liveHeartRate,
      liveHrv: liveHrv,
    );
  }
}

class ScanAccess {
  const ScanAccess({
    required this.granted,
    required this.permissionsGranted,
    required this.locationEnabled,
    required this.missingPermissions,
  });

  const ScanAccess.granted()
    : granted = true,
      permissionsGranted = true,
      locationEnabled = true,
      missingPermissions = const [];

  final bool granted;
  final bool permissionsGranted;
  final bool locationEnabled;
  final List<String> missingPermissions;

  factory ScanAccess.fromMap(Map<dynamic, dynamic> source) {
    return ScanAccess(
      granted: source['granted'] == true,
      permissionsGranted: source['permissionsGranted'] == true,
      locationEnabled: source['locationEnabled'] == true,
      missingPermissions: List<String>.from(
        source['missingPermissions'] ?? const [],
      ),
    );
  }

  String get message {
    if (!permissionsGranted) {
      return 'Bluetooth or Nearby Devices permission is required to discover rings.';
    }
    if (!locationEnabled) {
      return 'Turn on Location services so this phone can discover nearby BLE rings.';
    }
    return 'Bluetooth scan access is ready.';
  }

  String get denialTitle {
    if (!permissionsGranted) return 'Bluetooth access needed';
    if (!locationEnabled) return 'Location services off';
    return 'Scan access needed';
  }

  String get denialIcon {
    if (!permissionsGranted) return 'bluetooth';
    if (!locationEnabled) return 'target';
    return 'shield';
  }

  String get denialHint {
    if (!permissionsGranted) {
      return 'Allow Bluetooth and Nearby Devices for Vyana in system settings, '
          'then try scanning again.';
    }
    if (!locationEnabled) {
      return 'Turn on Location so this phone can discover nearby BLE rings, '
          'then try scanning again.';
    }
    return message;
  }

  bool get needsAppSettings => !permissionsGranted;

  bool get needsLocationSettings => permissionsGranted && !locationEnabled;
}

Future<T?> _safePluginCall<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on MissingPluginException {
    return null;
  } on Object catch (error) {
    debugPrint('RING_PLUGIN_CALL_FAILED $error');
    return null;
  }
}

String _statusMessage(dynamic response, String success) {
  final code = readInt(response, const ['statusCode', 'code']);
  if (code == PluginState.succeed || response == null) return success;
  if (code == PluginState.unavailable) {
    return 'Device does not support this command';
  }
  return 'Command failed';
}

String _ringRenameDetails(dynamic response) {
  final details = <String>[];
  final sdkCode = readInt(response, const ['sdkCode']);
  if (sdkCode != null) details.add('SDK code $sdkCode');

  final sdkState = readAny(response, const ['sdkState']);
  if (sdkState != null && sdkState.toString().isNotEmpty) {
    details.add('SDK state $sdkState');
  }

  final data = readAny(response, const ['data']);
  if (data != null && data.toString().isNotEmpty && data.toString() != '{}') {
    details.add('data $data');
  }

  return details.isEmpty ? '' : ' (${details.join(', ')})';
}

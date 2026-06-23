part of '../main.dart';

class RingSyncResult {
  const RingSyncResult({
    required this.basicInfo,
    required this.features,
    required this.history,
    required this.vitals,
  });

  final DeviceBasicSnapshot? basicInfo;
  final DeviceFeatureSnapshot? features;
  final RingHistory history;
  final RingVitals vitals;
}

class RingNameUpdateResult {
  const RingNameUpdateResult({
    required this.successful,
    required this.name,
    required this.message,
  });

  final bool successful;
  final String name;
  final String message;
}

class RingResetResult {
  const RingResetResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}

class RingHealthDeleteTarget {
  const RingHealthDeleteTarget({
    required this.type,
    required this.label,
  });

  final int type;
  final String label;
}

/// Health history types to wipe on the ring when factory reset is unavailable.
/// Mirrors the history types Vyana syncs, gated on the same feature flags.
List<RingHealthDeleteTarget> ringHealthDeleteTargets(
  DeviceFeatureSnapshot? features,
) {
  final supportsInvasive =
      features?.supportsAny(const [
        'isSupportBloodGlucose',
        'isSupportUricAcid',
        'isSupportBloodKetone',
        'isSupportBloodFat',
      ]) ??
      true;
  final supportsSport = features?.supports('isSupportSport') ?? true;

  return [
    const RingHealthDeleteTarget(type: HealthDataType.step, label: 'step'),
    const RingHealthDeleteTarget(type: HealthDataType.sleep, label: 'sleep'),
    const RingHealthDeleteTarget(
      type: HealthDataType.heartRate,
      label: 'heartRate',
    ),
    const RingHealthDeleteTarget(
      type: HealthDataType.bloodPressure,
      label: 'bloodPressure',
    ),
    const RingHealthDeleteTarget(
      type: HealthDataType.combinedData,
      label: 'combined',
    ),
    if (supportsInvasive)
      const RingHealthDeleteTarget(
        type: HealthDataType.invasiveComprehensiveData,
        label: 'invasive',
      ),
    if (supportsSport)
      const RingHealthDeleteTarget(
        type: HealthDataType.sportHistoryData,
        label: 'sport',
      ),
  ];
}

const _coreRingHealthDeleteLabels = {
  'step',
  'sleep',
  'heartRate',
  'bloodPressure',
  'combined',
};

bool isCoreRingHealthDeleteLabel(String label) =>
    _coreRingHealthDeleteLabels.contains(label);

/// True when every core delete succeeded and no core delete hard-failed.
/// Optional types (sport, invasive) may return [PluginState.unavailable] — that
/// is normal on rings that sync sport but do not expose a delete command.
bool ringHealthDeleteSucceeded(
  Iterable<({String label, int? statusCode})> results,
) {
  var anyCoreSuccess = false;
  var anyCoreFailure = false;

  for (final result in results) {
    final isCore = isCoreRingHealthDeleteLabel(result.label);
    switch (result.statusCode) {
      case PluginState.succeed:
        if (isCore) anyCoreSuccess = true;
      case PluginState.unavailable:
        break;
      default:
        if (isCore) anyCoreFailure = true;
    }
  }

  return !anyCoreFailure && anyCoreSuccess;
}

/// SDK-allowed automatic health monitoring interval (minutes).
const kHealthMonitoringMinInterval = 1;
const kHealthMonitoringMaxInterval = 60;
const kHealthMonitoringDefaultInterval = 30;
const kHealthMonitoringPresetIntervals = [5, 10, 15, 30, 45, 60];

int clampHealthMonitoringInterval(int minutes) {
  return minutes.clamp(kHealthMonitoringMinInterval, kHealthMonitoringMaxInterval);
}

class HealthMonitoringSettings {
  const HealthMonitoringSettings({
    required this.enabled,
    required this.intervalMinutes,
    required this.ringAcknowledged,
    this.lastMessage,
  });

  final bool enabled;
  final int intervalMinutes;
  final bool ringAcknowledged;
  final String? lastMessage;

  String get summaryLabel {
    if (!enabled) return 'Off';
    return '${intervalMinutes}m';
  }

  HealthMonitoringSettings copyWith({
    bool? enabled,
    int? intervalMinutes,
    bool? ringAcknowledged,
    String? lastMessage,
  }) {
    return HealthMonitoringSettings(
      enabled: enabled ?? this.enabled,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      ringAcknowledged: ringAcknowledged ?? this.ringAcknowledged,
      lastMessage: lastMessage ?? this.lastMessage,
    );
  }
}

class HealthMonitoringApplyResult {
  const HealthMonitoringApplyResult({
    required this.successful,
    required this.message,
    required this.settings,
  });

  final bool successful;
  final String message;
  final HealthMonitoringSettings settings;
}

class EcgSessionSnapshot {
  const EcgSessionSnapshot({
    required this.startedAt,
    required this.endedAt,
    required this.capturedAt,
    required this.preStartRemainingSeconds,
    required this.waitingForContact,
    required this.rawSamples,
    required this.filteredSamples,
    required this.rr,
    required this.hrv,
    required this.heartRate,
    required this.bloodPressure,
    required this.contactAttached,
    required this.endReason,
    required this.failureReason,
    required this.successful,
  });

  static const recommendedDuration = Duration(seconds: 60);
  static const preparationDuration = Duration(seconds: 5);

  factory EcgSessionSnapshot.empty() {
    final now = DateTime.now();
    return EcgSessionSnapshot(
      startedAt: null,
      endedAt: null,
      capturedAt: now,
      preStartRemainingSeconds: null,
      waitingForContact: false,
      rawSamples: const [],
      filteredSamples: const [],
      rr: null,
      hrv: null,
      heartRate: null,
      bloodPressure: null,
      contactAttached: null,
      endReason: null,
      failureReason: null,
      successful: false,
    );
  }

  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime capturedAt;
  final int? preStartRemainingSeconds;
  final bool waitingForContact;
  final List<double> rawSamples;
  final List<double> filteredSamples;
  final int? rr;
  final int? hrv;
  final int? heartRate;
  final String? bloodPressure;
  final bool? contactAttached;
  final String? endReason;
  final String? failureReason;
  final bool successful;

  bool get hasSession =>
      isPreparing ||
      waitingForContact ||
      startedAt != null ||
      endedAt != null ||
      failureReason != null;

  bool get isPreparing => preStartRemainingSeconds != null;

  bool get isActive =>
      isPreparing || waitingForContact || startedAt != null && endedAt == null;

  bool get isRecording => startedAt != null && endedAt == null;

  bool get canReadResult => successful && failureReason == null;

  List<double> get displaySamples =>
      filteredSamples.isNotEmpty ? filteredSamples : rawSamples;

  int get sampleCount => rawSamples.length > filteredSamples.length
      ? rawSamples.length
      : filteredSamples.length;

  Duration get elapsed {
    final start = startedAt;
    if (start == null) return Duration.zero;
    final end = endedAt ?? capturedAt;
    final value = end.difference(start);
    return value.isNegative ? Duration.zero : value;
  }

  Duration get remaining {
    if (!isRecording) return Duration.zero;
    final value = recommendedDuration - elapsed;
    return value.isNegative ? Duration.zero : value;
  }

  double get progress {
    final preStart = preStartRemainingSeconds;
    if (preStart != null) {
      final completed =
          preparationDuration.inSeconds - preStart.clamp(0, 999).toInt();
      return (completed / preparationDuration.inSeconds)
          .clamp(0.0, 1.0)
          .toDouble();
    }
    if (waitingForContact) return 0;
    final ratio = elapsed.inMilliseconds / recommendedDuration.inMilliseconds;
    return ratio.clamp(0.0, 1.0).toDouble();
  }

  String get contactLabel {
    final attached = contactAttached;
    if (attached == null) return 'Contact unknown';
    return attached ? 'Contact good' : 'Contact lost';
  }

  String get stateLabel {
    final preStart = preStartRemainingSeconds;
    if (preStart != null) return 'Starting in ${preStart}s';
    if (waitingForContact) return 'Waiting for contact';
    if (isRecording) return 'Recording';
    if (successful) return 'Completed';
    if (failureReason != null) return 'Try again';
    return 'Ready';
  }
}

class ParsedEcgResult {
  const ParsedEcgResult({
    required this.heartRate,
    required this.qrsType,
    required this.afFlag,
    required this.hrv,
    required this.heavyLoad,
    required this.pressure,
    required this.body,
    required this.sympatheticActivityIndex,
    required this.respiratoryRate,
    required this.interpretation,
  });

  factory ParsedEcgResult.fromDynamic(
    dynamic source, {
    int? liveHeartRate,
    int? liveHrv,
  }) {
    final heartRate =
        _positiveInt(liveHeartRate) ??
        _positiveInt(readInt(source, const ['hearRate', 'heartRate']));
    final hrv =
        _positiveDouble(liveHrv?.toDouble()) ??
        _positiveDouble(readDouble(source, const ['hrv', 'hrvNorm']));
    final qrsType = readInt(source, const ['qrsType']) ?? 0;
    final afFlag = readBool(source, const ['afFlag', 'afflag']) ?? false;

    return ParsedEcgResult(
      heartRate: heartRate,
      qrsType: qrsType,
      afFlag: afFlag,
      hrv: hrv,
      heavyLoad: _positiveDouble(readDouble(source, const ['heavyLoad'])),
      pressure: _positiveDouble(readDouble(source, const ['pressure'])),
      body: _positiveDouble(readDouble(source, const ['body'])),
      sympatheticActivityIndex: _positiveDouble(
        readDouble(source, const ['sympatheticActivityIndex']),
      ),
      respiratoryRate: _positiveInt(
        readInt(source, const ['respiratoryRate', 'respirationRate']),
      ),
      interpretation: ecgInterpretation(
        afFlag: afFlag,
        qrsType: qrsType,
        heartRate: heartRate,
        hrv: hrv,
      ),
    );
  }

  final int? heartRate;
  final int qrsType;
  final bool afFlag;
  final double? hrv;
  final double? heavyLoad;
  final double? pressure;
  final double? body;
  final double? sympatheticActivityIndex;
  final int? respiratoryRate;
  final String interpretation;

  bool get isMeasurementSuccessful => qrsType != 0 && qrsType != 14;

  String get summaryText {
    final rate = heartRate == null ? '-' : '$heartRate bpm';
    final hrvText = hrv == null ? '-' : '${hrv!.toStringAsFixed(0)} ms';
    return '$interpretation - HR $rate - HRV $hrvText';
  }
}

int? _positiveInt(int? value) {
  if (value == null || value <= 0) return null;
  return value;
}

double? _positiveDouble(double? value) {
  if (value == null || value <= 0) return null;
  return value;
}

String ecgInterpretation({
  required bool afFlag,
  required int qrsType,
  required int? heartRate,
  required double? hrv,
}) {
  if (afFlag) return 'Atrial fibrillation flag';

  switch (qrsType) {
    case 14:
      return 'Failed or noisy measurement';
    case 5:
      return 'Ventricular premature beat';
    case 9:
      return 'Atrial premature beat';
    case 1:
      if (heartRate != null && heartRate <= 50) {
        return 'Suspected bradycardia';
      }
      if (heartRate != null && heartRate >= 120) {
        return 'Suspected tachycardia';
      }
      if (hrv != null && hrv >= 125) {
        return 'Suspected sinus arrhythmia';
      }
      return 'Normal ECG';
    default:
      return qrsType == 0 ? 'No ECG diagnosis' : 'QRS type $qrsType';
  }
}

class DeviceBasicSnapshot {
  const DeviceBasicSnapshot({
    required this.deviceId,
    required this.deviceType,
    required this.batteryStatus,
    required this.batteryPower,
    required this.firmwareVersion,
  });

  final String deviceId;
  final String deviceType;
  final String batteryStatus;
  final int? batteryPower;
  final String firmwareVersion;

  factory DeviceBasicSnapshot.fromDynamic(dynamic source) {
    return DeviceBasicSnapshot(
      deviceId:
          readAny(source, const ['deviceID', 'deviceId', 'id'])?.toString() ??
          '-',
      deviceType:
          readAny(source, const ['deviceType'])?.toString().split('.').last ??
          '-',
      batteryStatus: normalizedBatteryStatus(
        readAny(source, const ['batteryStatus']),
      ),
      batteryPower: readInt(source, const ['batteryPower', 'power', 'battery']),
      firmwareVersion:
          readAny(source, const ['firmwareVersion'])?.toString() ??
          _firmwareFromParts(source),
    );
  }

  String toLogString() {
    return 'deviceId=$deviceId type=$deviceType battery=$batteryPower status=$batteryStatus firmware=$firmwareVersion';
  }
}

String _firmwareFromParts(dynamic source) {
  final major = readInt(source, const ['firmwareMajorVersion']);
  final sub = readInt(source, const ['firmwareSubVersion']);
  if (major == null || sub == null) return '-';
  return '$major.$sub';
}

class SavedPranaRing {
  const SavedPranaRing({
    required this.name,
    required this.address,
    required this.macAddress,
    required this.deviceIdentifier,
    required this.deviceId,
    required this.deviceType,
    required this.rssi,
    required this.batteryPower,
    required this.batteryStatus,
    required this.firmwareVersion,
    required this.lastSeenAt,
    required this.lastConnectedAt,
  });

  final String? name;
  final String? address;
  final String? macAddress;
  final String? deviceIdentifier;
  final String? deviceId;
  final String? deviceType;
  final int? rssi;
  final int? batteryPower;
  final String? batteryStatus;
  final String? firmwareVersion;
  final DateTime? lastSeenAt;
  final DateTime? lastConnectedAt;

  String get displayName => _cleanText(name) ?? 'PRANA ring';

  String get displayAddress =>
      _cleanText(address) ??
      _cleanText(macAddress) ??
      _cleanText(deviceIdentifier) ??
      _cleanText(deviceId) ??
      'Unknown address';

  factory SavedPranaRing.fromDevice(
    dynamic device, {
    DeviceBasicSnapshot? basicInfo,
    RingVitals? vitals,
    SavedPranaRing? previous,
  }) {
    final now = DateTime.now();
    final address = _knownDeviceAddress(device);
    final macAddress = _cleanText(
      readAny(device, const ['mac', 'macAddress', 'address']),
    );
    final deviceIdentifier = _cleanText(
      readAny(device, const ['deviceIdentifier', 'id']),
    );
    final deviceId = _cleanText(
      basicInfo?.deviceId == '-' ? null : basicInfo?.deviceId,
    );
    final rssi = deviceRssi(device);
    final batteryStatus = deviceBatteryStatus(device, basicInfo);
    final firmware = deviceFirmware(device, basicInfo);

    return SavedPranaRing(
      name:
          _cleanText(readAny(device, const ['name', 'deviceName'])) ??
          previous?.name,
      address: address ?? previous?.address,
      macAddress: macAddress ?? previous?.macAddress,
      deviceIdentifier: deviceIdentifier ?? previous?.deviceIdentifier,
      deviceId: deviceId ?? previous?.deviceId,
      deviceType: _cleanText(basicInfo?.deviceType) ?? previous?.deviceType,
      rssi: rssi == -999 ? previous?.rssi : rssi,
      batteryPower:
          deviceBatteryLevel(device, basicInfo, vitals) ??
          previous?.batteryPower,
      batteryStatus: batteryStatus == '-'
          ? previous?.batteryStatus
          : batteryStatus,
      firmwareVersion: firmware == '-' ? previous?.firmwareVersion : firmware,
      lastSeenAt: now,
      lastConnectedAt: now,
    );
  }

  factory SavedPranaRing.fromJson(Map<String, dynamic> json) {
    return SavedPranaRing(
      name: _cleanText(json['name']),
      address: _cleanText(json['address']),
      macAddress: _cleanText(json['macAddress']),
      deviceIdentifier: _cleanText(json['deviceIdentifier']),
      deviceId: _cleanText(json['deviceId']),
      deviceType: _cleanText(json['deviceType']),
      rssi: _jsonInt(json['rssi']),
      batteryPower: _jsonInt(json['batteryPower']),
      batteryStatus: _cleanText(json['batteryStatus']),
      firmwareVersion: _cleanText(json['firmwareVersion']),
      lastSeenAt: _dateFromJson(json['lastSeenAt']),
      lastConnectedAt: _dateFromJson(json['lastConnectedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'macAddress': macAddress,
      'deviceIdentifier': deviceIdentifier,
      'deviceId': deviceId,
      'deviceType': deviceType,
      'rssi': rssi,
      'batteryPower': batteryPower,
      'batteryStatus': batteryStatus,
      'firmwareVersion': firmwareVersion,
      'lastSeenAt': lastSeenAt?.toIso8601String(),
      'lastConnectedAt': lastConnectedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toDeviceMap() {
    return {
      if (name != null) 'name': name,
      if (macAddress != null) 'macAddress': macAddress,
      if (address != null) 'address': address,
      if (deviceIdentifier != null) 'deviceIdentifier': deviceIdentifier,
      if (deviceId != null) 'deviceId': deviceId,
      if (rssi != null) 'rssiValue': rssi,
      if (batteryPower != null) 'batteryPower': batteryPower,
      if (batteryStatus != null) 'batteryStatus': batteryStatus,
      if (firmwareVersion != null) 'firmwareVersion': firmwareVersion,
    };
  }

  bool matches(dynamic device) {
    final saved = _identitySet([
      address,
      macAddress,
      deviceIdentifier,
      deviceId,
    ]);
    if (saved.isEmpty) return false;

    final candidate = _identitySet([
      _knownDeviceAddress(device),
      readAny(device, const ['mac', 'macAddress', 'address']),
      readAny(device, const ['deviceIdentifier', 'id', 'deviceId']),
    ]);
    return candidate.any(saved.contains);
  }

  dynamic matchingDevice(List<dynamic> devices) {
    for (final device in devices) {
      if (matches(device)) return device;
    }
    return null;
  }
}

class PranaRingStore {
  static const _key = 'vyana.paired_prana_ring';

  static Future<SavedPranaRing?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_key);
    if (encoded == null || encoded.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return null;
      return SavedPranaRing.fromJson(Map<String, dynamic>.from(decoded));
    } on Object {
      return null;
    }
  }

  static Future<void> save(SavedPranaRing ring) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(ring.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

String? _knownDeviceAddress(dynamic device) {
  final address = _cleanText(_deviceIdentity(device));
  return address == 'Unknown address' ? null : address;
}

Set<String> _identitySet(Iterable<dynamic> values) {
  return values
      .map(_cleanText)
      .whereType<String>()
      .map((value) => value.toLowerCase())
      .toSet();
}

String? _cleanText(dynamic value) {
  final text = value?.toString().trim();
  if (text == null ||
      text.isEmpty ||
      text == '-' ||
      text == '0' ||
      text == 'Unknown address') {
    return null;
  }
  return text;
}

int? _jsonInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

DateTime? _dateFromJson(dynamic value) {
  final text = value?.toString();
  return text == null || text.isEmpty ? null : DateTime.tryParse(text);
}

class DeviceFeatureSnapshot {
  const DeviceFeatureSnapshot(this.items, this.flags);

  final List<FeatureItem> items;
  final Map<String, bool> flags;

  factory DeviceFeatureSnapshot.fromDynamic(dynamic source) {
    const candidates = [
      ['Heart rate', 'isSupportHeartRate'],
      ['Start heart rate', 'isSupportStartHeartRateMeasurement'],
      ['Blood oxygen', 'isSupportBloodOxygen'],
      ['Start blood oxygen', 'isSupportStartBloodOxygenMeasurement'],
      ['Blood pressure', 'isSupportBloodPressure'],
      ['Start blood pressure', 'isSupportStartBloodPressureMeasurement'],
      ['Sleep', 'isSupportSleep'],
      ['Step', 'isSupportStep'],
      ['Temperature', 'isSupportTemperature'],
      ['Start temperature', 'isSupportStartBodyTemperatureMeasurement'],
      ['Respiration rate', 'isSupportRespirationRate'],
      ['Start respiration rate', 'isSupportStartRespirationRateMeasurement'],
      ['HRV', 'isSupportHRV'],
      ['Start HRV', 'isSupportStartHRVMeasurement'],
      ['Pressure', 'isSupportPressure'],
      ['Start pressure', 'isSupportStartPressureMeasurement'],
      ['Blood glucose', 'isSupportBloodGlucose'],
      ['Start blood glucose', 'isSupportStartBloodGlucoseMeasurement'],
      ['Uric acid', 'isSupportUricAcid'],
      ['Blood ketone', 'isSupportBloodKetone'],
      ['Blood fat', 'isSupportBloodFat'],
      ['Sport history', 'isSupportSport'],
      ['Real-time upload', 'isSupportRealTimeDataUpload'],
      ['OTA', 'isSupportOta'],
      ['Find device', 'isSupportFindDevice'],
      ['Anti-lost', 'isSupportAntiLostReminder'],
      ['Health alarms', 'isSupportHeartRateAlarm'],
      ['VO2 max', 'isSupportVo2max'],
      ['Real-time ECG', 'isSupportRealTimeECG'],
      ['Historical ECG', 'isSupportHistoricalECG'],
      ['ECG diagnosis', 'isSupportECGDiagnosis'],
      ['Factory reset', 'isSupportFactorySettings'],
    ];
    final flags = <String, bool>{
      for (final item in candidates)
        item[1]: readBool(source, [item[1]]) ?? false,
    };

    return DeviceFeatureSnapshot(
      candidates
          .map((item) => FeatureItem(item[0], item[1], flags[item[1]] ?? false))
          .toList(),
      flags,
    );
  }

  Iterable<FeatureItem> get supported => items.where((item) => item.supported);

  bool supports(String key) => flags[key] ?? false;

  bool supportsAny(Iterable<String> keys) => keys.any(supports);

  String toLogString() {
    final supportedKeys = flags.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .join(',');
    final unsupportedKeys = flags.entries
        .where((entry) => !entry.value)
        .map((entry) => entry.key)
        .join(',');
    return 'supported=[$supportedKeys] unsupported=[$unsupportedKeys]';
  }
}

class FeatureItem {
  const FeatureItem(this.label, this.key, this.supported);

  final String label;
  final String key;
  final bool supported;
}

class RingHistory {
  const RingHistory({
    required this.steps,
    required this.sleep,
    required this.heartRate,
    required this.bloodPressure,
    required this.combined,
    required this.invasive,
    required this.sport,
  });

  final List<dynamic> steps;
  final List<dynamic> sleep;
  final List<dynamic> heartRate;
  final List<dynamic> bloodPressure;
  final List<dynamic> combined;
  final List<dynamic> invasive;
  final List<dynamic> sport;

  factory RingHistory.empty() => const RingHistory(
    steps: [],
    sleep: [],
    heartRate: [],
    bloodPressure: [],
    combined: [],
    invasive: [],
    sport: [],
  );

  int get totalRecords =>
      steps.length +
      sleep.length +
      heartRate.length +
      bloodPressure.length +
      combined.length +
      invasive.length +
      sport.length;

  Map<String, int> get counts => {
    'steps': steps.length,
    'sleep': sleep.length,
    'heartRate': heartRate.length,
    'bloodPressure': bloodPressure.length,
    'combined': combined.length,
    'invasive': invasive.length,
    'sport': sport.length,
  };
}

/// One calendar day of ring step intervals rolled up for charts and streaks.
class StepDaySummary {
  const StepDaySummary({
    required this.day,
    required this.steps,
    required this.distanceMeters,
    required this.calories,
    required this.intervalCount,
  });

  final DateTime day;
  final int steps;
  final int distanceMeters;
  final int calories;
  final int intervalCount;
}

const kStepStreakGoal = 5000;

DateTime localDayFromEpochSeconds(int seconds) {
  final local = DateTime.fromMillisecondsSinceEpoch(seconds * 1000).toLocal();
  return DateTime(local.year, local.month, local.day);
}

List<StepDaySummary> stepDaySummaries(List<dynamic> stepRecords) {
  final grouped = <DateTime, List<int>>{};
  final distances = <DateTime, int>{};
  final calories = <DateTime, int>{};
  final intervals = <DateTime, int>{};

  for (final record in stepRecords) {
    final ts = timestampOf(record);
    if (ts == null) continue;
    final day = localDayFromEpochSeconds(ts);
    grouped.putIfAbsent(day, () => []).add(readInt(record, const ['step', 'steps']) ?? 0);
    distances[day] = (distances[day] ?? 0) + (readInt(record, const ['distance']) ?? 0);
    calories[day] = (calories[day] ?? 0) + (readInt(record, const ['calories']) ?? 0);
    intervals[day] = (intervals[day] ?? 0) + 1;
  }

  return grouped.entries
      .map(
        (entry) => StepDaySummary(
          day: entry.key,
          steps: entry.value.fold<int>(0, (sum, value) => sum + value),
          distanceMeters: distances[entry.key] ?? 0,
          calories: calories[entry.key] ?? 0,
          intervalCount: intervals[entry.key] ?? entry.value.length,
        ),
      )
      .toList()
    ..sort((a, b) => b.day.compareTo(a.day));
}

StepDaySummary? stepDayForDate(List<dynamic> stepRecords, DateTime day) {
  final target = DateTime(day.year, day.month, day.day);
  for (final summary in stepDaySummaries(stepRecords)) {
    if (summary.day == target) return summary;
  }
  return null;
}

int computeStepStreak(List<StepDaySummary> days, {int goal = kStepStreakGoal}) {
  if (days.isEmpty) return 0;
  final byDay = {for (final day in days) day.day: day};
  var streak = 0;
  var cursor = DateTime.now();
  final today = DateTime(cursor.year, cursor.month, cursor.day);
  cursor = today;

  // Allow streak to start yesterday if today is still early / below goal.
  final todaySummary = byDay[today];
  if (todaySummary == null || todaySummary.steps < goal) {
    cursor = today.subtract(const Duration(days: 1));
  }

  while (true) {
    final summary = byDay[cursor];
    if (summary == null || summary.steps < goal) break;
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

class VitalHistoryPoint {
  const VitalHistoryPoint({
    required this.time,
    required this.value,
    required this.label,
  });

  final DateTime time;
  final double value;
  final String label;
}

/// Metric keys used by the home grid and detail screens.
enum VitalsMetricKind {
  steps,
  heartRate,
  hrv,
  spo2,
  sleep,
  calories,
  distance,
  bloodPressure,
  temperature,
  glucose,
  uricAcid,
  cholesterol,
  stress,
}

List<VitalHistoryPoint> vitalHistoryPoints(
  RingHistory history,
  VitalsMetricKind kind,
) {
  switch (kind) {
    case VitalsMetricKind.steps:
      return stepDaySummaries(history.steps)
          .reversed
          .map(
            (day) => VitalHistoryPoint(
              time: day.day,
              value: day.steps.toDouble(),
              label: '${day.steps} steps',
            ),
          )
          .toList();
    case VitalsMetricKind.heartRate:
      return _pointsFromHistoryRecords(history.heartRate, const ['heartRate'], 'bpm');
    case VitalsMetricKind.hrv:
      return _pointsFromHistoryRecords(history.combined, const ['hrv'], 'ms');
    case VitalsMetricKind.spo2:
      return _pointsFromHistoryRecords(history.combined, const ['bloodOxygen'], '%');
    case VitalsMetricKind.calories:
      return stepDaySummaries(history.steps)
          .reversed
          .map(
            (day) => VitalHistoryPoint(
              time: day.day,
              value: day.calories.toDouble(),
              label: '${day.calories} cal',
            ),
          )
          .toList();
    case VitalsMetricKind.distance:
      return stepDaySummaries(history.steps)
          .reversed
          .map(
            (day) => VitalHistoryPoint(
              time: day.day,
              value: day.distanceMeters.toDouble(),
              label: formatDistanceMeters(day.distanceMeters),
            ),
          )
          .toList();
    case VitalsMetricKind.bloodPressure:
      return history.bloodPressure
          .map((record) {
            final ts = timestampOf(record);
            final text = pressureText(record);
            if (ts == null || text == null) return null;
            final systolic = int.tryParse(text.split('/').first);
            if (systolic == null) return null;
            return VitalHistoryPoint(
              time: DateTime.fromMillisecondsSinceEpoch(ts * 1000),
              value: systolic.toDouble(),
              label: '$text mmHg',
            );
          })
          .whereType<VitalHistoryPoint>()
          .toList();
    case VitalsMetricKind.temperature:
      return _pointsFromHistoryRecords(
        history.combined,
        const ['temperature'],
        'C',
        filter: validTemperature,
      );
    case VitalsMetricKind.glucose:
      return [
        ..._pointsFromHistoryRecords(history.combined, const ['bloodGlucose'], 'mmol/L'),
        ..._pointsFromHistoryRecords(history.invasive, const ['bloodGlucose'], 'mmol/L'),
      ]..sort((a, b) => a.time.compareTo(b.time));
    case VitalsMetricKind.uricAcid:
      return _pointsFromHistoryRecords(history.invasive, const ['uricAcid'], 'µmol/L');
    case VitalsMetricKind.cholesterol:
      return _pointsFromHistoryRecords(
        history.invasive,
        const ['totalCholesterol'],
        'mmol/L',
      );
    case VitalsMetricKind.stress:
      return _pointsFromHistoryRecords(history.combined, const ['pressure'], '');
    case VitalsMetricKind.sleep:
      return sleepDaySummaries(history.sleep)
          .reversed
          .map(
            (day) => VitalHistoryPoint(
              time: day.day,
              value: day.score.toDouble(),
              label: '${day.score} score',
            ),
          )
          .toList();
  }
}

List<VitalHistoryPoint> _pointsFromHistoryRecords(
  List<dynamic> records,
  List<String> valueFields,
  String unit, {
  double? Function(double?)? filter,
}) {
  final points = <VitalHistoryPoint>[];
  for (final record in records) {
    final timestamp = timestampOf(record);
    final rawValue = readDouble(record, valueFields);
    final value = filter == null ? rawValue : filter(rawValue);
    if (timestamp == null || timestamp <= 0 || value == null || value == 0) {
      continue;
    }
    points.add(
      VitalHistoryPoint(
        time: DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
        value: value,
        label: unit.isEmpty ? '$value' : '$value $unit',
      ),
    );
  }
  points.sort((a, b) => a.time.compareTo(b.time));
  return points;
}

String formatDistanceMeters(int meters) {
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
  return '$meters m';
}

/// User-facing outcome of a manual ring sync (vitals + history pull).
class RingSyncFeedback {
  const RingSyncFeedback({
    required this.success,
    required this.recordCount,
    this.logSaved = true,
    this.errorMessage,
  });

  final bool success;
  final int recordCount;
  final bool logSaved;
  final String? errorMessage;

  String get snackMessage {
    if (!success) {
      return errorMessage ?? 'Could not sync vitals and data. Try again.';
    }
    if (!logSaved) {
      return 'Synced $recordCount records from your ring. Saving to the data log failed.';
    }
    if (recordCount == 0) {
      return 'Ring synced — no new history records yet.';
    }
    return 'Synced $recordCount records from your ring.';
  }
}

class SleepStageBreakdown {
  const SleepStageBreakdown({
    required this.deepSeconds,
    required this.lightSeconds,
    required this.remSeconds,
    required this.awakeSeconds,
    required this.segmentCount,
  });

  final int deepSeconds;
  final int lightSeconds;
  final int remSeconds;
  final int awakeSeconds;
  final int segmentCount;

  int get asleepSeconds => deepSeconds + lightSeconds + remSeconds;

  int get totalSeconds => asleepSeconds + awakeSeconds;

  bool get hasAnyStage => totalSeconds > 0;

  Map<String, dynamic> toCloudJson() => {
    'deepSeconds': deepSeconds,
    'lightSeconds': lightSeconds,
    'remSeconds': remSeconds,
    'awakeSeconds': awakeSeconds,
    'asleepSeconds': asleepSeconds,
    'totalSeconds': totalSeconds,
    'segmentCount': segmentCount,
  };

  SleepStageBreakdown merge(SleepStageBreakdown other) {
    return SleepStageBreakdown(
      deepSeconds: deepSeconds + other.deepSeconds,
      lightSeconds: lightSeconds + other.lightSeconds,
      remSeconds: remSeconds + other.remSeconds,
      awakeSeconds: awakeSeconds + other.awakeSeconds,
      segmentCount: segmentCount + other.segmentCount,
    );
  }
}

class SleepStageSegment {
  const SleepStageSegment({
    required this.startTimeStamp,
    required this.durationSeconds,
    required this.sleepType,
  });

  final int startTimeStamp;
  final int durationSeconds;
  final int sleepType;

  String get label => sleepStageLabel(sleepType);

  Map<String, dynamic> toCloudJson() => {
    'startTimeStamp': startTimeStamp,
    'startTime': epochSecondsToIso(startTimeStamp),
    'durationSeconds': durationSeconds,
    'sleepType': sleepType,
    'stage': label,
  };
}

class SleepSessionSummary {
  const SleepSessionSummary({
    required this.source,
    required this.startTimeStamp,
    required this.endTimeStamp,
    required this.isNewSleepProtocol,
    required this.breakdown,
    required this.segments,
  });

  final dynamic source;
  final int? startTimeStamp;
  final int? endTimeStamp;
  final bool isNewSleepProtocol;
  final SleepStageBreakdown breakdown;
  final List<SleepStageSegment> segments;

  factory SleepSessionSummary.fromDynamic(dynamic source) {
    final segments = sleepStageSegments(source);
    final fromSegments = _breakdownFromSegments(segments);
    final deep = readInt(source, const ['deepSleepSeconds']) ?? 0;
    final light = readInt(source, const ['lightSleepSeconds']) ?? 0;
    final rem = readInt(source, const ['remSleepSeconds']) ?? 0;

    return SleepSessionSummary(
      source: source,
      startTimeStamp: readInt(source, const ['startTimeStamp', 'timestamp']),
      endTimeStamp: readInt(source, const ['endTimeStamp']),
      isNewSleepProtocol:
          readBool(source, const ['isNewSleepProtocol']) ?? false,
      breakdown: SleepStageBreakdown(
        deepSeconds: deep == 0 ? fromSegments.deepSeconds : deep,
        lightSeconds: light == 0 ? fromSegments.lightSeconds : light,
        remSeconds: rem == 0 ? fromSegments.remSeconds : rem,
        awakeSeconds: fromSegments.awakeSeconds,
        segmentCount: segments.length,
      ),
      segments: segments,
    );
  }

  String get rangeLabel {
    final start = startTimeStamp == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(startTimeStamp! * 1000);
    final end = endTimeStamp == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(endTimeStamp! * 1000);
    if (start == null && end == null) return 'No time range';
    if (end == null) return 'Started ${timeLabel(start!)}';
    if (start == null) return 'Ended ${timeLabel(end)}';
    return '${timeLabel(start)} - ${timeLabel(end)}';
  }
}

class SleepDaySummary {
  const SleepDaySummary({
    required this.day,
    required this.windowStart,
    required this.windowEnd,
    required this.sections,
    required this.sessions,
    required this.breakdown,
    required this.waveform,
  });

  final DateTime day;
  final DateTime windowStart;
  final DateTime windowEnd;
  final List<SleepContinuousSection> sections;
  final List<SleepSessionSummary> sessions;
  final SleepStageBreakdown breakdown;
  final List<SleepWaveSegment> waveform;

  int get score => sleepScoreForBreakdown(breakdown);

  String get label {
    final month = day.month.toString().padLeft(2, '0');
    final date = day.day.toString().padLeft(2, '0');
    return '$month/$date sleep';
  }

  String get windowLabel {
    return '${timeOfDayLabel(windowStart)} - ${timeOfDayLabel(windowEnd)}';
  }
}

class SleepContinuousSection {
  const SleepContinuousSection({
    required this.day,
    required this.windowStart,
    required this.windowEnd,
    required this.sessions,
    required this.breakdown,
    required this.waveform,
  });

  final DateTime day;
  final DateTime windowStart;
  final DateTime windowEnd;
  final List<SleepSessionSummary> sessions;
  final SleepStageBreakdown breakdown;
  final List<SleepWaveSegment> waveform;

  String get windowLabel {
    return '${timeOfDayLabel(windowStart)} - ${timeOfDayLabel(windowEnd)}';
  }
}

class SleepWaveSegment {
  const SleepWaveSegment({
    required this.startTimeStamp,
    required this.endTimeStamp,
    required this.sleepType,
    required this.approximate,
  });

  final int startTimeStamp;
  final int endTimeStamp;
  final int sleepType;
  final bool approximate;

  int get durationSeconds => endTimeStamp - startTimeStamp;
}

class SleepVitalPoint {
  const SleepVitalPoint({required this.time, required this.value});

  final DateTime time;
  final double value;
}

class SleepVitalSeries {
  const SleepVitalSeries({
    required this.label,
    required this.unit,
    required this.points,
  });

  final String label;
  final String unit;
  final List<SleepVitalPoint> points;

  bool get hasPoints => points.isNotEmpty;

  double? get average {
    if (points.isEmpty) return null;
    final total = points.fold<double>(0, (sum, point) => sum + point.value);
    return total / points.length;
  }

  String averageText([int decimals = 0]) {
    final value = average;
    if (value == null) return '-';
    return decimals == 0
        ? value.round().toString()
        : value.toStringAsFixed(decimals);
  }
}

class SleepVitalsSummary {
  const SleepVitalsSummary({required this.series});

  final List<SleepVitalSeries> series;

  List<SleepVitalSeries> get available =>
      series.where((item) => item.hasPoints).toList();

  bool get hasAny => available.isNotEmpty;
}

class _SleepSessionBounds {
  const _SleepSessionBounds({
    required this.session,
    required this.start,
    required this.end,
  });

  final SleepSessionSummary session;
  final int start;
  final int end;
}

const _sleepSectionMergeGapSeconds = 90 * 60;

SleepStageBreakdown _breakdownFromSegments(List<SleepStageSegment> segments) {
  var deep = 0;
  var light = 0;
  var rem = 0;
  var awake = 0;
  for (final segment in segments) {
    switch (segment.sleepType) {
      case SleepType.deepSleep:
        deep += segment.durationSeconds;
        break;
      case SleepType.lightSleep:
        light += segment.durationSeconds;
        break;
      case SleepType.rem:
        rem += segment.durationSeconds;
        break;
      case SleepType.awake:
        awake += segment.durationSeconds;
        break;
    }
  }
  return SleepStageBreakdown(
    deepSeconds: deep,
    lightSeconds: light,
    remSeconds: rem,
    awakeSeconds: awake,
    segmentCount: segments.length,
  );
}

List<SleepDaySummary> sleepDaySummaries(List<dynamic> sleepRecords) {
  final grouped = <DateTime, List<SleepContinuousSection>>{};
  for (final section in sleepContinuousSections(sleepRecords)) {
    grouped.putIfAbsent(section.day, () => []).add(section);
  }

  final days = grouped.entries.map((entry) {
    final sections = entry.value
      ..sort((a, b) => a.windowStart.compareTo(b.windowStart));
    final sessions = sections.expand((section) => section.sessions).toList()
      ..sort(
        (a, b) => (a.startTimeStamp ?? 0).compareTo(b.startTimeStamp ?? 0),
      );
    final breakdown = sections.fold(
      _emptySleepStageBreakdown,
      (sum, section) => sum.merge(section.breakdown),
    );
    final waveform = sections.expand((section) => section.waveform).toList()
      ..sort((a, b) => a.startTimeStamp.compareTo(b.startTimeStamp));
    final starts = sections.map((section) => section.windowStart).toList();
    final ends = sections.map((section) => section.windowEnd).toList();
    final windowStart = starts.reduce((a, b) => a.isBefore(b) ? a : b);
    final windowEnd = ends.reduce((a, b) => a.isAfter(b) ? a : b);

    return SleepDaySummary(
      day: entry.key,
      windowStart: windowStart,
      windowEnd: windowEnd,
      sections: List.unmodifiable(sections),
      sessions: List.unmodifiable(sessions),
      breakdown: breakdown,
      waveform: List.unmodifiable(waveform),
    );
  }).toList()..sort((a, b) => b.day.compareTo(a.day));

  return days;
}

List<SleepContinuousSection> sleepContinuousSections(
  List<dynamic> sleepRecords,
) {
  final sessions = <_SleepSessionBounds>[];
  for (final record in sleepRecords) {
    final session = SleepSessionSummary.fromDynamic(record);
    if (!session.breakdown.hasAnyStage) continue;
    final bounds = _boundsForSleepSession(session);
    if (bounds == null) continue;
    sessions.add(bounds);
  }

  sessions.sort((a, b) => a.start.compareTo(b.start));
  final clusters = <List<_SleepSessionBounds>>[];
  for (final session in sessions) {
    if (clusters.isEmpty) {
      clusters.add([session]);
      continue;
    }

    final current = clusters.last;
    final currentEnd = current
        .map((item) => item.end)
        .reduce((a, b) => a > b ? a : b);
    if (session.start - currentEnd <= _sleepSectionMergeGapSeconds) {
      current.add(session);
    } else {
      clusters.add([session]);
    }
  }

  return clusters.map(_sleepContinuousSectionFromCluster).toList();
}

SleepDaySummary? latestSleepDaySummary(List<dynamic> sleepRecords) {
  final days = sleepDaySummaries(sleepRecords);
  return days.isEmpty ? null : days.first;
}

String? sleepSummaryForLatestSleepDay(List<dynamic> sleepRecords) {
  final day = latestSleepDaySummary(sleepRecords);
  if (day == null || day.breakdown.asleepSeconds <= 0) return null;
  return durationText(day.breakdown.asleepSeconds);
}

DateTime sleepDayForSession(SleepSessionSummary session) {
  final bounds = _boundsForSleepSession(session);
  if (bounds == null) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  return sleepDayForSection(
    DateTime.fromMillisecondsSinceEpoch(bounds.start * 1000),
    DateTime.fromMillisecondsSinceEpoch(bounds.end * 1000),
  );
}

DateTime sleepDayForSection(DateTime start, DateTime end) {
  final crossesMidnight =
      start.year != end.year ||
      start.month != end.month ||
      start.day != end.day;
  final day = crossesMidnight || start.hour < 12 ? end : start;
  return DateTime(day.year, day.month, day.day);
}

int sleepScoreForBreakdown(SleepStageBreakdown breakdown) {
  if (breakdown.asleepSeconds <= 0) return 0;

  final asleep = breakdown.asleepSeconds.toDouble();
  final total = breakdown.totalSeconds <= 0
      ? asleep
      : breakdown.totalSeconds.toDouble();
  final durationScore = (asleep / (8 * 3600) * 45).clamp(0, 45).toDouble();
  final efficiency = (asleep / total).clamp(0, 1).toDouble();
  final efficiencyScore = ((efficiency - 0.72) / 0.25 * 20)
      .clamp(0, 20)
      .toDouble();
  final deepScore = _ratioScore(
    actual: breakdown.deepSeconds / asleep,
    target: 0.18,
    points: 15,
  );
  final remScore = _ratioScore(
    actual: breakdown.remSeconds / asleep,
    target: 0.22,
    points: 15,
  );
  final awakePenalty = (breakdown.awakeSeconds / 60 / 8).clamp(0, 8).toDouble();
  final score =
      durationScore + efficiencyScore + deepScore + remScore + 5 - awakePenalty;
  return score.round().clamp(0, 100);
}

SleepVitalsSummary sleepVitalsForDay(SleepDaySummary day, RingHistory history) {
  return sleepVitalsForDays([day], history);
}

SleepVitalsSummary sleepVitalsForDays(
  Iterable<SleepDaySummary> days,
  RingHistory history,
) {
  final dayList = days.toList();
  return SleepVitalsSummary(
    series: [
      _sleepVitalSeries(
        'Heart rate',
        'bpm',
        [history.heartRate, history.combined],
        const ['heartRate'],
        dayList,
      ),
      _sleepVitalSeries(
        'SpO2',
        '%',
        [history.combined],
        const ['bloodOxygen'],
        dayList,
      ),
      _sleepVitalSeries(
        'HRV',
        'ms',
        [history.combined],
        const ['hrv'],
        dayList,
      ),
      _sleepVitalSeries(
        'Temperature',
        'C',
        [history.combined],
        const ['temperature'],
        dayList,
        filter: validTemperature,
      ),
      _sleepVitalSeries(
        'Stress',
        '',
        [history.combined],
        const ['pressure'],
        dayList,
      ),
      _sleepVitalSeries(
        'Glucose',
        'mmol/L',
        [history.combined, history.invasive],
        const ['bloodGlucose'],
        dayList,
      ),
    ],
  );
}

const _emptySleepStageBreakdown = SleepStageBreakdown(
  deepSeconds: 0,
  lightSeconds: 0,
  remSeconds: 0,
  awakeSeconds: 0,
  segmentCount: 0,
);

double _ratioScore({
  required double actual,
  required double target,
  required double points,
}) {
  final miss = (actual - target).abs() / target;
  return (points * (1 - miss)).clamp(0, points).toDouble();
}

SleepVitalSeries _sleepVitalSeries(
  String label,
  String unit,
  Iterable<List<dynamic>> sources,
  List<String> valueFields,
  List<SleepDaySummary> days, {
  double? Function(double?)? filter,
}) {
  final points = <SleepVitalPoint>[];
  for (final records in sources) {
    for (final record in records) {
      final timestamp = timestampOf(record);
      final rawValue = readDouble(record, valueFields);
      final value = filter == null ? rawValue : filter(rawValue);
      if (timestamp == null ||
          timestamp <= 0 ||
          value == null ||
          value == 0 ||
          !_timestampFallsInSleepDays(timestamp, days)) {
        continue;
      }
      points.add(
        SleepVitalPoint(
          time: DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
          value: value,
        ),
      );
    }
  }
  points.sort((a, b) => a.time.compareTo(b.time));
  return SleepVitalSeries(
    label: label,
    unit: unit,
    points: List.unmodifiable(points),
  );
}

bool _timestampFallsInSleepDays(int timestamp, List<SleepDaySummary> days) {
  for (final day in days) {
    for (final section in day.sections) {
      final start = section.windowStart.millisecondsSinceEpoch ~/ 1000;
      final end = section.windowEnd.millisecondsSinceEpoch ~/ 1000;
      if (timestamp >= start && timestamp <= end) return true;
    }
    final start = day.windowStart.millisecondsSinceEpoch ~/ 1000;
    final end = day.windowEnd.millisecondsSinceEpoch ~/ 1000;
    if (day.sections.isEmpty && timestamp >= start && timestamp <= end) {
      return true;
    }
  }
  return false;
}

_SleepSessionBounds? _boundsForSleepSession(SleepSessionSummary session) {
  final starts = <int>[
    if (session.startTimeStamp != null && session.startTimeStamp! > 0)
      session.startTimeStamp!,
    for (final segment in session.segments)
      if (segment.startTimeStamp > 0) segment.startTimeStamp,
  ];
  final ends = <int>[
    if (session.endTimeStamp != null && session.endTimeStamp! > 0)
      session.endTimeStamp!,
    for (final segment in session.segments)
      if (segment.startTimeStamp > 0)
        segment.startTimeStamp + segment.durationSeconds,
  ];

  if (starts.isEmpty && ends.isEmpty) return null;
  var start = starts.isEmpty
      ? ends.reduce((a, b) => a < b ? a : b) - session.breakdown.totalSeconds
      : starts.reduce((a, b) => a < b ? a : b);
  var end = ends.isEmpty
      ? start + session.breakdown.totalSeconds
      : ends.reduce((a, b) => a > b ? a : b);

  if (start <= 0 && end > 0) start = end - session.breakdown.totalSeconds;
  if (end <= start) {
    end = start + session.breakdown.totalSeconds.clamp(1, 86400);
  }
  if (start <= 0 || end <= 0) return null;

  return _SleepSessionBounds(session: session, start: start, end: end);
}

SleepContinuousSection _sleepContinuousSectionFromCluster(
  List<_SleepSessionBounds> cluster,
) {
  final sessions = cluster.map((item) => item.session).toList()
    ..sort((a, b) => (a.startTimeStamp ?? 0).compareTo(b.startTimeStamp ?? 0));
  final breakdown = sessions.fold(
    _emptySleepStageBreakdown,
    (sum, session) => sum.merge(session.breakdown),
  );
  final waveform = _sleepWaveformSegments(sessions);
  final starts = <int>[
    for (final item in cluster) item.start,
    for (final segment in waveform) segment.startTimeStamp,
  ];
  final ends = <int>[
    for (final item in cluster) item.end,
    for (final segment in waveform) segment.endTimeStamp,
  ];
  final start = starts.reduce((a, b) => a < b ? a : b);
  var end = ends.reduce((a, b) => a > b ? a : b);
  if (end <= start) end = start + breakdown.totalSeconds.clamp(1, 86400);
  final windowStart = DateTime.fromMillisecondsSinceEpoch(start * 1000);
  final windowEnd = DateTime.fromMillisecondsSinceEpoch(end * 1000);
  final day = sleepDayForSection(windowStart, windowEnd);

  return SleepContinuousSection(
    day: day,
    windowStart: windowStart,
    windowEnd: windowEnd,
    sessions: List.unmodifiable(sessions),
    breakdown: breakdown,
    waveform: List.unmodifiable(waveform),
  );
}

List<SleepWaveSegment> _sleepWaveformSegments(
  List<SleepSessionSummary> sessions,
) {
  final segments = <SleepWaveSegment>[];
  for (final session in sessions) {
    if (session.segments.isNotEmpty) {
      segments.addAll(
        session.segments.map(
          (segment) => SleepWaveSegment(
            startTimeStamp: segment.startTimeStamp,
            endTimeStamp: segment.startTimeStamp + segment.durationSeconds,
            sleepType: segment.sleepType,
            approximate: false,
          ),
        ),
      );
    } else {
      segments.addAll(_estimatedWaveformSegments(session));
    }
  }
  segments.sort((a, b) => a.startTimeStamp.compareTo(b.startTimeStamp));
  return segments.where((segment) => segment.durationSeconds > 0).toList();
}

List<SleepWaveSegment> _estimatedWaveformSegments(SleepSessionSummary session) {
  final start = session.startTimeStamp;
  if (start == null || start <= 0) return const [];
  var cursor = start;

  final stages = [
    (SleepType.deepSleep, session.breakdown.deepSeconds),
    (SleepType.lightSleep, session.breakdown.lightSeconds),
    (SleepType.rem, session.breakdown.remSeconds),
    (SleepType.awake, session.breakdown.awakeSeconds),
  ];
  final segments = <SleepWaveSegment>[];
  for (final stage in stages) {
    if (stage.$2 <= 0) continue;
    final end = cursor + stage.$2;
    segments.add(
      SleepWaveSegment(
        startTimeStamp: cursor,
        endTimeStamp: end,
        sleepType: stage.$1,
        approximate: true,
      ),
    );
    cursor = end;
  }
  return segments;
}

class RingVitals {
  const RingVitals({
    this.battery,
    this.steps,
    this.distanceMeters,
    this.calories,
    this.heartRate,
    this.bloodOxygen,
    this.respirationRate,
    this.hrv,
    this.temperature,
    this.bloodPressure,
    this.pressure,
    this.sleepSummary,
    this.bloodGlucose,
    this.uricAcid,
    this.totalCholesterol,
    this.updatedAt,
  });

  final int? battery;
  final int? steps;
  final int? distanceMeters;
  final int? calories;
  final int? heartRate;
  final int? bloodOxygen;
  final int? respirationRate;
  final int? hrv;
  final double? temperature;
  final String? bloodPressure;
  final double? pressure;
  final String? sleepSummary;
  final double? bloodGlucose;
  final int? uricAcid;
  final double? totalCholesterol;
  final DateTime? updatedAt;

  factory RingVitals.empty() => const RingVitals();

  factory RingVitals.fromHistory(
    RingHistory history,
    DeviceBasicSnapshot? basic,
  ) {
    final latestStep = latestByTimestamp(history.steps);
    final latestHeart = latestByTimestamp(history.heartRate);
    final latestBp = latestByTimestamp(history.bloodPressure);
    final latestCombined = latestByTimestamp(history.combined);
    final latestInvasive = latestByTimestamp(history.invasive);
    final latestSleepDay = latestSleepDaySummary(history.sleep);
    final latestTime =
        [
          latestStep,
          latestHeart,
          latestBp,
          latestCombined,
          latestInvasive,
          latestSleepDay?.sessions.isEmpty == true
              ? null
              : latestSleepDay?.sessions.last.source,
        ].map(timestampOf).whereType<int>().fold<int?>(null, (max, value) {
          return max == null || value > max ? value : max;
        });

    return RingVitals(
      battery: basic?.batteryPower,
      steps: readInt(latestStep, const ['step', 'steps']),
      distanceMeters: readInt(latestStep, const ['distance']),
      calories: readInt(latestStep, const ['calories']),
      heartRate:
          readInt(latestHeart, const ['heartRate']) ??
          readInt(latestCombined, const ['heartRate']),
      bloodOxygen: readInt(latestCombined, const ['bloodOxygen']),
      respirationRate: readInt(latestCombined, const ['respirationRate']),
      hrv: readInt(latestCombined, const ['hrv']),
      temperature: validTemperature(
        readDouble(latestCombined, const ['temperature']),
      ),
      bloodPressure: pressureText(latestBp) ?? pressureText(latestCombined),
      pressure: readDouble(latestCombined, const ['pressure']),
      sleepSummary: latestSleepDay == null
          ? null
          : durationText(latestSleepDay.breakdown.asleepSeconds),
      bloodGlucose:
          readDouble(latestCombined, const ['bloodGlucose']) ??
          readDouble(latestInvasive, const ['bloodGlucose']),
      uricAcid: readInt(latestInvasive, const ['uricAcid']),
      totalCholesterol: readDouble(latestInvasive, const ['totalCholesterol']),
      updatedAt: latestTime == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(latestTime * 1000),
    );
  }

  RingVitals merge(RingVitals fallback) {
    return RingVitals(
      battery: battery ?? fallback.battery,
      steps: steps ?? fallback.steps,
      distanceMeters: distanceMeters ?? fallback.distanceMeters,
      calories: calories ?? fallback.calories,
      heartRate: heartRate ?? fallback.heartRate,
      bloodOxygen: bloodOxygen ?? fallback.bloodOxygen,
      respirationRate: respirationRate ?? fallback.respirationRate,
      hrv: hrv ?? fallback.hrv,
      temperature: temperature ?? fallback.temperature,
      bloodPressure: bloodPressure ?? fallback.bloodPressure,
      pressure: pressure ?? fallback.pressure,
      sleepSummary: sleepSummary ?? fallback.sleepSummary,
      bloodGlucose: bloodGlucose ?? fallback.bloodGlucose,
      uricAcid: uricAcid ?? fallback.uricAcid,
      totalCholesterol: totalCholesterol ?? fallback.totalCholesterol,
      updatedAt: updatedAt ?? fallback.updatedAt,
    );
  }

  RingVitals mergeLiveEvent(Map<dynamic, dynamic> event) {
    int? eventInt(String key, List<String> fields) {
      final payload = event[key];
      if (payload is num) return payload.toInt();
      if (payload is String) return int.tryParse(payload);
      return readInt(payload, fields);
    }

    double? eventDouble(String key, List<String> fields) {
      final payload = event[key];
      if (payload is num) return payload.toDouble();
      if (payload is String) return double.tryParse(payload);
      return readDouble(payload, fields);
    }

    return RingVitals(
      battery: battery,
      steps: eventInt('deviceRealStep', const ['step', 'steps']) ?? steps,
      distanceMeters: distanceMeters,
      calories: calories,
      // During an app-started sport the ring streams HR inside the sport frame
      // (deviceRealSport) rather than as a standalone deviceRealHeartRate.
      heartRate:
          eventInt('deviceRealHeartRate', const ['heartRate', 'value']) ??
          readInt(event['deviceRealSport'], const ['heartRate']) ??
          heartRate,
      bloodOxygen:
          eventInt('deviceRealBloodOxygen', const ['bloodOxygen', 'value']) ??
          bloodOxygen,
      respirationRate: respirationRate,
      hrv: eventInt('deviceRealECGAlgorithmHRV', const ['hrv', 'value']) ?? hrv,
      temperature:
          validTemperature(
            eventDouble('deviceRealTemperature', const [
              'temperature',
              'value',
            ]),
          ) ??
          temperature,
      bloodPressure:
          pressureText(event['deviceRealBloodPressure']) ?? bloodPressure,
      pressure:
          eventDouble('deviceRealPressure', const ['pressure', 'value']) ??
          pressure,
      sleepSummary: sleepSummary,
      bloodGlucose:
          eventDouble('deviceRealBloodGlucose', const [
            'bloodGlucose',
            'value',
          ]) ??
          bloodGlucose,
      uricAcid: uricAcid,
      totalCholesterol: totalCholesterol,
      updatedAt: event.isEmpty ? updatedAt : DateTime.now(),
    );
  }
}

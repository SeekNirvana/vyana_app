part of '../main.dart';

dynamic latestByTimestamp(List<dynamic> items) {
  if (items.isEmpty) return null;
  dynamic latest = items.first;
  for (final item in items.skip(1)) {
    final current = timestampOf(item) ?? 0;
    final previous = timestampOf(latest) ?? 0;
    if (current > previous) latest = item;
  }
  return latest;
}

int? timestampOf(dynamic source) {
  return readInt(source, const ['startTimeStamp', 'timestamp', 'time']);
}

String deviceLabel(dynamic device) {
  return readAny(device, const [
            'name',
            'deviceName',
            'localName',
          ])?.toString().trim().isNotEmpty ==
          true
      ? readAny(device, const ['name', 'deviceName', 'localName']).toString()
      : 'PRANA ring';
}

String deviceAddress(dynamic device) {
  return _deviceIdentity(device) ?? 'Unknown address';
}

String? normalizeRingName(String value) {
  var cleanName = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  cleanName = cleanName.replaceAll(RegExp(kRingNameDisallowedCharsPattern, unicode: true), '');
  if (cleanName.length > kRingNameMaxLength) {
    cleanName = cleanName.substring(0, kRingNameMaxLength);
  }
  return cleanName.isEmpty ? null : cleanName;
}

String? validateRingName(String value) {
  final cleanName = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (cleanName.isEmpty) return 'Ring name is required';
  if (cleanName.length > kRingNameMaxLength) {
    return 'Ring name must be $kRingNameMaxLength characters or fewer';
  }
  if (!RegExp(kRingNameAllowedPattern, unicode: true).hasMatch(cleanName)) {
    return 'Ring name can only contain letters, numbers, spaces, - and \'';
  }
  return null;
}

String? _deviceIdentity(dynamic device) {
  final value = readAny(device, const [
    'mac',
    'macAddress',
    'address',
    'deviceIdentifier',
    'id',
  ])?.toString().trim();
  return value == null || value.isEmpty || value == '0' ? null : value;
}

int deviceRssi(dynamic device) {
  return readInt(device, const ['rssiValue', 'rssi']) ?? -999;
}

int? deviceBatteryLevel(
  dynamic device,
  DeviceBasicSnapshot? basicInfo,
  RingVitals? vitals,
) {
  return readInt(device, const ['batteryPower', 'battery', 'power']) ??
      vitals?.battery ??
      basicInfo?.batteryPower;
}

String deviceBatteryStatus(dynamic device, DeviceBasicSnapshot? basicInfo) {
  final status = normalizedBatteryStatus(
    readAny(device, const ['batteryStatus', 'deviceBatteryState']),
  );
  return status == '-' ? basicInfo?.batteryStatus ?? '-' : status;
}

String deviceFirmware(dynamic device, DeviceBasicSnapshot? basicInfo) {
  final firmware = readAny(device, const [
    'firmwareVersion',
  ])?.toString().trim();
  if (firmware != null &&
      firmware.isNotEmpty &&
      firmware != '-' &&
      firmware != '0') {
    return firmware;
  }

  final basicFirmware = basicInfo?.firmwareVersion.trim();
  if (basicFirmware != null && basicFirmware.isNotEmpty) {
    return basicFirmware;
  }
  return '-';
}

bool sameDevice(dynamic first, dynamic second) {
  if (identical(first, second)) return true;
  if (first == null || second == null) return false;

  final firstAddress = deviceAddress(first);
  final secondAddress = deviceAddress(second);
  return firstAddress != 'Unknown address' && firstAddress == secondAddress;
}

bool deviceLooksSystemConnected(dynamic device) {
  return deviceRssi(device) == 0 && deviceAddress(device) != 'Unknown address';
}

String _compactEvent(Map<dynamic, dynamic> event) {
  return event.entries
      .map((entry) => '${entry.key}: ${entry.value}')
      .join(' | ')
      .replaceAll(RegExp(r'\s+'), ' ');
}

bool containsLiveMeasurementValue(Map<dynamic, dynamic> event) {
  const keys = [
    NativeEventType.deviceRealHeartRate,
    NativeEventType.deviceRealBloodPressure,
    NativeEventType.deviceRealBloodOxygen,
    NativeEventType.deviceRealTemperature,
    NativeEventType.deviceRealPressure,
    NativeEventType.deviceRealBloodGlucose,
    NativeEventType.deviceRealHRV,
  ];
  return keys.any((key) {
    final value = event[key];
    return value != null && value.toString() != '0' && value.toString() != '';
  });
}

List<double> ecgSamplesFromPayload(dynamic payload) {
  if (payload == null) return const [];
  final samples = <double>[];
  _collectEcgSamples(payload, samples);
  return samples;
}

void _collectEcgSamples(dynamic payload, List<double> samples) {
  if (payload == null) return;
  if (payload is num) {
    samples.add(payload.toDouble());
    return;
  }
  if (payload is String) {
    final trimmed = payload.trim();
    if (trimmed.isEmpty) return;
    if (trimmed.startsWith('[')) {
      try {
        _collectEcgSamples(jsonDecode(trimmed), samples);
        return;
      } on FormatException {
        // Fall through to number extraction below.
      }
    }
    final direct = double.tryParse(trimmed);
    if (direct != null) {
      samples.add(direct);
      return;
    }
    final matches = RegExp(
      r'-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?',
    ).allMatches(trimmed);
    for (final match in matches) {
      final value = double.tryParse(match.group(0) ?? '');
      if (value != null) samples.add(value);
    }
    return;
  }
  if (payload is Iterable) {
    for (final item in payload) {
      _collectEcgSamples(item, samples);
    }
    return;
  }
  if (payload is Map) {
    final nested = readList(payload, const [
      'data',
      'datas',
      'ecgData',
      'filteredData',
      'list',
      'samples',
      'values',
    ]);
    if (nested.isNotEmpty) {
      _collectEcgSamples(nested, samples);
      return;
    }
    final value = readDouble(payload, const ['value']);
    if (value != null) samples.add(value);
  }
}

int? eventPayloadInt(dynamic payload, List<String> fields) {
  if (payload is num) return payload.toInt();
  if (payload is String) {
    return int.tryParse(payload) ?? double.tryParse(payload)?.toInt();
  }
  return readInt(payload, fields);
}

bool? ecgContactAttached(dynamic payload) {
  final status = eventPayloadInt(payload, const [
    'EcgStatus',
    'ecgStatus',
    'status',
    'value',
  ]);
  if (status == null) return null;
  if (status == 0) return true;
  if (status == 1) return false;
  return null;
}

String? pressureText(dynamic source) {
  final systolic = readInt(source, const [
    'systolicBloodPressure',
    'systolic',
    'sbp',
  ]);
  final diastolic = readInt(source, const [
    'diastolicBloodPressure',
    'diastolic',
    'dbp',
  ]);
  if (systolic == null ||
      diastolic == null ||
      systolic == 0 ||
      diastolic == 0) {
    return null;
  }
  return '$systolic/$diastolic';
}

String? sleepText(dynamic source) {
  final deep = readInt(source, const ['deepSleepSeconds']) ?? 0;
  final light = readInt(source, const ['lightSleepSeconds']) ?? 0;
  final rem = readInt(source, const ['remSleepSeconds']) ?? 0;
  final total = deep + light + rem;
  if (total <= 0) return null;
  return durationText(total);
}

List<SleepStageSegment> sleepStageSegments(dynamic source) {
  return readList(source, const ['detail', 'list'])
      .map((detail) {
        final start = readInt(detail, const ['startTimeStamp']) ?? 0;
        final duration = readInt(detail, const ['duration']) ?? 0;
        final sleepType = readInt(detail, const ['sleepType']) ?? 0;
        return SleepStageSegment(
          startTimeStamp: start,
          durationSeconds: duration,
          sleepType: sleepType,
        );
      })
      .where((segment) => segment.durationSeconds > 0)
      .toList();
}

String sleepStageLabel(int type) {
  switch (type) {
    case SleepType.deepSleep:
      return 'Deep';
    case SleepType.lightSleep:
      return 'Light';
    case SleepType.rem:
      return 'REM';
    case SleepType.awake:
      return 'Awake';
    default:
      return 'Unknown';
  }
}

Color sleepStageColor(int type) {
  switch (type) {
    case SleepType.deepSleep:
      return const Color(0xFF283593);
    case SleepType.lightSleep:
      return const Color(0xFF26A69A);
    case SleepType.rem:
      return const Color(0xFF7E57C2);
    case SleepType.awake:
      return const Color(0xFFFFB74D);
    default:
      return const Color(0xFF90A4AE);
  }
}

int sleepStageLane(int type) {
  switch (type) {
    case SleepType.awake:
      return 0;
    case SleepType.rem:
      return 1;
    case SleepType.lightSleep:
      return 2;
    case SleepType.deepSleep:
      return 3;
    default:
      return 2;
  }
}

String durationText(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours == 0) return '${minutes}m';
  return '${hours}h ${minutes}m';
}

double? validTemperature(double? value) {
  if (value == null || value == 0) return null;
  final fraction = ((value - value.truncate()).abs() * 100).round();
  if (fraction == 15) return null;
  return value;
}

dynamic readAny(dynamic source, List<String> names) {
  if (source == null) return null;
  if (source is Map) {
    for (final name in names) {
      if (source.containsKey(name)) return source[name];
    }
  }

  for (final name in names) {
    try {
      final mirror = _dynamicRead(source, name);
      if (mirror != null) return mirror;
    } on Object {
      continue;
    }
  }
  return null;
}

List<dynamic> readList(dynamic source, List<String> names) {
  final value = readAny(source, names);
  if (value is List) return value;
  if (value is Iterable) return List<dynamic>.from(value);
  return const [];
}

dynamic _dynamicRead(dynamic source, String name) {
  switch (name) {
    case 'address':
      return source.address;
    case 'battery':
      return source.battery;
    case 'batteryPower':
      return source.batteryPower;
    case 'batteryStatus':
      return source.batteryStatus;
    case 'afFlag':
      return source.afFlag;
    case 'afflag':
      return source.afflag;
    case 'bloodGlucose':
      return source.bloodGlucose;
    case 'bloodOxygen':
      return source.bloodOxygen;
    case 'body':
      return source.body;
    case 'calories':
      return source.calories;
    case 'bloodFatMode':
      return source.bloodFatMode;
    case 'bloodGlucoseMode':
      return source.bloodGlucoseMode;
    case 'bloodKetone':
      return source.bloodKetone;
    case 'bloodKetoneMode':
      return source.bloodKetoneMode;
    case 'deepSleepSeconds':
      return source.deepSleepSeconds;
    case 'deviceID':
      return source.deviceID;
    case 'deviceId':
      return source.deviceId;
    case 'deviceIdentifier':
      return source.deviceIdentifier;
    case 'deviceName':
      return source.deviceName;
    case 'deviceType':
      return source.deviceType;
    case 'diastolic':
      return source.diastolic;
    case 'diastolicBloodPressure':
      return source.diastolicBloodPressure;
    case 'distance':
      return source.distance;
    case 'duration':
      return source.duration;
    case 'endTimeStamp':
      return source.endTimeStamp;
    case 'fat':
      return source.fat;
    case 'firmwareMajorVersion':
      return source.firmwareMajorVersion;
    case 'firmwareSubVersion':
      return source.firmwareSubVersion;
    case 'firmwareVersion':
      return source.firmwareVersion;
    case 'flag':
      return source.flag;
    case 'heartRate':
      return source.heartRate;
    case 'hearRate':
      return source.hearRate;
    case 'heavyLoad':
      return source.heavyLoad;
    case 'hdlCholesterol':
      return source.hdlCholesterol;
    case 'hrv':
      return source.hrv;
    case 'hrvNorm':
      return source.hrvNorm;
    case 'id':
      return source.id;
    case 'isNewSleepProtocol':
      return source.isNewSleepProtocol;
    case 'ldlCholesterol':
      return source.ldlCholesterol;
    case 'lightSleepSeconds':
      return source.lightSleepSeconds;
    case 'list':
      return source.list;
    case 'localName':
      return source.localName;
    case 'mac':
      return source.mac;
    case 'macAddress':
      return source.macAddress;
    case 'maximumHeartRate':
      return source.maximumHeartRate;
    case 'minimumHeartRate':
      return source.minimumHeartRate;
    case 'mode':
      return source.mode;
    case 'name':
      return source.name;
    case 'power':
      return source.power;
    case 'pressure':
      return source.pressure;
    case 'qrsType':
      return source.qrsType;
    case 'remSleepSeconds':
      return source.remSleepSeconds;
    case 'respirationRate':
      return source.respirationRate;
    case 'rssi':
      return source.rssi;
    case 'rssiValue':
      return source.rssiValue;
    case 'sbp':
      return source.sbp;
    case 'sleepType':
      return source.sleepType;
    case 'sportTime':
      return source.sportTime;
    case 'sportType':
      return source.sportType;
    case 'step':
      return source.step;
    case 'steps':
      return source.steps;
    case 'sympatheticActivityIndex':
      return source.sympatheticActivityIndex;
    case 'startTimeStamp':
      return source.startTimeStamp;
    case 'statusCode':
      return source.statusCode;
    case 'systolic':
      return source.systolic;
    case 'systolicBloodPressure':
      return source.systolicBloodPressure;
    case 'temperature':
      return source.temperature;
    case 'time':
      return source.time;
    case 'timestamp':
      return source.timestamp;
    case 'totalCholesterol':
      return source.totalCholesterol;
    case 'triglycerides':
      return source.triglycerides;
    case 'uricAcidMode':
      return source.uricAcidMode;
    case 'uricAcid':
      return source.uricAcid;
    case 'value':
      return source.value;
    case 'cvrr':
      return source.cvrr;
    default:
      if (name.startsWith('isSupport')) {
        return _readFeatureFlag(source, name);
      }
      return null;
  }
}

dynamic _readFeatureFlag(dynamic source, String name) {
  switch (name) {
    case 'isSupportAntiLostReminder':
      return source.isSupportAntiLostReminder;
    case 'isSupportBloodOxygen':
      return source.isSupportBloodOxygen;
    case 'isSupportBloodOxygenAlarm':
      return source.isSupportBloodOxygenAlarm;
    case 'isSupportBloodPressure':
      return source.isSupportBloodPressure;
    case 'isSupportBloodFat':
      return source.isSupportBloodFat;
    case 'isSupportBloodGlucose':
      return source.isSupportBloodGlucose;
    case 'isSupportBloodKetone':
      return source.isSupportBloodKetone;
    case 'isSupportECGDiagnosis':
      return source.isSupportECGDiagnosis;
    case 'isSupportFindDevice':
      return source.isSupportFindDevice;
    case 'isSupportHeartRate':
      return source.isSupportHeartRate;
    case 'isSupportHeartRateAlarm':
      return source.isSupportHeartRateAlarm;
    case 'isSupportHRV':
      return source.isSupportHRV;
    case 'isSupportOta':
      return source.isSupportOta;
    case 'isSupportPressure':
      return source.isSupportPressure;
    case 'isSupportHistoricalECG':
      return source.isSupportHistoricalECG;
    case 'isSupportRealTimeDataUpload':
      return source.isSupportRealTimeDataUpload;
    case 'isSupportRealTimeECG':
      return source.isSupportRealTimeECG;
    case 'isSupportRespirationRate':
      return source.isSupportRespirationRate;
    case 'isSupportSleep':
      return source.isSupportSleep;
    case 'isSupportSport':
      return source.isSupportSport;
    case 'isSupportStep':
      return source.isSupportStep;
    case 'isSupportTemperature':
      return source.isSupportTemperature;
    case 'isSupportStartBloodGlucoseMeasurement':
      return source.isSupportStartBloodGlucoseMeasurement;
    case 'isSupportStartBloodOxygenMeasurement':
      return source.isSupportStartBloodOxygenMeasurement;
    case 'isSupportStartBloodPressureMeasurement':
      return source.isSupportStartBloodPressureMeasurement;
    case 'isSupportStartBodyTemperatureMeasurement':
      return source.isSupportStartBodyTemperatureMeasurement;
    case 'isSupportStartHeartRateMeasurement':
      return source.isSupportStartHeartRateMeasurement;
    case 'isSupportStartHRVMeasurement':
      return source.isSupportStartHRVMeasurement;
    case 'isSupportStartPressureMeasurement':
      return source.isSupportStartPressureMeasurement;
    case 'isSupportStartRespirationRateMeasurement':
      return source.isSupportStartRespirationRateMeasurement;
    case 'isSupportUricAcid':
      return source.isSupportUricAcid;
    case 'isSupportVo2max':
      return source.isSupportVo2max;
    default:
      return null;
  }
}

int? readInt(dynamic source, List<String> names) {
  final value = readAny(source, names);
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? readDouble(dynamic source, List<String> names) {
  final value = readAny(source, names);
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

bool? readBool(dynamic source, List<String> names) {
  final value = readAny(source, names);
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().toLowerCase();
  if (text == 'true') return true;
  if (text == 'false') return false;
  return null;
}

String valueOrDash(num? value) => value == null || value == 0 ? '-' : '$value';

String doubleOrDash(double? value, int decimals) {
  return value == null || value == 0 ? '-' : value.toStringAsFixed(decimals);
}

String percent(int? value) => value == null || value <= 0 ? '-' : '$value%';

String normalizedBatteryStatus(dynamic value) {
  final raw = value?.toString().split('.').last.trim().toLowerCase() ?? '';
  switch (raw) {
    case '0':
    case 'normal':
      return 'normal';
    case '1':
    case 'low':
      return 'low';
    case '2':
    case 'charging':
    case 'charge':
      return 'charging';
    case '3':
    case 'full':
    case 'fully':
      return 'full';
    default:
      return raw.isEmpty ? '-' : raw;
  }
}

String batteryDisplayText(int? value, String? status) {
  final percentage = percent(value);
  final hasPercentage = percentage != '-';
  switch (normalizedBatteryStatus(status)) {
    case 'charging':
      return hasPercentage ? 'Charging $percentage' : 'Charging';
    case 'full':
      return hasPercentage ? 'Full $percentage' : 'Full';
    case 'low':
      return hasPercentage ? 'Low $percentage' : 'Low';
    default:
      return percentage;
  }
}

IconData batteryIcon(int? value, {String? status}) {
  switch (normalizedBatteryStatus(status)) {
    case 'charging':
      return Icons.battery_charging_full;
    case 'full':
      return Icons.battery_full;
    case 'low':
      return Icons.battery_alert;
  }
  if (value == null || value <= 0) return Icons.battery_unknown;
  if (value <= 20) return Icons.battery_alert;
  return Icons.battery_std;
}

String measurementStateLabel(int state) {
  switch (state) {
    case 0:
      return 'ended';
    case 1:
      return 'completed';
    case 2:
      return 'failed';
    case 3:
      return 'running';
    default:
      return 'state $state';
  }
}

String measureTypeIndexLabel(int index) {
  switch (index) {
    case 0:
      return 'Heart rate';
    case 1:
      return 'Blood pressure';
    case 2:
      return 'SpO2';
    case 3:
      return 'Respiration';
    case 4:
      return 'Temperature';
    case 5:
      return 'Glucose';
    case 6:
      return 'Uric acid';
    case 7:
      return 'Blood ketone';
    case 8:
      return 'EDA';
    case 9:
      return 'Blood fat';
    case 10:
      return 'HRV';
    case 11:
      return 'PPG';
    case 12:
      return 'Stress';
    case 13:
      return 'VO2 max';
    default:
      return 'type $index';
  }
}

String measureTypeLabel(DeviceAppControlMeasureHealthDataType type) {
  switch (type) {
    case DeviceAppControlMeasureHealthDataType.heartRate:
      return 'Heart rate';
    case DeviceAppControlMeasureHealthDataType.bloodPressure:
      return 'Blood pressure';
    case DeviceAppControlMeasureHealthDataType.bloodOxygen:
      return 'SpO2';
    case DeviceAppControlMeasureHealthDataType.respirationRate:
      return 'Respiration';
    case DeviceAppControlMeasureHealthDataType.bodyTemperature:
      return 'Temperature';
    case DeviceAppControlMeasureHealthDataType.bloodGlucose:
      return 'Glucose';
    case DeviceAppControlMeasureHealthDataType.uricAcid:
      return 'Uric acid';
    case DeviceAppControlMeasureHealthDataType.bloodKetone:
      return 'Blood ketone';
    case DeviceAppControlMeasureHealthDataType.eda:
      return 'EDA';
    case DeviceAppControlMeasureHealthDataType.bloodFat:
      return 'Blood fat';
    case DeviceAppControlMeasureHealthDataType.hrv:
      return 'HRV';
    case DeviceAppControlMeasureHealthDataType.ppg:
      return 'PPG';
    case DeviceAppControlMeasureHealthDataType.pressure:
      return 'Stress';
    case DeviceAppControlMeasureHealthDataType.vo2max:
      return 'VO2 max';
  }
}

String timeLabel(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  final month = time.month.toString().padLeft(2, '0');
  final day = time.day.toString().padLeft(2, '0');
  return '$month/$day $hour:$minute';
}

String timeOfDayLabel(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

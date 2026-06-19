part of '../main.dart';

Map<String, dynamic> buildCloudHistoryBatch({
  required dynamic device,
  required DeviceBasicSnapshot? basicInfo,
  required DeviceFeatureSnapshot? features,
  required RingHistory history,
}) {
  final now = DateTime.now().toUtc();
  final basicDeviceId = basicInfo?.deviceId;
  final deviceId = basicDeviceId != null && basicDeviceId != '-'
      ? basicDeviceId
      : deviceAddress(device);
  final safeDeviceId = deviceId == 'Unknown address'
      ? 'unknown-device'
      : deviceId;
  final batchId = '$safeDeviceId-${now.toIso8601String()}'.replaceAll(
    RegExp(r'[^A-Za-z0-9_.:-]'),
    '_',
  );

  return {
    'schemaVersion': 1,
    'source': {
      'provider': 'seek_nirvana',
      'sdk': 'vyana_sdk',
      'transport': 'ble',
    },
    'device': {
      'deviceId': basicInfo?.deviceId,
      'address': deviceAddress(device),
      'name': deviceLabel(device),
      'deviceType': basicInfo?.deviceType,
      'firmwareVersion': basicInfo?.firmwareVersion,
      'batteryPower': basicInfo?.batteryPower,
    },
    'sync': {
      'batchId': batchId,
      'pulledAt': now.toIso8601String(),
      'phoneTimeZone': DateTime.now().timeZoneName,
    },
    'capabilities': features?.flags ?? const <String, bool>{},
    'summary': {'totalRecords': history.totalRecords, 'counts': history.counts},
    'records': {
      'steps': history.steps
          .map((record) => _cloudRecord('step', safeDeviceId, record))
          .toList(),
      'sleepSessions': history.sleep
          .map((record) => _cloudSleepRecord(safeDeviceId, record))
          .toList(),
      'heartRate': history.heartRate
          .map((record) => _cloudRecord('heart_rate', safeDeviceId, record))
          .toList(),
      'bloodPressure': history.bloodPressure
          .map((record) => _cloudRecord('blood_pressure', safeDeviceId, record))
          .toList(),
      'combinedVitals': history.combined
          .map(
            (record) => _cloudRecord('combined_vitals', safeDeviceId, record),
          )
          .toList(),
      'biomarkers': history.invasive
          .map((record) => _cloudRecord('biomarker', safeDeviceId, record))
          .toList(),
      'sportSessions': history.sport
          .map((record) => _cloudRecord('sport_session', safeDeviceId, record))
          .toList(),
    },
  };
}

Map<String, dynamic> _cloudRecord(
  String type,
  String deviceId,
  dynamic record,
) {
  final start = readInt(record, const ['startTimeStamp', 'timestamp', 'time']);
  final end = readInt(record, const ['endTimeStamp']);
  return {
    'recordId': cloudRecordId(deviceId, type, start, end),
    'type': type,
    'startTimeStamp': start,
    'startTime': epochSecondsToIso(start),
    'endTimeStamp': end,
    'endTime': epochSecondsToIso(end),
    'metrics': _cloudMetricsFor(type, record),
    'raw': rawSdkRecord(record),
  };
}

Map<String, dynamic> _cloudSleepRecord(String deviceId, dynamic record) {
  final base = _cloudRecord('sleep_session', deviceId, record);
  final session = SleepSessionSummary.fromDynamic(record);
  return {
    ...base,
    'metrics': {
      'isNewSleepProtocol': session.isNewSleepProtocol,
      'stages': session.breakdown.toCloudJson(),
      'segments': session.segments
          .map((segment) => segment.toCloudJson())
          .toList(),
    },
  };
}

Map<String, dynamic> _cloudMetricsFor(String type, dynamic record) {
  switch (type) {
    case 'step':
      return {
        'steps': readInt(record, const ['step', 'steps']),
        'distanceMeters': readInt(record, const ['distance']),
        'calories': readInt(record, const ['calories']),
      };
    case 'heart_rate':
      return {
        'heartRateBpm': readInt(record, const ['heartRate']),
      };
    case 'blood_pressure':
      return {
        'systolicMmHg': readInt(record, const [
          'systolicBloodPressure',
          'systolic',
        ]),
        'diastolicMmHg': readInt(record, const [
          'diastolicBloodPressure',
          'diastolic',
        ]),
        'mode': readInt(record, const ['mode']),
      };
    case 'combined_vitals':
      return {
        'bloodOxygenPercent': readInt(record, const ['bloodOxygen']),
        'respirationRateRpm': readInt(record, const ['respirationRate']),
        'hrvMs': readInt(record, const ['hrv']),
        'cvrr': readInt(record, const ['cvrr']),
        'temperatureC': validTemperature(
          readDouble(record, const ['temperature']),
        ),
        'bloodGlucoseMmolL': readDouble(record, const ['bloodGlucose']),
        'fat': readDouble(record, const ['fat']),
      };
    case 'biomarker':
      return {
        'bloodGlucoseMmolL': readDouble(record, const ['bloodGlucose']),
        'uricAcidUmolL': readInt(record, const ['uricAcid']),
        'bloodKetoneMmolL': readDouble(record, const ['bloodKetone']),
        'totalCholesterolMmolL': readDouble(record, const ['totalCholesterol']),
        'hdlCholesterolMmolL': readDouble(record, const ['hdlCholesterol']),
        'ldlCholesterolMmolL': readDouble(record, const ['ldlCholesterol']),
        'triglyceridesMmolL': readDouble(record, const ['triglycerides']),
      };
    case 'sport_session':
      return {
        'sportType': readInt(record, const ['sportType']),
        'startMethod': readInt(record, const ['flag']),
        'durationSeconds': readInt(record, const ['sportTime']),
        'steps': readInt(record, const ['step', 'steps']),
        'distanceMeters': readInt(record, const ['distance']),
        'calories': readInt(record, const ['calories']),
        'averageHeartRateBpm': readInt(record, const ['heartRate']),
        'minimumHeartRateBpm': readInt(record, const ['minimumHeartRate']),
        'maximumHeartRateBpm': readInt(record, const ['maximumHeartRate']),
      };
    default:
      return const {};
  }
}

Map<String, dynamic> rawSdkRecord(dynamic record) {
  final raw = <String, dynamic>{};
  const fields = [
    'isNewSleepProtocol',
    'startTimeStamp',
    'endTimeStamp',
    'deepSleepSeconds',
    'lightSleepSeconds',
    'remSleepSeconds',
    'step',
    'distance',
    'calories',
    'heartRate',
    'systolicBloodPressure',
    'diastolicBloodPressure',
    'mode',
    'bloodOxygen',
    'respirationRate',
    'hrv',
    'cvrr',
    'temperature',
    'bloodGlucoseMode',
    'bloodGlucose',
    'uricAcidMode',
    'uricAcid',
    'bloodKetoneMode',
    'bloodKetone',
    'bloodFatMode',
    'totalCholesterol',
    'hdlCholesterol',
    'ldlCholesterol',
    'triglycerides',
    'sportType',
    'sportTime',
    'flag',
    'minimumHeartRate',
    'maximumHeartRate',
  ];
  for (final field in fields) {
    final value = readAny(record, [field]);
    if (value != null) raw[field] = value;
  }

  final details = sleepStageSegments(record);
  if (details.isNotEmpty) {
    raw['detail'] = details.map((segment) => segment.toCloudJson()).toList();
  }
  return raw;
}

Map<String, dynamic> cloudHistorySchemaExample() {
  return {
    'collection': 'ring_history_sync_batches',
    'document': {
      'schemaVersion': 1,
      'source': {
        'provider': 'seek_nirvana',
        'sdk': 'vyana_sdk',
        'transport': 'ble',
      },
      'device': {
        'deviceId': 'ring device id from SDK basic info',
        'address': 'BLE MAC or platform identifier',
        'name': 'ring display name',
        'deviceType': 'ring',
        'firmwareVersion': 'x.y',
      },
      'sync': {
        'batchId': 'deviceId-pulledAt',
        'pulledAt': 'UTC ISO-8601 timestamp',
        'phoneTimeZone': 'local timezone label',
      },
      'capabilities': {'isSupportSleep': true},
      'summary': {
        'totalRecords': 0,
        'counts': {
          'steps': 0,
          'sleep': 0,
          'heartRate': 0,
          'bloodPressure': 0,
          'combined': 0,
          'invasive': 0,
          'sport': 0,
        },
      },
      'records': {
        'sleepSessions': [
          {
            'recordId': 'device:type:start:end',
            'type': 'sleep_session',
            'startTimeStamp': 0,
            'startTime': 'UTC ISO-8601 timestamp',
            'endTimeStamp': 0,
            'endTime': 'UTC ISO-8601 timestamp',
            'metrics': {
              'isNewSleepProtocol': true,
              'stages': {
                'deepSeconds': 0,
                'lightSeconds': 0,
                'remSeconds': 0,
                'awakeSeconds': 0,
                'asleepSeconds': 0,
                'totalSeconds': 0,
              },
              'segments': [
                {
                  'startTimeStamp': 0,
                  'startTime': 'UTC ISO-8601 timestamp',
                  'durationSeconds': 0,
                  'sleepType': SleepType.rem,
                  'stage': 'REM',
                },
              ],
            },
            'raw': {'deepSleepSeconds': 0, 'detail': []},
          },
        ],
      },
    },
  };
}

String cloudRecordId(String deviceId, String type, int? start, int? end) {
  return [deviceId, type, start ?? 'na', end ?? 'na'].join(':');
}

String? epochSecondsToIso(int? seconds) {
  if (seconds == null || seconds <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(
    seconds * 1000,
    isUtc: true,
  ).toIso8601String();
}

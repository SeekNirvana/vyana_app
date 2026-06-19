part of '../../main.dart';

/// Persists the last successful ring history pull so Home/Vitals can render
/// immediately on launch while a fresh BLE sync runs in the background.
class RingHistoryCacheService {
  RingHistoryCacheService(this._db);

  final VyanaDatabase _db;

  Future<RingHistoryCacheSnapshot?> loadForDevice(String deviceId) async {
    final row = await _db.getRingHistoryCache(deviceId);
    if (row == null) return null;
    return _snapshotFromRow(row);
  }

  Future<RingHistoryCacheSnapshot?> loadLatest() async {
    final row = await _db.getLatestRingHistoryCache();
    if (row == null) return null;
    return _snapshotFromRow(row);
  }

  Future<void> save({
    required String deviceId,
    required RingHistory history,
    RingVitals? vitals,
    DeviceBasicSnapshot? basicInfo,
  }) async {
    await _db.upsertRingHistoryCache(
      deviceId: deviceId,
      historyJson: jsonEncode(_encodeHistory(history)),
      vitalsJson: vitals == null ? null : jsonEncode(_encodeVitals(vitals)),
      basicInfoJson:
          basicInfo == null ? null : jsonEncode(_encodeBasicInfo(basicInfo)),
      recordCount: history.totalRecords,
      syncedAt: DateTime.now(),
    );
  }

  RingHistoryCacheSnapshot? _snapshotFromRow(RingHistoryCacheRow row) {
    try {
      final historyMap = Map<String, dynamic>.from(
        jsonDecode(row.historyJson) as Map,
      );
      return RingHistoryCacheSnapshot(
        deviceId: row.deviceId,
        history: _decodeHistory(historyMap),
        vitals: row.vitalsJson == null
            ? null
            : _decodeVitals(
                Map<String, dynamic>.from(jsonDecode(row.vitalsJson!) as Map),
              ),
        basicInfo: row.basicInfoJson == null
            ? null
            : _decodeBasicInfo(
                Map<String, dynamic>.from(
                  jsonDecode(row.basicInfoJson!) as Map,
                ),
              ),
        recordCount: row.recordCount,
        syncedAt: row.syncedAt,
      );
    } on Object {
      return null;
    }
  }

  static Map<String, dynamic> _encodeHistory(RingHistory history) {
    return {
      'steps': _encodeRecords(history.steps),
      'sleep': _encodeRecords(history.sleep),
      'heartRate': _encodeRecords(history.heartRate),
      'bloodPressure': _encodeRecords(history.bloodPressure),
      'combined': _encodeRecords(history.combined),
      'invasive': _encodeRecords(history.invasive),
      'sport': _encodeRecords(history.sport),
    };
  }

  static RingHistory _decodeHistory(Map<String, dynamic> map) {
    return RingHistory(
      steps: _decodeRecords(map['steps']),
      sleep: _decodeRecords(map['sleep']),
      heartRate: _decodeRecords(map['heartRate']),
      bloodPressure: _decodeRecords(map['bloodPressure']),
      combined: _decodeRecords(map['combined']),
      invasive: _decodeRecords(map['invasive']),
      sport: _decodeRecords(map['sport']),
    );
  }

  static List<Map<String, dynamic>> _encodeRecords(List<dynamic> records) {
    return records.map(_recordToMap).toList();
  }

  static Map<String, dynamic> _recordToMap(dynamic record) {
    if (record is Map) {
      return Map<String, dynamic>.from(
        record.map(
          (key, value) => MapEntry(key.toString(), _normalizeValue(value)),
        ),
      );
    }
    if (record is StepDataInfo) {
      return {
        'startTimeStamp': record.startTimeStamp,
        'endTimeStamp': record.endTimeStamp,
        'step': record.step,
        'distance': record.distance,
        'calories': record.calories,
      };
    }
    if (record is SleepDataInfo) {
      return {
        'isNewSleepProtocol': record.isNewSleepProtocol,
        'startTimeStamp': record.startTimeStamp,
        'endTimeStamp': record.endTimeStamp,
        'deepSleepSeconds': record.deepSleepSeconds,
        'lightSleepSeconds': record.lightSleepSeconds,
        'remSleepSeconds': record.remSleepSeconds,
        'detail': record.list.map(_recordToMap).toList(),
      };
    }
    if (record is SleepDetailDataInfo) {
      return {
        'startTimeStamp': record.startTimeStamp,
        'duration': record.duration,
        'sleepType': record.sleepType,
      };
    }
    if (record is HeartRateDataInfo) {
      return {
        'startTimeStamp': record.startTimeStamp,
        'heartRate': record.heartRate,
      };
    }
    if (record is BloodPressureDataInfo) {
      return {
        'startTimeStamp': record.startTimeStamp,
        'systolicBloodPressure': record.systolicBloodPressure,
        'diastolicBloodPressure': record.diastolicBloodPressure,
        'mode': record.mode,
      };
    }
    if (record is CombinedDataDataInfo) {
      return {
        'startTimeStamp': record.startTimeStamp,
        'step': record.step,
        'heartRate': record.heartRate,
        'systolicBloodPressure': record.systolicBloodPressure,
        'diastolicBloodPressure': record.diastolicBloodPressure,
        'bloodOxygen': record.bloodOxygen,
        'respirationRate': record.respirationRate,
        'hrv': record.hrv,
        'cvrr': record.cvrr,
        'bloodGlucose': record.bloodGlucose,
        'fat': record.fat,
        'temperature': record.temperature,
      };
    }
    if (record is InvasiveComprehensiveDataInfo) {
      return {
        'startTimeStamp': record.startTimeStamp,
        'bloodGlucoseMode': record.bloodGlucoseMode,
        'bloodGlucose': record.bloodGlucose,
        'uricAcidMode': record.uricAcidMode,
        'uricAcid': record.uricAcid,
        'bloodKetoneMode': record.bloodKetoneMode,
        'bloodKetone': record.bloodKetone,
        'bloodFatMode': record.bloodFatMode,
        'totalCholesterol': record.totalCholesterol,
        'hdlCholesterol': record.hdlCholesterol,
        'ldlCholesterol': record.ldlCholesterol,
        'triglycerides': record.triglycerides,
      };
    }
    if (record is SportModeDataInfo) {
      return {
        'startTimeStamp': record.startTimeStamp,
        'endTimeStamp': record.endTimeStamp,
        'flag': record.flag,
        'sportType': record.sportType,
        'sportTime': record.sportTime,
        'step': record.step,
        'distance': record.distance,
        'calories': record.calories,
        'heartRate': record.heartRate,
        'minimumHeartRate': record.minimumHeartRate,
        'maximumHeartRate': record.maximumHeartRate,
      };
    }
    if (record is BodyIndexDataInfo) {
      return record.toJson();
    }
    final normalized = _normalizeValue(record);
    if (normalized is Map) {
      return Map<String, dynamic>.from(normalized);
    }
    return {'value': normalized?.toString()};
  }

  static List<dynamic> _decodeRecords(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((record) => Map<String, dynamic>.from(record))
        .toList();
  }

  static dynamic _normalizeValue(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, entry) => MapEntry(key.toString(), _normalizeValue(entry)),
      );
    }
    if (value is List) {
      return value.map(_normalizeValue).toList();
    }
    return value;
  }

  static Map<String, dynamic> _encodeVitals(RingVitals vitals) {
    return {
      'battery': vitals.battery,
      'steps': vitals.steps,
      'distanceMeters': vitals.distanceMeters,
      'calories': vitals.calories,
      'heartRate': vitals.heartRate,
      'bloodOxygen': vitals.bloodOxygen,
      'respirationRate': vitals.respirationRate,
      'hrv': vitals.hrv,
      'temperature': vitals.temperature,
      'bloodPressure': vitals.bloodPressure,
      'pressure': vitals.pressure,
      'sleepSummary': vitals.sleepSummary,
      'bloodGlucose': vitals.bloodGlucose,
      'uricAcid': vitals.uricAcid,
      'totalCholesterol': vitals.totalCholesterol,
      'updatedAt': vitals.updatedAt?.toIso8601String(),
    };
  }

  static RingVitals _decodeVitals(Map<String, dynamic> map) {
    final updatedAtRaw = map['updatedAt']?.toString();
    return RingVitals(
      battery: _cacheJsonInt(map['battery']),
      steps: _cacheJsonInt(map['steps']),
      distanceMeters: _cacheJsonInt(map['distanceMeters']),
      calories: _cacheJsonInt(map['calories']),
      heartRate: _cacheJsonInt(map['heartRate']),
      bloodOxygen: _cacheJsonInt(map['bloodOxygen']),
      respirationRate: _cacheJsonInt(map['respirationRate']),
      hrv: _cacheJsonInt(map['hrv']),
      temperature: _cacheJsonDouble(map['temperature']),
      bloodPressure: map['bloodPressure']?.toString(),
      pressure: _cacheJsonDouble(map['pressure']),
      sleepSummary: map['sleepSummary']?.toString(),
      bloodGlucose: _cacheJsonDouble(map['bloodGlucose']),
      uricAcid: _cacheJsonInt(map['uricAcid']),
      totalCholesterol: _cacheJsonDouble(map['totalCholesterol']),
      updatedAt:
          updatedAtRaw == null ? null : DateTime.tryParse(updatedAtRaw),
    );
  }

  static Map<String, dynamic> _encodeBasicInfo(DeviceBasicSnapshot basic) {
    return {
      'deviceId': basic.deviceId,
      'deviceType': basic.deviceType,
      'batteryStatus': basic.batteryStatus,
      'batteryPower': basic.batteryPower,
      'firmwareVersion': basic.firmwareVersion,
    };
  }

  static DeviceBasicSnapshot _decodeBasicInfo(Map<String, dynamic> map) {
    return DeviceBasicSnapshot(
      deviceId: map['deviceId']?.toString() ?? '-',
      deviceType: map['deviceType']?.toString() ?? '-',
      batteryStatus: map['batteryStatus']?.toString() ?? '-',
      batteryPower: _cacheJsonInt(map['batteryPower']),
      firmwareVersion: map['firmwareVersion']?.toString() ?? '-',
    );
  }

  static int? _cacheJsonInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _cacheJsonDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}

class RingHistoryCacheSnapshot {
  const RingHistoryCacheSnapshot({
    required this.deviceId,
    required this.history,
    this.vitals,
    this.basicInfo,
    required this.recordCount,
    required this.syncedAt,
  });

  final String deviceId;
  final RingHistory history;
  final RingVitals? vitals;
  final DeviceBasicSnapshot? basicInfo;
  final int recordCount;
  final DateTime syncedAt;
}

final ringHistoryCacheServiceProvider = Provider<RingHistoryCacheService>((ref) {
  return RingHistoryCacheService(ref.watch(databaseProvider));
});
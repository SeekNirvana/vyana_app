import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vyana/main.dart';
import 'package:vyana_sdk/vyana_sdk.dart';

void main() {
  test('sleep summaries are calculated locally from SDK fields', () {
    final sleep = {
      'deepSleepSeconds': 3600,
      'lightSleepSeconds': 5400,
      'remSleepSeconds': 1800,
    };

    expect(sleepText(sleep), '3h 0m');
  });

  test('sleep stage details include REM and awake segments', () {
    final sleep = {
      'isNewSleepProtocol': true,
      'deepSleepSeconds': 3600,
      'lightSleepSeconds': 5400,
      'remSleepSeconds': 1800,
      'detail': [
        {'startTimeStamp': 1000, 'duration': 600, 'sleepType': SleepType.rem},
        {'startTimeStamp': 1600, 'duration': 300, 'sleepType': SleepType.awake},
      ],
    };

    final session = SleepSessionSummary.fromDynamic(sleep);

    expect(session.breakdown.asleepSeconds, 10800);
    expect(session.breakdown.awakeSeconds, 300);
    expect(session.segments.map((segment) => segment.label), ['REM', 'Awake']);
  });

  test('sleep sections are assigned to the day users expect', () {
    final eveningStart =
        DateTime(2026, 5, 30, 18).millisecondsSinceEpoch ~/ 1000;
    final morningStart =
        DateTime(2026, 5, 31, 2).millisecondsSinceEpoch ~/ 1000;
    final continuousStart =
        DateTime(2026, 6, 1, 22).millisecondsSinceEpoch ~/ 1000;
    final sleepRecords = [
      {
        'startTimeStamp': eveningStart,
        'endTimeStamp': eveningStart + 12600,
        'deepSleepSeconds': 3600,
        'lightSleepSeconds': 7200,
        'remSleepSeconds': 1800,
      },
      {
        'startTimeStamp': morningStart,
        'endTimeStamp': morningStart + 21600,
        'deepSleepSeconds': 5400,
        'lightSleepSeconds': 10800,
        'remSleepSeconds': 5400,
      },
      {
        'startTimeStamp': continuousStart,
        'endTimeStamp': continuousStart + 28800,
        'deepSleepSeconds': 7200,
        'lightSleepSeconds': 14400,
        'remSleepSeconds': 7200,
      },
    ];

    final days = sleepDaySummaries(sleepRecords);
    final may30 = days.firstWhere(
      (day) => day.day.month == 5 && day.day.day == 30,
    );
    final may31 = days.firstWhere(
      (day) => day.day.month == 5 && day.day.day == 31,
    );
    final june2 = days.firstWhere(
      (day) => day.day.month == 6 && day.day.day == 2,
    );

    expect(days.length, 3);
    expect(may30.windowStart.hour, 18);
    expect(may31.windowStart.hour, 2);
    expect(june2.windowStart.hour, 22);
    expect(durationText(may31.breakdown.asleepSeconds), '6h 0m');
  });

  test('overnight sleep vitals ignore samples outside sleep windows', () {
    final start = DateTime(2026, 6, 1, 22).millisecondsSinceEpoch ~/ 1000;
    final sleepRecords = [
      {
        'startTimeStamp': start,
        'endTimeStamp': start + 28800,
        'deepSleepSeconds': 7200,
        'lightSleepSeconds': 14400,
        'remSleepSeconds': 7200,
      },
    ];
    final history = RingHistory(
      steps: const [],
      sleep: sleepRecords,
      heartRate: [
        {
          'startTimeStamp':
              DateTime(2026, 6, 1, 23).millisecondsSinceEpoch ~/ 1000,
          'heartRate': 60,
        },
        {
          'startTimeStamp':
              DateTime(2026, 6, 2, 3).millisecondsSinceEpoch ~/ 1000,
          'heartRate': 70,
        },
        {
          'startTimeStamp':
              DateTime(2026, 6, 2, 12).millisecondsSinceEpoch ~/ 1000,
          'heartRate': 110,
        },
      ],
      bloodPressure: const [],
      combined: [
        {
          'startTimeStamp':
              DateTime(2026, 6, 2, 1).millisecondsSinceEpoch ~/ 1000,
          'bloodOxygen': 96,
          'hrv': 52,
        },
      ],
      invasive: const [],
      sport: const [],
    );

    final day = sleepDaySummaries(sleepRecords).first;
    final vitals = sleepVitalsForDay(day, history);
    final heartRate = vitals.series.firstWhere(
      (series) => series.label == 'Heart rate',
    );
    final spo2 = vitals.series.firstWhere((series) => series.label == 'SpO2');

    expect(day.day.day, 2);
    expect(heartRate.points.length, 2);
    expect(heartRate.average, 65);
    expect(spo2.average, 96);
  });

  testWidgets('sleep waveform handles segments clipped at chart end', (
    tester,
  ) async {
    final windowStart = DateTime(2026, 6, 2, 0);
    final windowEnd = windowStart.add(const Duration(hours: 8));
    final endSeconds = windowEnd.millisecondsSinceEpoch ~/ 1000;
    final day = SleepDaySummary(
      day: DateTime(2026, 6, 2),
      windowStart: windowStart,
      windowEnd: windowEnd,
      sections: const [],
      sessions: const [],
      breakdown: const SleepStageBreakdown(
        deepSeconds: 60,
        lightSeconds: 60,
        remSeconds: 0,
        awakeSeconds: 0,
        segmentCount: 2,
      ),
      waveform: [
        SleepWaveSegment(
          startTimeStamp: endSeconds - 1,
          endTimeStamp: endSeconds + 600,
          sleepType: SleepType.lightSleep,
          approximate: false,
        ),
        SleepWaveSegment(
          startTimeStamp: endSeconds + 1,
          endTimeStamp: endSeconds + 600,
          sleepType: SleepType.rem,
          approximate: false,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 356,
            height: 240,
            child: SleepWaveform(day: day, height: 184),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('capabilities panel de-duplicates SDK start flags', (
    tester,
  ) async {
    final features = DeviceFeatureSnapshot.fromDynamic({
      'isSupportHeartRate': true,
      'isSupportStartHeartRateMeasurement': true,
      'isSupportBloodOxygen': true,
      'isSupportStartBloodOxygenMeasurement': true,
      'isSupportSleep': true,
      'isSupportStep': true,
      'isSupportFindDevice': true,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FeaturePanel(features: features)),
      ),
    );

    expect(find.text('Heart rate'), findsOneWidget);
    expect(find.text('SpO2'), findsOneWidget);
    expect(find.text('Sleep stages'), findsOneWidget);
    expect(find.text('Steps'), findsOneWidget);
    expect(find.text('Find ring'), findsOneWidget);
    expect(find.text('Start heart rate'), findsNothing);
    expect(find.text('Start blood oxygen'), findsNothing);
  });

  test('DeviceFeatureSnapshot parses factory reset support flag', () {
    final supported = DeviceFeatureSnapshot.fromDynamic({
      'isSupportFactorySettings': true,
    });
    expect(supported.supports('isSupportFactorySettings'), isTrue);
    expect(
      supported.items.singleWhere((item) => item.key == 'isSupportFactorySettings').supported,
      isTrue,
    );

    final unsupported = DeviceFeatureSnapshot.fromDynamic({
      'isSupportFactorySettings': false,
    });
    expect(unsupported.supports('isSupportFactorySettings'), isFalse);

    final missing = DeviceFeatureSnapshot.fromDynamic({});
    expect(missing.supports('isSupportFactorySettings'), isFalse);
  });

  test('ring health delete treats unsupported optional types as success', () {
    expect(
      ringHealthDeleteSucceeded([
        (label: 'step', statusCode: PluginState.succeed),
        (label: 'sleep', statusCode: PluginState.succeed),
        (label: 'heartRate', statusCode: PluginState.succeed),
        (label: 'bloodPressure', statusCode: PluginState.succeed),
        (label: 'combined', statusCode: PluginState.succeed),
        (label: 'sport', statusCode: PluginState.unavailable),
      ]),
      isTrue,
    );

    expect(
      ringHealthDeleteSucceeded([
        (label: 'step', statusCode: PluginState.succeed),
        (label: 'sleep', statusCode: PluginState.failed),
      ]),
      isFalse,
    );
  });

  test('ring health delete targets mirror sync feature gates', () {
    final full = DeviceFeatureSnapshot.fromDynamic({
      'isSupportSport': true,
      'isSupportBloodGlucose': true,
    });
    expect(
      ringHealthDeleteTargets(full).map((target) => target.label).toList(),
      ['step', 'sleep', 'heartRate', 'bloodPressure', 'combined', 'invasive', 'sport'],
    );

    final minimal = DeviceFeatureSnapshot.fromDynamic({
      'isSupportSport': false,
      'isSupportBloodGlucose': false,
      'isSupportUricAcid': false,
      'isSupportBloodKetone': false,
      'isSupportBloodFat': false,
    });
    expect(
      ringHealthDeleteTargets(minimal).map((target) => target.label).toList(),
      ['step', 'sleep', 'heartRate', 'bloodPressure', 'combined'],
    );
  });

  test('cloud history batch keeps typed sleep stages for upload', () {
    final history = RingHistory(
      steps: const [],
      sleep: [
        {
          'startTimeStamp': 1000,
          'endTimeStamp': 2000,
          'deepSleepSeconds': 300,
          'lightSleepSeconds': 400,
          'remSleepSeconds': 200,
          'detail': [
            {
              'startTimeStamp': 1200,
              'duration': 200,
              'sleepType': SleepType.rem,
            },
          ],
        },
      ],
      heartRate: const [],
      bloodPressure: const [],
      combined: const [],
      invasive: const [],
      sport: const [],
    );

    final batch = buildCloudHistoryBatch(
      device: {'name': 'R36', 'macAddress': '08:00:00:00:01:5A'},
      basicInfo: null,
      features: null,
      history: history,
    );
    final sleepRecords =
        (batch['records'] as Map<String, dynamic>)['sleepSessions'] as List;
    final metrics = sleepRecords.first['metrics'] as Map<String, dynamic>;
    final stages = metrics['stages'] as Map<String, dynamic>;

    expect(batch['schemaVersion'], 1);
    expect(stages['remSeconds'], 200);
    expect((metrics['segments'] as List).first['stage'], 'REM');
  });

  test('live blood glucose events update vitals', () {
    final vitals = RingVitals.empty().mergeLiveEvent({
      NativeEventType.deviceRealBloodGlucose: '7.2',
    });

    expect(vitals.bloodGlucose, 7.2);
  });

  test('invalid SDK temperature values are hidden', () {
    expect(validTemperature(36.15), isNull);
    expect(validTemperature(36.6), 36.6);
  });

  test('step day summaries roll interval records into daily totals', () {
    final records = [
      {
        'startTimeStamp': DateTime(2026, 6, 10, 10).millisecondsSinceEpoch ~/ 1000,
        'step': 100,
        'distance': 80,
        'calories': 5,
      },
      {
        'startTimeStamp': DateTime(2026, 6, 10, 11).millisecondsSinceEpoch ~/ 1000,
        'step': 50,
        'distance': 40,
        'calories': 2,
      },
      {
        'startTimeStamp': DateTime(2026, 6, 11, 9).millisecondsSinceEpoch ~/ 1000,
        'step': 200,
        'distance': 120,
        'calories': 8,
      },
    ];

    final days = stepDaySummaries(records);
    expect(days.length, 2);
    expect(days.first.steps, 200);
    expect(days.last.steps, 150);
    expect(days.last.distanceMeters, 120);
    expect(days.last.calories, 7);
  });

  test('step streak counts consecutive goal days ending today or yesterday', () {
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final days = [
      StepDaySummary(
        day: day,
        steps: 6000,
        distanceMeters: 0,
        calories: 0,
        intervalCount: 1,
      ),
      StepDaySummary(
        day: day.subtract(const Duration(days: 1)),
        steps: 5500,
        distanceMeters: 0,
        calories: 0,
        intervalCount: 1,
      ),
      StepDaySummary(
        day: day.subtract(const Duration(days: 2)),
        steps: 1000,
        distanceMeters: 0,
        calories: 0,
        intervalCount: 1,
      ),
    ];

    expect(computeStepStreak(days), 2);
  });

  test('scan access messaging is platform-neutral for mobile devices', () {
    const access = ScanAccess(
      granted: false,
      permissionsGranted: true,
      locationEnabled: false,
      missingPermissions: [],
    );

    expect(access.message, contains('Location services'));
    expect(access.message, isNot(contains('Android 9')));
  });

  test('zero RSSI SDK scan devices are treated as system-connected', () {
    expect(
      deviceLooksSystemConnected({
        'macAddress': '08:00:00:00:01:5A',
        'rssiValue': 0,
      }),
      isTrue,
    );
    expect(
      deviceLooksSystemConnected({
        'macAddress': '08:00:00:00:01:5A',
        'rssiValue': -64,
      }),
      isFalse,
    );
  });

  test('device labels use SDK advertised names and platform identifiers', () {
    expect(
      deviceLabel({'name': 'PRANA V1', 'macAddress': '08:00:00:00:01:5B'}),
      'PRANA V1',
    );
    expect(deviceLabel({'macAddress': '08:00:00:00:01:5B'}), 'PRANA ring');
    expect(
      deviceAddress({'deviceIdentifier': 'ios-device-id'}),
      'ios-device-id',
    );
  });

  test('saved PRANA ring matching uses persisted hardware identity', () {
    final ring = SavedPranaRing.fromDevice({
      'name': 'PRANA V1',
      'macAddress': '08:00:00:00:01:5A',
      'deviceIdentifier': '08:00:00:00:01:5A',
      'rssiValue': -61,
    });

    expect(
      ring.matches({
        'name': 'Different advertised name',
        'macAddress': '08:00:00:00:01:5A',
      }),
      isTrue,
    );
    expect(
      ring.matches({'name': 'PRANA V1', 'macAddress': '08:00:00:00:01:5B'}),
      isFalse,
    );
  });

  test('paired PRANA ring persists identity and observed stats', () async {
    SharedPreferences.setMockInitialValues({});
    final ring = SavedPranaRing.fromDevice(
      {'name': 'PRANA V1', 'macAddress': '08:00:00:00:01:5A', 'rssiValue': -58},
      basicInfo: DeviceBasicSnapshot.fromDynamic({
        'deviceID': 15,
        'deviceType': 1,
        'batteryStatus': 2,
        'batteryPower': 74,
        'firmwareMajorVersion': 1,
        'firmwareSubVersion': 2,
      }),
    );

    await PranaRingStore.save(ring);
    final restored = await PranaRingStore.load();

    expect(restored?.displayName, 'PRANA V1');
    expect(restored?.displayAddress, '08:00:00:00:01:5A');
    expect(restored?.batteryPower, 74);
    expect(restored?.batteryStatus, 'charging');
  });

  test('battery status maps SDK charging states into display labels', () {
    final basic = DeviceBasicSnapshot.fromDynamic({
      'deviceID': 15,
      'deviceType': 1,
      'batteryStatus': 2,
      'batteryPower': 74,
      'firmwareMajorVersion': 1,
      'firmwareSubVersion': 2,
    });

    expect(basic.batteryStatus, 'charging');
    expect(
      batteryDisplayText(basic.batteryPower, basic.batteryStatus),
      'Charging 74%',
    );
    expect(
      batteryIcon(basic.batteryPower, status: basic.batteryStatus),
      Icons.battery_charging_full,
    );
  });

  test('ECG RR and HRV algorithm events do not complete one-shot tests', () {
    expect(
      containsLiveMeasurementValue({
        NativeEventType.deviceRealECGAlgorithmHRV: 85,
      }),
      isFalse,
    );
    expect(
      containsLiveMeasurementValue({
        NativeEventType.deviceRealECGAlgorithmRR: 780,
      }),
      isFalse,
    );
    expect(
      containsLiveMeasurementValue({NativeEventType.deviceRealHeartRate: 72}),
      isTrue,
    );
  });

  test('ECG waveform payloads and contact status parse from SDK events', () {
    expect(ecgSamplesFromPayload([1, '2.5', -3]), [1.0, 2.5, -3.0]);
    expect(
      ecgSamplesFromPayload({
        'filteredData': ['0.1', '0.2', '0.3'],
      }),
      [0.1, 0.2, 0.3],
    );
    expect(ecgContactAttached({'EcgStatus': 0}), isTrue);
    expect(ecgContactAttached({'EcgStatus': 1}), isFalse);
  });

  test('ECG result parser applies SDK interpretation priority', () {
    expect(
      ParsedEcgResult.fromDynamic({
        'hearRate': 80,
        'qrsType': 1,
        'afflag': true,
        'hrvNorm': 30,
      }).interpretation,
      'Atrial fibrillation flag',
    );
    expect(
      ParsedEcgResult.fromDynamic({
        'hearRate': 130,
        'qrsType': 1,
        'afflag': false,
        'hrvNorm': 30,
      }).interpretation,
      'Suspected tachycardia',
    );
    expect(
      ParsedEcgResult.fromDynamic({
        'hearRate': 80,
        'qrsType': 14,
        'afflag': false,
      }).interpretation,
      'Failed or noisy measurement',
    );
  });

  test('ECG failed or missing diagnosis is not result-eligible', () {
    expect(
      ParsedEcgResult.fromDynamic({
        'hearRate': 80,
        'qrsType': 14,
        'afflag': false,
      }).isMeasurementSuccessful,
      isFalse,
    );
    expect(
      ParsedEcgResult.fromDynamic({
        'hearRate': 80,
        'qrsType': 1,
        'afflag': false,
      }).isMeasurementSuccessful,
      isTrue,
    );
  });

  test('ECG session separates preparation, contact wait, and recording', () {
    final preparing = EcgSessionSnapshot(
      startedAt: null,
      endedAt: null,
      capturedAt: DateTime(2026),
      preStartRemainingSeconds: 3,
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
    final waiting = EcgSessionSnapshot(
      startedAt: null,
      endedAt: null,
      capturedAt: DateTime(2026),
      preStartRemainingSeconds: null,
      waitingForContact: true,
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

    expect(preparing.isPreparing, isTrue);
    expect(preparing.stateLabel, 'Starting in 3s');
    expect(waiting.waitingForContact, isTrue);
    expect(waiting.stateLabel, 'Waiting for contact');
    expect(waiting.canReadResult, isFalse);
  });

  test('vitals plausibility gates reject loose-contact garbage', () {
    // Grounded in real ring data: HRV artefact cluster ~175-179, zeros on no
    // contact, glucose 0 = no contact.
    expect(plausibleHrv(179), isNull);
    expect(plausibleHrv(0), isNull);
    expect(plausibleHrv(65), 65);
    expect(plausibleSpo2(0), isNull);
    expect(plausibleSpo2(97), 97);
    expect(plausibleGlucose(0), isNull);
    expect(plausibleGlucose(5.1), 5.1);
    expect(plausibleHeartRate(0), isNull);
    expect(plausibleHeartRate(72), 72);
  });

  test('no-contact record (all-zero vitals) is detected', () {
    expect(
      isNoContactRecord({
        'heartRate': 0,
        'bloodOxygen': 0,
        'hrv': 0,
        'temperature': 0.15,
      }),
      isTrue,
    );
    expect(
      isNoContactRecord({
        'heartRate': 72,
        'bloodOxygen': 97,
        'hrv': 65,
        'temperature': 36.7,
      }),
      isFalse,
    );
  });

  test('current vitals pick the latest plausible value, skipping artefacts', () {
    final history = RingHistory(
      steps: const [],
      sleep: const [],
      heartRate: const [],
      bloodPressure: const [],
      combined: [
        // Oldest: good reading.
        {
          'startTimeStamp': 1000,
          'heartRate': 70,
          'bloodOxygen': 97,
          'hrv': 60,
          'temperature': 36.7,
          'bloodGlucose': 5.1,
        },
        // Newer: HRV artefact but otherwise fine.
        {
          'startTimeStamp': 2000,
          'heartRate': 74,
          'bloodOxygen': 98,
          'hrv': 179,
          'temperature': 36.8,
          'bloodGlucose': 5.4,
        },
        // Newest: no contact — everything zero.
        {
          'startTimeStamp': 3000,
          'heartRate': 0,
          'bloodOxygen': 0,
          'hrv': 0,
          'temperature': 0.15,
          'bloodGlucose': 0,
        },
      ],
      invasive: const [],
      sport: const [],
    );

    final vitals = RingVitals.fromHistory(history, null);
    // Newest plausible, not the zero record.
    expect(vitals.heartRate, 74);
    expect(vitals.bloodOxygen, 98);
    expect(vitals.bloodGlucose, 5.4);
    // 179 is rejected, so HRV falls back to the older good 60.
    expect(vitals.hrv, 60);

    // Charts drop the 179 artefact and the zero record entirely.
    final hrvPoints = vitalHistoryPoints(history, VitalsMetricKind.hrv);
    expect(hrvPoints.map((p) => p.value).toList(), [60.0]);
  });

  test('stress zones map inversely from HRV', () {
    expect(stressZoneForHrv(80), StressZone.calm);
    expect(stressZoneForHrv(50), StressZone.activated);
    expect(stressZoneForHrv(20), StressZone.stressed);
    expect(stressZoneLabel(StressZone.calm), 'Calm');
    expect(stressZoneLabel(StressZone.stressed), 'Stressed');
  });
}

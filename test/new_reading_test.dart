import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/main.dart';
import 'package:vyana_sdk/vyana_sdk.dart';

/// Item 133 — "New reading" shows the reading the ring actually sent.
void main() {
  final at = DateTime(2026, 11, 19, 10, 40);

  test('blood pressure reads 118/78, never a placeholder 1.0', () {
    final r = capturedReadingFrom(
      {
        'deviceRealBloodPressure': {
          'systolicBloodPressure': 118,
          'diastolicBloodPressure': 78,
        },
      },
      DeviceAppControlMeasureHealthDataType.bloodPressure,
      at: at,
    )!;
    expect(r.text, '118/78');
    expect(r.value, 118);
  });

  test('whole numbers without .0, temperature to one decimal', () {
    expect(
      capturedReadingFrom(
        {'deviceRealBloodOxygen': {'bloodOxygen': 97}},
        DeviceAppControlMeasureHealthDataType.bloodOxygen,
      )!.text,
      '97',
    );
    expect(
      capturedReadingFrom(
        {'deviceRealHeartRate': {'heartRate': 72}},
        DeviceAppControlMeasureHealthDataType.heartRate,
      )!.text,
      '72',
    );
    expect(
      capturedReadingFrom(
        {'deviceRealTemperature': {'temperature': 36.43}},
        DeviceAppControlMeasureHealthDataType.bodyTemperature,
      )!.text,
      '36.4',
    );
  });

  test('a loose ring sends zeros, which are no reading at all', () {
    expect(
      capturedReadingFrom(
        {'deviceRealBloodOxygen': {'bloodOxygen': 0}},
        DeviceAppControlMeasureHealthDataType.bloodOxygen,
      ),
      isNull,
    );
    expect(
      capturedReadingFrom(
        {
          'deviceRealBloodPressure': {
            'systolicBloodPressure': 0,
            'diastolicBloodPressure': 0,
          },
        },
        DeviceAppControlMeasureHealthDataType.bloodPressure,
      ),
      isNull,
    );
    // An event about something else carries nothing for this vital.
    expect(
      capturedReadingFrom(
        {'deviceRealHeartRate': {'heartRate': 72}},
        DeviceAppControlMeasureHealthDataType.bloodPressure,
      ),
      isNull,
    );
  });

  test('a reading taken by hand reaches the list, once', () {
    final ring = [
      VitalHistoryPoint(
        time: DateTime(2026, 11, 19, 9),
        value: 120,
        label: '120/80 mmHg',
      ),
    ];
    final reading = CapturedReading(
      kind: VitalsMetricKind.bloodPressure,
      value: 118,
      text: '118/78',
      at: at,
    );
    final merged = withCapturedReadings(ring, [reading], unit: 'mmHg');
    expect(merged.last.label, '118/78 mmHg');
    expect(merged.length, 2);

    // Once the ring also stores it, it is not shown twice.
    final stored = [
      ...ring,
      VitalHistoryPoint(
        time: at.add(const Duration(seconds: 30)),
        value: 118,
        label: '118/78 mmHg',
      ),
    ];
    expect(withCapturedReadings(stored, [reading], unit: 'mmHg').length, 2);
  });

  test('a kept reading survives a restart', () {
    final reading = CapturedReading(
      kind: VitalsMetricKind.spo2,
      value: 97,
      text: '97',
      at: at,
    );
    final back = CapturedReading.fromJson(reading.toJson())!;
    expect(back.kind, VitalsMetricKind.spo2);
    expect(back.text, '97');
    expect(back.at, at);
  });

  test('success never comes from a value already held', () {
    final source = File('lib/src/state/ring_controller.dart')
        .readAsStringSync();
    expect(source, isNot(contains('_plausibleVitalForType')));
    expect(source, isNot(contains('? 1 : null')));
  });
}

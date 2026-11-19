import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/main.dart';

/// Item 132 — the pill leaves Charging when the ring leaves the charger.
void main() {
  DeviceBasicSnapshot info(int battery, String status) => DeviceBasicSnapshot(
        deviceId: 'r1',
        deviceType: 'ring',
        batteryStatus: status,
        batteryPower: battery,
        firmwareVersion: '1.0',
      );

  test('off the charger at the same percentage is a change', () {
    expect(
      RingController.batteryPollChanged(
        previous: info(80, 'charging'),
        previousVitalsBattery: 80,
        next: info(80, 'normal'),
      ),
      isTrue,
    );
  });

  test('nothing new is nothing new', () {
    expect(
      RingController.batteryPollChanged(
        previous: info(80, 'normal'),
        previousVitalsBattery: 80,
        next: info(80, 'normal'),
      ),
      isFalse,
    );
  });

  test('a new percentage is still a change', () {
    expect(
      RingController.batteryPollChanged(
        previous: info(80, 'normal'),
        previousVitalsBattery: 80,
        next: info(79, 'normal'),
      ),
      isTrue,
    );
  });
}

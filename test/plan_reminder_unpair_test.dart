import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/src/services/vitals_notification_service.dart';

/// Item 109 — unpairing a ring leaves the weekly plan reminder alone.
void main() {
  test('the plan reminder is not a ring alert', () {
    expect(
      kRingAlertNotificationIds,
      isNot(contains(VitalsNotificationService.planReminderId)),
    );
    expect(VitalsNotificationService.planReminderId, 4307);
  });

  test('the ring alerts are still all cancelled', () {
    expect(kRingAlertNotificationIds, containsAll([4301, 4302, 4303, 4306]));
  });
}

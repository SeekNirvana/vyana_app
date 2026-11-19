import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/main.dart';

/// Item 110 — alert leftovers.
void main() {
  final now = DateTime(2026, 11, 19, 10);

  test('a ring that has just come back re-arms the offline alert', () {
    expect(
      RingController.offlineAlertNeedsRearming(
        wasConnected: false,
        lastArmedAt: now.subtract(const Duration(seconds: 2)),
        now: now,
      ),
      isTrue,
    );
  });

  test('a poll that says "still connected" does not', () {
    expect(
      RingController.offlineAlertNeedsRearming(
        wasConnected: true,
        lastArmedAt: now.subtract(const Duration(seconds: 2)),
        now: now,
      ),
      isFalse,
    );
  });

  test('but every few minutes it is refreshed', () {
    expect(
      RingController.offlineAlertNeedsRearming(
        wasConnected: true,
        lastArmedAt: now.subtract(const Duration(minutes: 5)),
        now: now,
      ),
      isTrue,
    );
  });

  test('the notification is sent only when its text changes', () {
    final source =
        File('lib/src/state/ring_controller.dart').readAsStringSync();
    expect(source, contains('if (next == _lastForegroundNotification) return;'));
  });

  test('Diagnostics reads the service log fresh', () {
    final source =
        File('lib/src/services/ring_foreground_service.dart').readAsStringSync();
    final log = source.indexOf('static Future<List<DateTime>> heartbeatLog()');
    expect(source.indexOf('await prefs.reload();', log), greaterThan(log));
  });
}

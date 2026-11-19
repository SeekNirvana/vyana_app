import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Item 111 — ring setup and pairing gaps.
void main() {
  final controller =
      File('lib/src/state/ring_controller.dart').readAsStringSync();
  final scan = File('lib/src/scan_screen.dart').readAsStringSync();
  final you = File('lib/src/screens/you_screen.dart').readAsStringSync();
  final home = File('lib/src/screens/home_screen.dart').readAsStringSync();

  test('setup is decided after the ring is saved, not before', () {
    expect(
      controller,
      contains('Future<void> handleScannerDetectedConnection(dynamic device) async'),
    );
    final detected = scan.indexOf('await widget.onConnectedDeviceDetected(');
    final first = scan.indexOf('widget.onFirstConnected?.call();', detected);
    expect(detected, greaterThan(0));
    expect(first, greaterThan(detected));
  });

  test('a greyed-out Pair says why and offers Retry, everywhere', () {
    expect(
      RegExp('retrySdkInit').allMatches(you).length,
      greaterThanOrEqualTo(2),
    );
    expect(home, contains('retrySdkInit'));
    expect(home, contains('ringServiceStatusLine(controller)'));
  });

  test("the ring screen's Sync and Reconnect say when they fail", () {
    expect(you, contains('onSyncWithFeedback: (context) async'));
    expect(you, contains('syncRingWithFeedback(context, c)'));
    expect(scan, contains("Couldn't reach your ring. Keep it close"));
  });
}

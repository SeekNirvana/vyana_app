import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/main.dart';

/// Item 122 — the risks that were worth checking, and what was found.
void main() {
  group('a ring that samples every 10 minutes is worn, not "not recorded"', () {
    final night = DateTime(2026, 11, 10, 0);
    RingHistory every(Duration step, {int count = 50}) => RingHistory(
          steps: const [],
          sleep: const [],
          heartRate: [
            for (var i = 0; i < count; i++)
              {
                'startTimeStamp':
                    night.add(step * i).millisecondsSinceEpoch ~/ 1000,
                'heartRate': 58,
              },
          ],
          bloodPressure: const [],
          combined: const [],
          invasive: const [],
          sport: const [],
        );

    test('every five-minute step between ten-minute readings counts', () {
      final history = every(const Duration(minutes: 10));
      for (var m = 0; m < 300; m += 5) {
        final from = night.add(Duration(minutes: m));
        expect(
          ringMeasuredBetween(
            history,
            from,
            from.add(const Duration(minutes: 5)),
          ),
          isTrue,
          reason: 'at +$m min',
        );
      }
    });

    test('an hour with no readings at all is still not recorded', () {
      final history = every(const Duration(minutes: 10), count: 6);
      final gapStart = night.add(const Duration(hours: 2));
      expect(
        ringMeasuredBetween(
          history,
          gapStart,
          gapStart.add(const Duration(minutes: 5)),
        ),
        isFalse,
      );
    });
  });

  test('sleep nights are worked out once per history', () {
    final history = RingHistory.empty();
    expect(identical(history.sleepNights, history.sleepNights), isTrue);
  });

  test('the plan reminder waits for the plan at a cold start', () {
    final source = File('lib/src/state/weekly_plan.dart').readAsStringSync();
    expect(source, contains('await _ref.read(weeklyPlanRowsProvider.future)'));
  });

  test('a reopened Wallet gets a modal with a live context', () {
    final source =
        File('lib/src/state/reown_wallet_service.dart').readAsStringSync();
    expect(source, contains('modal.modalContext != null'));
  });

  test('the share sheet has an anchor for iPad', () {
    final source =
        File('lib/src/services/file_exchange_service.dart').readAsStringSync();
    expect(source, contains('sharePositionOrigin: shareSheetAnchor()'));
  });
}

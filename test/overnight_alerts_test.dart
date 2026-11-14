import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/main.dart';

/// Item 63 — what the background service may conclude from an old snapshot,
/// and what it must not say at four in the morning.
void main() {
  final evening = DateTime(2026, 11, 15, 20, 30);

  RingAlertSnapshot snapshotAt(DateTime at) => RingAlertSnapshot(
        at: at,
        hasRingContext: true,
        paired: true,
        connected: true,
        batteryPercent: 12,
        batteryReadAt: at,
        lastSyncedAt: at,
        lastConnectionConfirmedAt: at,
        restingHr: 54,
        spo2: 97,
        hrBandLow: 45,
        hrBandHigh: 85,
        charging: true,
      );

  group('an old snapshot stops being evidence', () {
    test('the readings that go out of date are cleared', () {
      // Not wrong — old. A battery percentage from bedtime says nothing
      // about the battery at 03:00, and deciding from it is worse than
      // declining to decide.
      final unknown = snapshotAt(evening).asUnknown();
      expect(unknown.batteryPercent, isNull);
      expect(unknown.batteryReadAt, isNull);
      expect(unknown.restingHr, isNull);
      expect(unknown.spo2, isNull);
    });

    test('a frozen "charging" stops muting everything', () {
      // charging: true at bedtime stayed true all night, and the battery
      // check returns early on it — so no battery alert could ever fire.
      expect(snapshotAt(evening).charging, isTrue);
      expect(snapshotAt(evening).asUnknown().charging, isFalse);
    });

    test('a frozen "connected" stops hiding an absent ring', () {
      // This is why a ring out of range all night went unreported: the
      // offline check reads connected, and connected never moved.
      expect(snapshotAt(evening).connected, isTrue);
      expect(snapshotAt(evening).asUnknown().connected, isFalse);
    });

    test('what the ring is, rather than what it read, is kept', () {
      final unknown = snapshotAt(evening).asUnknown();
      expect(unknown.paired, isTrue);
      expect(unknown.hasRingContext, isTrue);
      expect(unknown.hrBandLow, 45);
      // Kept so the offline check can still measure from it.
      expect(unknown.lastConnectionConfirmedAt, isNotNull);
    });

    test('the threshold is longer than the heartbeat', () {
      // Otherwise an app that is awake and reporting every twenty minutes
      // would be mistaken for a suspended one.
      expect(kAlertSnapshotStaleAfter, greaterThan(const Duration(minutes: 20)));
      expect(kAlertSnapshotStaleAfter, const Duration(minutes: 30));
    });
  });

  group('nothing is said at night that cannot be acted on', () {
    test('the small hours are quiet', () {
      // The 15% alert fired 00:00-07:00: the one guaranteed to wake
      // someone, about the one thing they could do nothing about.
      for (final hour in [22, 23, 0, 3, 6]) {
        expect(
          isBatteryQuietHour(DateTime(2026, 11, 15, hour)),
          isTrue,
          reason: '$hour:00 should be quiet',
        );
      }
    });

    test('the day is not', () {
      for (final hour in [7, 12, 19, 21]) {
        expect(
          isBatteryQuietHour(DateTime(2026, 11, 15, hour)),
          isFalse,
          reason: '$hour:00 should not be quiet',
        );
      }
    });

    test('the evening check still falls outside quiet hours', () {
      // 19:00-22:00 is the one that catches a low battery while there is
      // still time to charge it, and it has to survive this.
      expect(isBatteryQuietHour(DateTime(2026, 11, 15, 19)), isFalse);
      expect(isBatteryQuietHour(DateTime(2026, 11, 15, 21, 59)), isFalse);
      expect(kBatteryQuietFromHour, 22);
      expect(kBatteryQuietToHour, 7);
    });
  });
}

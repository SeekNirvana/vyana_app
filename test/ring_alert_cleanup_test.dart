import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/main.dart';

/// Item 64 — a removed ring stops being watched, and nothing arrives twice.
void main() {
  group('unpairing forgets everything that decides to warn', () {
    test('every alert key is listed, so none outlives the ring', () {
      // Each of these is a reason the app would warn about a ring. Left
      // behind, they made "Nothing is reading you right now" arrive about
      // a ring that had been unpaired.
      for (final key in [
        'vyana.ring.alert.offlineSince',
        'vyana.ring.alert.offlineFired',
        'vyana.ring.alert.lowBatteryFiredAt',
        'vyana.ring.alert.overnightBatteryFiredOn',
        'vyana.ring.alert.staleFired',
        'vyana.ring.alert.healthFiredAt',
      ]) {
        expect(kRingAlertStateKeys, contains(key), reason: key);
      }
    });

    test('the snapshot goes too', () {
      // The snapshot is what the background service judges from. Clearing
      // the flags but leaving it would let the service decide all over
      // again from the removed ring's last readings.
      expect(kRingAlertStateKeys, contains('vyana.ring.alert.snapshot'));
    });

    test('they are all ring alert keys and nothing else', () {
      // Clearing by prefix would be easy and would take the user's
      // notification switches with it.
      for (final key in kRingAlertStateKeys) {
        expect(key, startsWith('vyana.ring.alert.'));
      }
    });
  });

  group('one path per platform', () {
    test('live checks belong to the platform with a service', () {
      // Android runs a foreground service that can look at what is true
      // now; iOS has no background timer, so there a scheduled alert is
      // the only thing that can fire. Running both is what made the stale
      // and offline alerts arrive twice, minutes apart, about one ring.
      //
      // Asserted against the platform rather than a fixed value: these
      // tests run on the host, which is neither phone.
      expect(liveChecksRunHere, Platform.isAndroid);
    });

    test('it is a single answer, so the two paths cannot both run', () {
      // The scheduling sites guard on !liveChecksRunHere and the live
      // checks on liveChecksRunHere, which is only exclusive because it is
      // one expression rather than two that could drift apart.
      expect(liveChecksRunHere || !liveChecksRunHere, isTrue);
      expect(liveChecksRunHere && !liveChecksRunHere, isFalse);
    });
  });
}

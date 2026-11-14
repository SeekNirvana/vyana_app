import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Item 84 — the parts that live on the ring controller.
///
/// The charging window, the offline cancel and the reconnect flag all sit
/// on state that needs an SDK, a paired device and a live BLE stack to
/// reach. These read the source instead, which is honest about what it
/// proves: that the call exists, not that the radio behaves.
void main() {
  String read(String path) {
    final file = File.fromUri(Directory.current.uri.resolve(path));
    if (!file.existsSync()) throw StateError('Missing $path');
    return file.readAsStringSync();
  }

  String codeOnly(String source) => source
      .split('\n')
      .map((l) {
        final at = l.indexOf('//');
        return at < 0 ? l : l.substring(0, at);
      })
      .join('\n');

  final controller = codeOnly(read('lib/src/state/ring_controller.dart'));
  final prefs = codeOnly(read('lib/src/state/notification_prefs.dart'));

  group('charging is believed for a while, not forever (bug 43)', () {
    test('the window exists and the getter uses it', () {
      // A ring on its charger drops out of range and is still off the
      // finger on purpose, so charging has to survive losing the
      // connection — but a status still reading "charging" hours later
      // muted every alert indefinitely.
      expect(prefs, contains('kChargingBelievedFor'));
      expect(controller, contains('kChargingBelievedFor'));
      expect(controller, contains('_lastConnectionConfirmedAt'));
    });

    test('a standing offline alert is withdrawn, not just left', () {
      // It used to return early, so an alert that had already fired stayed
      // on the lock screen saying nothing was reading you, while the ring
      // sat charging.
      final offline = prefs.substring(prefs.indexOf('_evaluateOffline('));
      expect(offline, contains('cancelRingOfflineAlert()'));
    });
  });

  group('the scheduled battery alert respects charging (bug 47)', () {
    test('it is cancelled while the ring is on its charger', () {
      // The declaration, not the call site above it.
      final scheduled = controller.substring(
        controller.indexOf('Future<void> _refreshScheduledBatteryAlert'),
      );
      final body = scheduled.substring(0, scheduled.indexOf('\n  }'));
      expect(body, contains('wasChargingWhenLastSeen'));
      expect(body, contains('cancelOvernightBattery()'));
    });
  });

  group('a timed-out reconnect stops saying CONNECTING (bug 48)', () {
    test('the flag can be withdrawn without the attempt finishing', () {
      expect(controller, contains('void giveUpUserReconnect()'));
      final you = codeOnly(read('lib/src/screens/you_screen.dart'));
      final feedback = you.substring(you.indexOf('reconnectWithFeedback('));
      expect(feedback, contains('giveUpUserReconnect()'));
    });
  });

  group('a failed sync stops waiting for last night (bug 36)', () {
    test('the catch evaluates the night too', () {
      // Waiting only stops when this runs, so a failed sync left "Reading
      // last night…" on Home until noon — a spinner standing in for an
      // error nobody was told about.
      final sync = controller.substring(
        controller.indexOf('Future<RingSyncFeedback?> _syncDeviceData'),
      );
      final body = sync.substring(0, sync.indexOf('\n  Future<'));
      final catchBlock = body.substring(body.indexOf('} on Object catch'));
      expect(catchBlock, contains('_evaluateTonightSleep()'));
    });
  });

  group('editing an old month leaves the latest period alone (bug 34)', () {
    test('the days are remembered, not a flag', () {
      // A flag meant editing any month confirmed the latest period, so
      // correcting a date from two years ago closed last week's run.
      final cycle = codeOnly(read('lib/src/screens/cycle_screens.dart'));
      expect(cycle, contains('_editedDays'));
      expect(cycle, isNot(contains('bool _edited =')));
      expect(cycle, contains('touchesLatest'));
    });
  });

  group('Practice shows the line Home shows (bug 45)', () {
    test('both screens render the low-readiness alternative', () {
      for (final path in [
        'lib/src/screens/home_screen.dart',
        'lib/src/screens/practice_screen.dart',
      ]) {
        expect(
          codeOnly(read(path)),
          contains('_LowReadinessAlternative(suggestion:'),
          reason: '$path does not offer the gentler option',
        );
      }
    });
  });
}

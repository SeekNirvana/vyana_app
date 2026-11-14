import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/main.dart';

/// Item 62 — telling a real change from a two-second poll.
///
/// The connection poll runs every two seconds and reached the foreground
/// service every time: check notification permission, request it if
/// denied, read whether the service is running, reset the repeat interval.
/// Four platform calls for a state that had almost never changed — and a
/// twenty-minute heartbeat whose timer was restarted before it could fire.
void main() {
  group('nothing changed means nothing to do', () {
    test('two identical intents are equal', () {
      const a = ForegroundServiceIntent(shouldRun: true, intervalMinutes: 20);
      const b = ForegroundServiceIntent(shouldRun: true, intervalMinutes: 20);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('turning the service off is a change', () {
      expect(
        const ForegroundServiceIntent(shouldRun: true, intervalMinutes: 20),
        isNot(const ForegroundServiceIntent(
            shouldRun: false, intervalMinutes: 20)),
      );
    });

    test('a new sync interval is a change', () {
      // The one case that must still reach the platform: the heartbeat
      // cadence someone chose has to be applied.
      expect(
        const ForegroundServiceIntent(shouldRun: true, intervalMinutes: 20),
        isNot(const ForegroundServiceIntent(
            shouldRun: true, intervalMinutes: 60)),
      );
    });

    test('it can be held in a set, so repeats collapse', () {
      // Built from a list so the duplicate is the thing under test
      // rather than something the analyser can object to in a literal.
      const polls = <ForegroundServiceIntent>[
        ForegroundServiceIntent(shouldRun: true, intervalMinutes: 20),
        ForegroundServiceIntent(shouldRun: true, intervalMinutes: 20),
        ForegroundServiceIntent(shouldRun: true, intervalMinutes: 60),
      ];
      expect(polls.toSet(), hasLength(2));
    });
  });
}

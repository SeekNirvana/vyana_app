import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/src/services/session_minutes.dart';

/// Items 79 and 80 — how long a session was, and which day it was on.
///
/// Four screens answered the first question four ways. The summary read the
/// live timer, which excludes pauses; everything else used
/// `endedAt - startedAt`, which does not. So a run with a ten-minute stop
/// at a crossing was ten minutes longer on three screens than in its own
/// summary, and nothing in the app could tell you which was right.
void main() {
  final started = DateTime(2026, 11, 10, 7, 30);

  String summary({int? durationSec, Map<String, Object?> extra = const {}}) =>
      jsonEncode({
        'activity': 'walk',
        if (durationSec != null) 'durationSec': durationSec,
        ...extra,
      });

  group('a pause does not become practice time', () {
    test('the recorded active seconds win over the clock', () {
      // Forty minutes on the clock, thirty of them moving.
      expect(
        sessionMinutes(
          summaryJson: summary(durationSec: 30 * 60),
          startedAt: started,
          endedAt: started.add(const Duration(minutes: 40)),
        ),
        30,
      );
    });

    test('the clock is the fallback when nothing was recorded', () {
      // A session saved before this, or recovered after a crash, has no
      // pause record to recover — the clock is all there is.
      expect(
        sessionMinutes(
          summaryJson: null,
          startedAt: started,
          endedAt: started.add(const Duration(minutes: 25)),
        ),
        25,
      );
      expect(
        sessionMinutes(
          summaryJson: summary(),
          startedAt: started,
          endedAt: started.add(const Duration(minutes: 25)),
        ),
        25,
      );
    });

    test('an unreadable summary falls back rather than reporting zero', () {
      // Returning 0 would report a real session as having taken no time.
      for (final bad in ['', 'not json', '[]', '{"durationSec":"ten"}']) {
        expect(
          sessionMinutes(
            summaryJson: bad,
            startedAt: started,
            endedAt: started.add(const Duration(minutes: 12)),
          ),
          12,
          reason: 'summary: "$bad"',
        );
      }
    });

    test('a negative duration is not trusted', () {
      expect(storedActiveSeconds(summary(durationSec: -5)), isNull);
      expect(
        sessionSeconds(
          summaryJson: null,
          startedAt: started,
          endedAt: started.subtract(const Duration(minutes: 5)),
        ),
        0,
      );
    });

    test('a session still running is zero, not negative', () {
      expect(
        sessionSeconds(summaryJson: null, startedAt: started),
        0,
      );
    });
  });

  group('a short practice is not nothing', () {
    test('fifty seconds rounds to a minute rather than truncating', () {
      // Three of these summed to "0m" before: not short, but worth nothing.
      expect(
        sessionMinutes(summaryJson: summary(durationSec: 50), startedAt: started),
        1,
      );
    });

    test('rounding is to the nearest minute, both ways', () {
      expect(
        sessionMinutes(summaryJson: summary(durationSec: 29), startedAt: started),
        0,
      );
      expect(
        sessionMinutes(summaryJson: summary(durationSec: 31), startedAt: started),
        1,
      );
      expect(
        sessionMinutes(summaryJson: summary(durationSec: 90), startedAt: started),
        2,
      );
    });

    test('a total under a minute says so', () {
      expect(minutesLabel(0, seconds: 40), 'under 1m');
      expect(minutesLabel(0, seconds: 1), 'under 1m');
    });

    test('and nothing at all is still nothing', () {
      expect(minutesLabel(0, seconds: 0), '0m');
      expect(minutesLabel(0), '0m');
    });

    test('a real total reads normally', () {
      expect(minutesLabel(32, seconds: 1900), '32m');
    });
  });

  group('a session is on the day it started', () {
    test('a session over midnight belongs to the day it began', () {
      // Grouped by finish in one place and start in another, a session begun
      // at 23:50 appeared on different days on different screens.
      final late = DateTime(2026, 11, 10, 23, 50);
      expect(sessionDay(late), DateTime(2026, 11, 10));
    });

    test('the day strips the time of day', () {
      expect(sessionDay(DateTime(2026, 11, 10, 0, 0, 1)),
          DateTime(2026, 11, 10));
      expect(sessionDay(DateTime(2026, 11, 10, 23, 59, 59)),
          DateTime(2026, 11, 10));
    });

    test('a window of seven days means the same seven everywhere', () {
      final today = DateTime(2026, 11, 10, 15, 0);
      expect(daysBack(startedAt: today, today: today, window: 7), 0);
      expect(
        daysBack(
          startedAt: today.subtract(const Duration(days: 6)),
          today: today,
          window: 7,
        ),
        6,
      );
      // Just outside.
      expect(
        daysBack(
          startedAt: today.subtract(const Duration(days: 7)),
          today: today,
          window: 7,
        ),
        isNull,
      );
      // A session later today is not "tomorrow".
      expect(
        daysBack(
          startedAt: DateTime(2026, 11, 10, 23, 30),
          today: today,
          window: 7,
        ),
        0,
      );
    });

    test('a future day is outside the window', () {
      final today = DateTime(2026, 11, 10);
      expect(
        daysBack(
          startedAt: today.add(const Duration(days: 1)),
          today: today,
          window: 7,
        ),
        isNull,
      );
    });
  });
}

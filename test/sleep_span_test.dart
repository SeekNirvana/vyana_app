import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/src/services/sleep_span.dart';

/// Item 92 — every minute of the night is one of three things.
///
/// Reported from several nights: fell asleep 00:07, woke 09:00, awake 0m,
/// sleep length 8h 05m. Those are 48 minutes apart and nothing on screen
/// accounted for them. The handover's own test case is the first group
/// below, both ways round.
void main() {
  DateTime at(int hour, int minute) => DateTime(2026, 11, 10, hour, minute);

  group("the handover's night", () {
    // 00:07 to 09:00, with one 48-minute gap the ring did not label.
    final windowStart = at(0, 7);
    final windowEnd = at(9, 0);
    final labelled = [
      SleepSpan(from: at(0, 7), to: at(3, 12)),
      SleepSpan(from: at(4, 0), to: at(9, 0)),
    ];

    test('a gap with heart rate is sleep, so the night is 8h 53m', () {
      final split = splitSleepGaps(
        windowStart: windowStart,
        windowEnd: windowEnd,
        labelled: labelled,
        measuring: (_, __) => true,
      );
      expect(split.unstagedSeconds, 48 * 60);
      expect(split.notRecordedSeconds, 0);
      expect(split.notRecorded, isEmpty);
      // 8h 53m total, of which 48m is now unstaged sleep rather than lost.
      final staged = 3 * 3600 + 5 * 60 + 5 * 3600;
      expect(staged + split.unstagedSeconds, 8 * 3600 + 53 * 60);
    });

    test('the same gap with no readings is not counted, and is named', () {
      final split = splitSleepGaps(
        windowStart: windowStart,
        windowEnd: windowEnd,
        labelled: labelled,
        measuring: (_, __) => false,
      );
      expect(split.unstagedSeconds, 0);
      expect(split.notRecordedSeconds, 48 * 60);
      expect(split.notRecorded.single.from, at(3, 12));
      expect(split.notRecorded.single.to, at(4, 0));
      expect(notRecordedLabel(split.notRecordedSeconds), 'Not recorded · 48m');
    });
  });

  group('a gap is split where the readings stop', () {
    test('half measured, half not', () {
      // The ring stopped at 03:30 and came back at 04:00 — the first part
      // of the gap is sleep, the rest is not.
      final split = splitSleepGaps(
        windowStart: at(0, 0),
        windowEnd: at(5, 0),
        labelled: [
          SleepSpan(from: at(0, 0), to: at(3, 0)),
          SleepSpan(from: at(4, 0), to: at(5, 0)),
        ],
        measuring: (from, to) => from.isBefore(at(3, 30)),
      );
      expect(split.unstagedSeconds, 30 * 60);
      expect(split.notRecordedSeconds, 30 * 60);
      expect(split.notRecorded.single.from, at(3, 30));
      expect(split.notRecorded.single.to, at(4, 0));
    });

    test('two separate stretches are reported separately', () {
      final split = splitSleepGaps(
        windowStart: at(0, 0),
        windowEnd: at(6, 0),
        labelled: [
          SleepSpan(from: at(0, 0), to: at(1, 0)),
          SleepSpan(from: at(2, 0), to: at(3, 0)),
          SleepSpan(from: at(4, 0), to: at(6, 0)),
        ],
        measuring: (_, __) => false,
      );
      expect(split.notRecorded.length, 2);
      expect(split.notRecordedSeconds, 2 * 3600);
    });
  });

  group('a night the ring covered entirely has nothing to account for', () {
    test('no gaps, no unstaged, no not-recorded', () {
      final split = splitSleepGaps(
        windowStart: at(23, 0),
        windowEnd: at(23, 0).add(const Duration(hours: 8)),
        labelled: [
          SleepSpan(
            from: at(23, 0),
            to: at(23, 0).add(const Duration(hours: 8)),
          ),
        ],
        measuring: (_, __) => true,
      );
      expect(split.isEmpty, isTrue);
    });

    test('overlapping records do not invent a gap', () {
      // Sessions can overlap; merging them must not leave slivers.
      final split = splitSleepGaps(
        windowStart: at(0, 0),
        windowEnd: at(4, 0),
        labelled: [
          SleepSpan(from: at(0, 0), to: at(2, 30)),
          SleepSpan(from: at(2, 0), to: at(4, 0)),
        ],
        measuring: (_, __) => false,
      );
      expect(split.isEmpty, isTrue);
    });

    test('a record reaching past the night is clipped, not negative', () {
      final split = splitSleepGaps(
        windowStart: at(1, 0),
        windowEnd: at(3, 0),
        labelled: [SleepSpan(from: at(0, 0), to: at(5, 0))],
        measuring: (_, __) => false,
      );
      expect(split.isEmpty, isTrue);
    });
  });

  group('nothing is reported for a night that is not one', () {
    test('an empty or backwards window gives nothing', () {
      for (final pair in [
        (at(2, 0), at(2, 0)),
        (at(3, 0), at(1, 0)),
      ]) {
        final split = splitSleepGaps(
          windowStart: pair.$1,
          windowEnd: pair.$2,
          labelled: const [],
          measuring: (_, __) => false,
        );
        expect(split.isEmpty, isTrue);
      }
    });

    test('a night with no records at all is all unaccounted for', () {
      // Which is correct: if the ring labelled nothing and measured
      // nothing, there is no sleep to claim.
      final split = splitSleepGaps(
        windowStart: at(0, 0),
        windowEnd: at(2, 0),
        labelled: const [],
        measuring: (_, __) => false,
      );
      expect(split.notRecordedSeconds, 2 * 3600);
      expect(split.unstagedSeconds, 0);
    });
  });

  group('the label reads as a duration', () {
    test('minutes, hours, and both', () {
      expect(notRecordedLabel(40 * 60), 'Not recorded · 40m');
      expect(notRecordedLabel(60 * 60), 'Not recorded · 1h');
      expect(notRecordedLabel(95 * 60), 'Not recorded · 1h 35m');
    });
  });
}

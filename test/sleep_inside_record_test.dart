import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/main.dart';
import 'package:vyana/src/services/sleep_span.dart';

/// Item 105 — sleep minutes inside a record are counted too.
void main() {
  DateTime at(int hour, int minute) => DateTime(2026, 11, 10, hour, minute);

  test("the handover's night: 48 unlabelled minutes inside one record", () {
    // One record, 00:07–09:00, whose stages add up to 8h 05m. Heart rate
    // all night, so nothing is "not recorded".
    const staged = 8 * 3600 + 5 * 60;
    final unlabelled = unlabelledSleepSeconds(
      spanSeconds: at(9, 0).difference(at(0, 7)).inSeconds,
      stagedSeconds: staged,
      awakeSeconds: 0,
      notRecordedSeconds: 0,
    );
    expect(unlabelled, 48 * 60);
    expect(staged + unlabelled, 8 * 3600 + 53 * 60);
  });

  test('awake and not-recorded minutes are not sleep', () {
    expect(
      unlabelledSleepSeconds(
        spanSeconds: 9 * 3600,
        stagedSeconds: 7 * 3600,
        awakeSeconds: 20 * 60,
        notRecordedSeconds: 40 * 60,
      ),
      60 * 60,
    );
  });

  test('overlapping records never make it negative', () {
    expect(
      unlabelledSleepSeconds(
        spanSeconds: 3600,
        stagedSeconds: 4000,
        awakeSeconds: 0,
        notRecordedSeconds: 0,
      ),
      0,
    );
  });

  test('the chart finds the unstaged stretches, not the gaps', () {
    final spans = unlabelledSleepSpans(
      windowStart: at(0, 7),
      windowEnd: at(9, 0),
      labelled: [
        SleepSpan(from: at(0, 7), to: at(3, 12)),
        SleepSpan(from: at(4, 0), to: at(8, 0)),
      ],
      notRecorded: [SleepGap(from: at(8, 30), to: at(9, 0))],
    );
    expect(spans.length, 2);
    expect(spans[0].from, at(3, 12));
    expect(spans[0].to, at(4, 0));
    expect(spans[1].from, at(8, 0));
    expect(spans[1].to, at(8, 30));
  });

  test('stage shares are of staged sleep, not unstaged', () {
    // 6h staged with ideal deep (18%) and REM (22%) shares, plus 2h the
    // ring did not stage. The shares must not be diluted by those 2h.
    const stagedSeconds = 6 * 3600;
    final withUnstaged = SleepStageBreakdown(
      deepSeconds: (stagedSeconds * 0.18).round(),
      remSeconds: (stagedSeconds * 0.22).round(),
      lightSeconds: (stagedSeconds * 0.60).round(),
      awakeSeconds: 0,
      segmentCount: 3,
      unstagedSeconds: 2 * 3600,
    );
    final stagedOnly = SleepStageBreakdown(
      deepSeconds: (8 * 3600 * 0.18).round(),
      remSeconds: (8 * 3600 * 0.22).round(),
      lightSeconds: (8 * 3600 * 0.60).round(),
      awakeSeconds: 0,
      segmentCount: 3,
    );
    // Same length, same shares of what was staged: the same score.
    expect(
      sleepScoreForBreakdown(withUnstaged),
      sleepScoreForBreakdown(stagedOnly),
    );
  });
}

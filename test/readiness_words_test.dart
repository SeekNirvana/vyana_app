import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/src/wellness/wellness_state.dart';

/// Item 74 — one set of readiness words, wherever they are said.
///
/// The app said Ready / Balanced / Depleted at 70 and 50. The notification
/// and the home-screen widget said Primed / Steady / Settled / Recovering
/// at 80, 65 and 50. A 68 was therefore "Balanced" on the screen and
/// "Steady" in the notification about the same reading, and nothing told
/// you which was meant.
void main() {
  group('the cut-offs are the app\'s', () {
    test('68 is Balanced, which is what the screen says', () {
      // The number from the report.
      expect(readinessStateWord(68), 'Balanced');
      expect(readinessTone(68), WellnessTone.steady);
    });

    test('the boundaries fall where the ring draws them', () {
      expect(readinessStateWord(70), 'Ready');
      expect(readinessStateWord(69), 'Balanced');
      expect(readinessStateWord(50), 'Balanced');
      expect(readinessStateWord(49), 'Depleted');
    });

    test('the old words are gone', () {
      for (final score in [0, 25, 49, 50, 64, 65, 68, 69, 70, 79, 80, 100]) {
        final word = readinessStateWord(score);
        expect(
          word,
          anyOf('Ready', 'Balanced', 'Depleted'),
          reason: '$score produced "$word"',
        );
      }
    });

    test('the word and the colour agree at every score', () {
      // They were computed from different cut-offs, so a score could be
      // worded one band and coloured another.
      for (var score = 0; score <= 100; score++) {
        final word = readinessStateWord(score);
        final tone = readinessTone(score);
        expect(
          tone,
          switch (word) {
            'Ready' => WellnessTone.good,
            'Balanced' => WellnessTone.steady,
            _ => WellnessTone.watch,
          },
          reason: '$score: "$word" with $tone',
        );
      }
    });
  });

  group('half a reading earns no verdict', () {
    test('an HRV-only score is a partial read, not a band', () {
      // Bug 36: "Depleted" must never come from a missing night.
      for (final score in [20, 49, 55, 85]) {
        expect(readinessStateWord(score, hrvOnly: true), 'Partial read');
        expect(readinessTone(score, hrvOnly: true), WellnessTone.unknown);
      }
    });

    test('no score at all says so', () {
      expect(readinessStateWord(null), 'No read yet');
      expect(readinessTone(null), WellnessTone.unknown);
      expect(readinessSummary(null), contains('Sync your ring'));
    });

    test('the partial-read sentence says what is missing', () {
      // "Partial read" on its own invites the question this answers.
      expect(readinessSummary(60, hrvOnly: true), contains('HRV'));
      expect(readinessSummary(60, hrvOnly: true), contains('missing'));
    });
  });

  group('the sentence matches the word', () {
    test('each band gets its own, and never another band\'s', () {
      expect(readinessSummary(85), contains('ready for the day'));
      expect(readinessSummary(60), contains('balanced'));
      expect(readinessSummary(30), contains('rest'));
      // The depleted sentence must not turn up on a Ready score.
      expect(readinessSummary(85), isNot(contains('rest')));
    });

    test('every score has something to say', () {
      for (var score = 0; score <= 100; score++) {
        expect(readinessSummary(score), isNotEmpty);
        expect(readinessSummary(score), endsWith('.'));
      }
    });
  });

  group('the notification and the widget read the same thing', () {
    test('a readiness score drives the title the screen would show', () {
      // Both surfaces take WellnessState.title, so this is the one place
      // where their words are decided.
      final state = WellnessState.from(readinessScore: 68, heartRate: 60);
      expect(state.title, 'Balanced');
      expect(state.title, readinessStateWord(68));
      expect(state.tone, readinessTone(68));
    });

    test('an HRV-only score reaches them as a partial read', () {
      final state = WellnessState.from(
        readinessScore: 45,
        heartRate: 60,
        readinessIsHrvOnly: true,
      );
      expect(state.title, 'Partial read');
      // The point of passing the flag through: "Depleted" in a notification
      // from a night that was never recorded is the worst version of this.
      expect(state.title, isNot('Depleted'));
    });

    test('a 68 and an 80 are no longer the same word', () {
      // They both read "Steady"/"Primed" under the old bands; what matters
      // is that each now matches its own screen.
      expect(
        WellnessState.from(readinessScore: 68, heartRate: 60).title,
        'Balanced',
      );
      expect(
        WellnessState.from(readinessScore: 80, heartRate: 60).title,
        'Ready',
      );
    });
  });

  group('item 112: the same words on all three', () {
    test('no score is "No read yet", not a verdict from live signals', () {
      final state = WellnessState.from(heartRate: 60, hrv: 70);
      expect(state.title, 'No read yet');
      expect(state.title, isNot(anyOf('Steady & bright', 'Running low')));
      expect(wellnessResultSentence(state), startsWith('No read yet — '));
    });

    test('an HRV-only score is its own sentence', () {
      final state = WellnessState.from(
        readinessScore: 45,
        hrv: 40,
        readinessIsHrvOnly: true,
      );
      expect(wellnessResultSentence(state), 'Partial read: sleep not recorded.');
      expect(wellnessResultSentence(state), isNot(contains('feeling partial')));
    });

    test('Recovery says Steady, never the readiness word Balanced', () {
      final state = WellnessState.from(readinessScore: 80, hrv: 45);
      final recovery = state.signals.firstWhere((s) => s.label == 'Recovery');
      expect(recovery.reading, 'Steady');
    });

    test('one full stop at the end, whatever the line ends with', () {
      final state = WellnessState.from(readinessScore: 80);
      expect(wellnessResultSentence(state), isNot(contains('..')));
    });
  });
}

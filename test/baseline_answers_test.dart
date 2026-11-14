import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/main.dart';

/// Item 95 — "Your normal" asked about questions it had never put.
///
/// Reported after a reinstall with no history: the screen listed Sleep,
/// Resting HR and HRV, each with three options, no values, and nothing to
/// say what the screen was or what would be agreed to. The sheet is only
/// meant for changing an answer already given to the Metrics question.
void main() {
  group('the answers say what they do', () {
    test('each one names its consequence', () {
      // "It is a real signal" did not say what it does — nobody reading it
      // could tell what they were choosing.
      expect(BaselineAnswer.adopted.label, 'This is normal for me');
      expect(BaselineAnswer.kept.label, 'Keep flagging it');
      expect(BaselineAnswer.deferred.label, 'Ask me later');
    });

    test('the old wording is gone from the app', () {
      final source = Directory.fromUri(
        Directory.current.uri.resolve('lib/'),
      )
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => f.readAsStringSync())
          .map((s) => s
              .split('\n')
              .map((l) {
                final at = l.indexOf('//');
                return at < 0 ? l : l.substring(0, at);
              })
              .join('\n'))
          .join('\n');
      expect(source, isNot(contains('It is a real signal')));
      expect(source, isNot(contains('This is my normal')));
    });

    test('an unasked vital is still told apart from an answered one', () {
      // The sheet shows choices only where the answer is not `none`, so
      // this distinction is what keeps unasked vitals off it.
      expect(BaselineAnswer.none.label, 'Not asked yet');
      for (final answer in BaselineAnswer.values) {
        expect(answer.label, isNotEmpty);
      }
    });
  });

  group('each vital knows what it is judged against', () {
    test('a typical band and a unit, so the numbers can be shown', () {
      expect(BaselineVital.hrv.typicalRangeFor(null).low, greaterThan(0));
      expect(BaselineVital.hrv.unit, 'ms');
      expect(BaselineVital.restingHr.unit, 'bpm');
      expect(BaselineVital.sleep.unit, 'h');
    });

    test("resting HR's band follows how often the person trains", () {
      // It is the one band that is not the same for everybody, which is why
      // it is asked for rather than constant.
      final athlete =
          BaselineVital.restingHr.typicalRangeFor(TrainingFrequency.mostDays);
      final rarely =
          BaselineVital.restingHr.typicalRangeFor(TrainingFrequency.rarely);
      expect(athlete.low, isNot(rarely.low));
    });
  });

  group('the sheet only offers what was asked', () {
    final sheet = File.fromUri(
      Directory.current.uri.resolve('lib/src/screens/baseline_blocks.dart'),
    ).readAsStringSync();

    test('it says what the screen is, before any choices', () {
      expect(sheet, contains('Vyana learns your usual sleep'));
    });

    test('while learning it shows only how far along it is', () {
      expect(sheet, contains('Learning your normal · day'));
      expect(sheet, contains('baselines.learningDay case final day?'));
    });

    test('a vital Metrics never asked about has nothing to decide', () {
      // The branch that keeps an unasked vital off the list of choices.
      expect(sheet, contains('BaselineAnswer.none'));
      expect(sheet, contains('nothing'));
      expect(sheet, contains('to decide'));
    });

    test('and an answered one shows its numbers', () {
      expect(sheet, contains('_baselineNumbersLine'));
      expect(sheet, contains('Yours about'));
      expect(sheet, contains('typical'));
    });
  });
}

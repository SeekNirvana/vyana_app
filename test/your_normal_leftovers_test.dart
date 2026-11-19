import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/main.dart';

/// Item 113 — "Your normal" leftovers.
void main() {
  test('Metrics asks with the same three answers as Your normal', () {
    for (final vital in BaselineVital.values) {
      final q = baselineQuestionFor(vital, atypicalDays: 9, windowDays: 14);
      expect(
        [for (final (label, _) in q.options) label],
        ['This is normal for me', 'Keep flagging it', 'Ask me later'],
      );
      expect(
        [for (final (_, answer) in q.options) answer],
        [BaselineAnswer.adopted, BaselineAnswer.kept, BaselineAnswer.deferred],
      );
      for (final (label, answer) in q.options) {
        expect(label, answer.label);
      }
    }
  });

  test('an unasked vital in range says so', () {
    expect(
      unaskedBaselineLine(
        label: 'HRV',
        yours: 60,
        low: 21,
        high: 90,
        numbers: 'Yours about 60 ms, typical 21–90 ms',
      ),
      'HRV · within the typical range, nothing to decide.',
    );
  });

  test('out of range and not asked yet: only its numbers', () {
    final line = unaskedBaselineLine(
      label: 'HRV',
      yours: 15,
      low: 21,
      high: 90,
      numbers: 'Yours about 15 ms, typical 21–90 ms',
    );
    expect(line, 'HRV · Yours about 15 ms, typical 21–90 ms');
    expect(line, isNot(contains('within the typical range')));
  });

  test('no readings yet says that, not a verdict', () {
    expect(
      unaskedBaselineLine(
        label: 'Sleep',
        yours: null,
        low: 7,
        high: 9,
        numbers: null,
      ),
      'Sleep · not enough readings yet.',
    );
  });
}

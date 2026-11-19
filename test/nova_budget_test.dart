import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/src/services/guide_persona_prefs_service.dart';
import 'package:vyana/src/services/nova_budget.dart';

/// Item 70 — Nova's token budget, and the dates she is given.
///
/// The false date matches are the reason this file exists. Each one is a
/// sentence someone would plainly type, which Nova answered by looking up
/// an unrelated day and saying nothing about having done so.
void main() {
  // A Tuesday, so "most recent Saturday" is three days back and unambiguous.
  final now = DateTime(2026, 11, 10, 15, 20);

  group('an ordinary word is not a date', () {
    test('"I sat" is not Saturday', () {
      // The reported fault: \bsat\b.
      expect(novaLookupRangeFor('I sat down and felt dizzy', now: now), isNull);
      expect(novaLookupRangeFor('we sat through dinner', now: now), isNull);
    });

    test('"the sun" is not Sunday', () {
      expect(novaLookupRangeFor('the sun was too bright', now: now), isNull);
      expect(novaLookupRangeFor('I was out in the sun', now: now), isNull);
    });

    test('"2 decaf" is not 2 December', () {
      // The month pattern allowed any suffix, so dec matched decaf and Nova
      // answered about a day in winter.
      final range = novaLookupRangeFor('I had 2 decaf coffees', now: now);
      expect(range, isNull);
    });

    test('a month name inside a longer word is not a month', () {
      for (final text in [
        'the janitor came',
        'I saw a 3 marginal reading',
        'augmented my routine',
        '4 maybe 5 hours',
        'decaf after 6',
      ]) {
        expect(novaLookupRangeFor(text, now: now), isNull, reason: text);
      }
    });

    test('"wed" alone is not Wednesday', () {
      expect(novaLookupRangeFor('they wed last year', now: now), isNull);
    });
  });

  group('a date phrase is a date', () {
    test('an abbreviation with a date word around it counts', () {
      for (final text in [
        'how did I sleep on sat',
        'what about last sat',
        'sat night was rough',
        "sat's sleep score",
      ]) {
        final range = novaLookupRangeFor(text, now: now);
        expect(range, isNotNull, reason: text);
        expect(range!.label, 'Sat', reason: text);
        // The most recent Saturday before a Tuesday is three days back.
        expect(range.from, DateTime(2026, 11, 7), reason: text);
        expect(range.days, 1, reason: text);
      }
    });

    test('a full weekday name needs no help', () {
      final range = novaLookupRangeFor('saturday felt awful', now: now);
      expect(range, isNotNull);
      expect(range!.from, DateTime(2026, 11, 7));
    });

    test('a written date is read either way round', () {
      for (final text in ['how was 3 nov', 'how was nov 3', 'november 3']) {
        final range = novaLookupRangeFor(text, now: now);
        expect(range, isNotNull, reason: text);
        expect(range!.from, DateTime(2026, 11, 3), reason: text);
      }
    });

    test('a date still to come is read as last year', () {
      final range = novaLookupRangeFor('how was 25 dec', now: now);
      expect(range, isNotNull);
      expect(range!.from.year, 2025);
      expect(range.from.month, 12);
    });

    test('the named ranges are unchanged', () {
      expect(novaLookupRangeFor('last week', now: now)!.label, 'last week');
      expect(
        novaLookupRangeFor('how was this week', now: now)!.label,
        'last 7 days',
      );
      expect(novaLookupRangeFor('yesterday', now: now)!.days, 1);
      expect(
        novaLookupRangeFor('my hrv trend', now: now)!.label,
        'last 7 days',
      );
    });

    test('a question about now asks for no lookup', () {
      for (final text in [
        'how am I doing',
        'what should I do today',
        'is my hrv ok',
      ]) {
        expect(novaLookupRangeFor(text, now: now), isNull, reason: text);
      }
    });
  });

  group('a lookup fits the window', () {
    NovaDay day(int d) => NovaDay(
          day: DateTime(2026, 11, d),
          sleepSeconds: 7 * 3600,
          sleepScore: 70,
          readiness: 68,
          hrv: 48,
          restingHr: 57,
        );

    test('a few full days are listed', () {
      final block = formatNovaLookup([for (var d = 1; d <= 3; d++) day(d)],
          label: '3 days');
      expect(block.split('\n').length, 4);
      expect(estimateNovaTokens(block), lessThanOrEqualTo(kNovaLookupTokenCap));
    });

    test('a week of full days is summarised, not listed', () {
      // Seven lines of every field is what used to go out at 200+ tokens —
      // on iOS that alone could fill the window before the reply started.
      final block = formatNovaLookup([for (var d = 1; d <= 7; d++) day(d)],
          label: 'last 7 days');
      expect(block.split('\n').length, 2);
      expect(block, contains('7 days'));
      expect(block, contains('average score'));
    });

    test('no block ever exceeds the cap', () {
      for (final count in [1, 2, 5, 6, 10, 30, 90]) {
        final block = formatNovaLookup(
          [for (var d = 1; d <= count; d++) day(((d - 1) % 28) + 1)],
          label: '$count days',
        );
        expect(
          estimateNovaTokens(block),
          lessThanOrEqualTo(kNovaLookupTokenCap),
          reason: '$count days came to ${estimateNovaTokens(block)} tokens',
        );
      }
    });
  });

  group('a range with nothing in it says so', () {
    test('empty days are reported, not silently dropped', () {
      // Returning nothing left Nova answering as though the days had been
      // ordinary. This is the difference between "your ring was off" and an
      // invented quiet week.
      final block = formatNovaLookup(const [], label: 'last week');
      expect(block, isNotEmpty);
      expect(block, contains('last week'));
      expect(block, contains('no data'));
    });

    test('days present but all blank are reported the same way', () {
      final blank = [
        for (var d = 1; d <= 7; d++) NovaDay(day: DateTime(2026, 11, d)),
      ];
      final block = formatNovaLookup(blank, label: 'last 7 days');
      expect(block, contains('no data'));
      // One line, not seven of "no data".
      expect(block.split('\n').length, 2);
    });

    test('one day with only a score still counts as data', () {
      // A first version of hasNumbers looked only at the measured values,
      // so a day holding nothing but a sleep score was called empty.
      final block = formatNovaLookup(
        [NovaDay(day: DateTime(2026, 11, 9), sleepScore: 78)],
        label: 'Mon',
      );
      expect(block, contains('score 78'));
      expect(block, isNot(contains('no data recorded')));
    });
  });

  group('the data block is sent once a session', () {
    const block = 'DATA\nreadiness 62';

    test('the first message carries it', () {
      expect(
        novaDataNeedsSending(
          block: block,
          lastSent: null,
          sessionRemembers: true,
        ),
        isTrue,
      );
    });

    test('the second does not, while the numbers are the same', () {
      expect(
        novaDataNeedsSending(
          block: block,
          lastSent: block,
          sessionRemembers: true,
        ),
        isFalse,
      );
    });

    test('a change sends it again', () {
      expect(
        novaDataNeedsSending(
          block: 'DATA\nreadiness 71',
          lastSent: block,
          sessionRemembers: true,
        ),
        isTrue,
      );
    });

    test('an endpoint gets it every time', () {
      // An HTTP request carries its whole context and remembers nothing, so
      // skipping it there would leave Nova with no numbers at all.
      expect(
        novaDataNeedsSending(
          block: block,
          lastSent: block,
          sessionRemembers: false,
        ),
        isTrue,
      );
    });

    test('an empty block is never sent', () {
      for (final empty in ['', '   ', '\n']) {
        expect(
          novaDataNeedsSending(
            block: empty,
            lastSent: null,
            sessionRemembers: true,
          ),
          isFalse,
        );
      }
    });
  });

  group('the question comes first', () {
    test('so that an overflow loses the data, not what was asked', () {
      final composed = composeNovaPrompt(
        message: 'how did I sleep?',
        dataBlock: 'DATA\nx',
        lookupBlock: 'LOOKUP (Sat)\ny',
      );
      expect(composed.indexOf('how did I sleep?'), 0);
      expect(composed.indexOf('DATA'), lessThan(composed.indexOf('LOOKUP')));
    });

    test('blank blocks leave no empty gaps', () {
      expect(
        composeNovaPrompt(message: 'hello', dataBlock: '  ', lookupBlock: ''),
        'hello',
      );
    });
  });

  group('what the person was actually alerted about', () {
    test('a recent alert is named with its age', () {
      final concerns = recentAlertConcerns(
        now: now,
        healthFiredAt: now.subtract(const Duration(days: 2)),
      );
      expect(concerns, ['health alert sent 2 days ago']);
    });

    test('an old alert is not', () {
      expect(
        recentAlertConcerns(
          now: now,
          healthFiredAt: now.subtract(const Duration(days: 9)),
        ),
        isEmpty,
      );
    });

    test('a stamp in the future is ignored rather than trusted', () {
      // A clock change should not produce "health alert sent in -3 days".
      expect(
        recentAlertConcerns(
          now: now,
          healthFiredAt: now.add(const Duration(days: 3)),
        ),
        isEmpty,
      );
    });

    test('nothing stored means nothing claimed', () {
      expect(recentAlertConcerns(now: now), isEmpty);
    });

    test('today reads as today', () {
      final concerns = recentAlertConcerns(
        now: now,
        lowBatteryFiredAt: now.subtract(const Duration(hours: 2)),
      );
      expect(concerns, ['low battery alert sent today']);
    });
  });

  group('the response length shortens the reply, not the memory', () {
    test('the context window is the same whatever the setting', () {
      // The fault: "Short" halved the window to 256 on iOS, so instructions,
      // data, question and answer had to share it and every message was
      // over budget before being sent.
      for (final lowRam in [true, false]) {
        final window = GuidePersonaPrefsService.contextTokensFor(lowRam: lowRam);
        for (final length in GuideResponseLength.values) {
          expect(GuidePersonaPrefsService.replyTokensFor(length), lessThan(window + 1));
        }
        expect(window, anyOf(1024, 2048));
      }
    });

    test('a shorter setting asks for a shorter reply', () {
      expect(
        GuidePersonaPrefsService.replyTokensFor(GuideResponseLength.short),
        lessThan(GuidePersonaPrefsService.replyTokensFor(GuideResponseLength.balanced)),
      );
      expect(
        GuidePersonaPrefsService.replyTokensFor(GuideResponseLength.balanced),
        lessThan(GuidePersonaPrefsService.replyTokensFor(GuideResponseLength.detailed)),
      );
    });

    test('and says so in words, since the runtime takes no reply cap', () {
      expect(
        replyLengthInstruction(GuideResponseLength.short),
        contains('two or three sentences'),
      );
      for (final length in GuideResponseLength.values) {
        expect(replyLengthInstruction(length), isNotEmpty);
        // Cheap enough to be worth it against a 256-token window.
        expect(estimateNovaTokens(replyLengthInstruction(length)),
            lessThan(25));
      }
    });
  });
}

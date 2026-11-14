import 'package:flutter_test/flutter_test.dart';
import 'package:vyana/src/services/spoken_text.dart';

void main() {
  group('numbers are said, not skipped', () {
    // The bug this exists for: Kokoro's lexicon has no entry for any digit,
    // and a word it cannot find is dropped in silence rather than
    // mispronounced. Every one of these read as a sentence with a hole in it.
    test('the cues that lost their only content', () {
      expect(speakableText('Halfway. 5 minutes.'), 'Halfway. five minutes.');
      expect(
        speakableText('Your HRV is 48 milliseconds.'),
        'Your HRV is forty eight milliseconds.',
      );
      expect(
        speakableText('Resting heart rate 54 BPM.'),
        'Resting heart rate fifty four BPM.',
      );
    });

    test('tens, teens and the ones that sound alike', () {
      expect(spokenNumbers('13'), 'thirteen');
      expect(spokenNumbers('30'), 'thirty');
      expect(spokenNumbers('19'), 'nineteen');
      expect(spokenNumbers('90'), 'ninety');
      expect(spokenNumbers('0'), 'zero');
    });

    test('hundreds and thousands, as a person would read them', () {
      expect(spokenNumbers('206'), 'two hundred and six');
      expect(spokenNumbers('200'), 'two hundred');
      expect(spokenNumbers('1200'), 'one thousand two hundred');
      expect(spokenNumbers('1005'), 'one thousand and five');
      // A step count, with the separator the UI writes it with.
      expect(spokenNumbers('12,480'), 'twelve thousand four hundred and eighty');
    });

    test('decimals are read digit by digit after the point', () {
      // "point seventy" is a different number from "point seven zero" to
      // everyone except a computer.
      expect(spokenNumbers('36.7'), 'thirty six point seven');
      expect(spokenNumbers('2.50'), 'two point five zero');
      expect(spokenNumbers('0.5'), 'zero point five');
    });

    test('a full stop that ends a sentence is not a decimal point', () {
      expect(
        speakableText('You walked 3 kilometres. Well done.'),
        'You walked three kilometres. Well done.',
      );
    });

    test('a per-cent sign is a word, not a symbol to drop', () {
      expect(
        speakableText('Readiness 72%.'),
        'Readiness seventy two percent.',
      );
    });

    test('negatives say so', () {
      expect(numberToWords(-4), 'minus four');
    });

    test('text with no numbers is left exactly as it is', () {
      const line = 'Settle into savasana and let your breath lengthen.';
      expect(speakableText(line), line);
    });

    test('several numbers in one line all survive', () {
      expect(
        speakableText('HRV 48 ms, resting 54 BPM, sleep 7.5 hours.'),
        'HRV forty eight ms, resting fifty four BPM, '
            'sleep seven point five hours.',
      );
    });
  });
}

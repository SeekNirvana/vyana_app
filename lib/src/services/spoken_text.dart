/// Turning what is on screen into something Kokoro can actually say.
///
/// Kokoro is driven by a lexicon of words, and the lexicon has no entry for
/// any digit — not one. A word it cannot find is not guessed at or
/// mispronounced, it is *skipped*, and the sentence closes over the gap. So
/// "Your HRV is 48 milliseconds" was spoken as "Your HRV is milliseconds",
/// and "Halfway. 5 minutes." as "Halfway. minutes." — a guidance cue whose
/// only real content is the number, with the number removed, and nothing
/// anywhere reporting a problem.
///
/// This is the last thing done to a string before it reaches the voice. The
/// screen keeps the digits; only speech gets the words.
library;

const List<String> _ones = [
  'zero',
  'one',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
  'eight',
  'nine',
  'ten',
  'eleven',
  'twelve',
  'thirteen',
  'fourteen',
  'fifteen',
  'sixteen',
  'seventeen',
  'eighteen',
  'nineteen',
];

const List<String> _tens = [
  '',
  '',
  'twenty',
  'thirty',
  'forty',
  'fifty',
  'sixty',
  'seventy',
  'eighty',
  'ninety',
];

/// Up to three digits — "two hundred and six".
String _underThousand(int n) {
  if (n < 20) return _ones[n];
  if (n < 100) {
    final rest = n % 10;
    return rest == 0 ? _tens[n ~/ 10] : '${_tens[n ~/ 10]} ${_ones[rest]}';
  }
  final rest = n % 100;
  final hundreds = '${_ones[n ~/ 100]} hundred';
  return rest == 0 ? hundreds : '$hundreds and ${_underThousand(rest)}';
}

/// A whole number as it would be read aloud.
///
/// Stops at billions, which is well past any figure this app holds — a step
/// count, a heart rate, a number of milliseconds.
String numberToWords(int n) {
  if (n < 0) return 'minus ${numberToWords(-n)}';
  if (n < 1000) return _underThousand(n);

  final parts = <String>[];
  for (final scale in const [
    (1000000000, 'billion'),
    (1000000, 'million'),
    (1000, 'thousand'),
  ]) {
    final count = n ~/ scale.$1;
    if (count > 0) {
      parts.add('${_underThousand(count)} ${scale.$2}');
      n %= scale.$1;
    }
  }
  if (n > 0) {
    // "one thousand and five", but "one thousand two hundred".
    parts.add(n < 100 ? 'and ${_underThousand(n)}' : _underThousand(n));
  }
  return parts.join(' ');
}

/// Matches a number: optional thousands separators, optional decimal part.
/// The decimal point must be followed by a digit, so a full stop at the end
/// of a sentence is never mistaken for one.
final RegExp _number = RegExp(r'\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?');

/// Rewrites every number in [text] as the words for it.
///
/// Decimals are read the way people say them — "thirty six point seven", one
/// digit at a time after the point, because "point seventy" is a different
/// number from "point seven zero" to everyone except a computer.
String spokenNumbers(String text) {
  return text.replaceAllMapped(_number, (match) {
    final raw = match[0]!.replaceAll(',', '');
    final dot = raw.indexOf('.');
    if (dot < 0) {
      final value = int.tryParse(raw);
      return value == null ? raw : numberToWords(value);
    }
    final whole = int.tryParse(raw.substring(0, dot));
    if (whole == null) return raw;
    final decimals =
        raw.substring(dot + 1).split('').map((d) => _ones[int.parse(d)]);
    return '${numberToWords(whole)} point ${decimals.join(' ')}';
  });
}

/// Everything that has to happen to a line before it is spoken.
///
/// One function, called in one place — [NovaVoiceService.speak] — so a cue, a
/// preview and a streamed reply cannot drift apart in how they sound.
String speakableText(String text) {
  // "48%" would otherwise read as "forty eight", with the sign dropped in
  // silence like the digits were.
  final withPercent = text.replaceAll('%', ' percent');
  return spokenNumbers(withPercent)
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .trim();
}

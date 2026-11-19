/// Item 70 — how much Nova is told, and when.
///
/// Item 51 gave Nova the user's own numbers. This is the arithmetic of
/// fitting them in. The context window is small — 2,048 tokens, 1,024 on a
/// low-memory phone (item 124) — and it is shared by the instructions, the DATA block, the
/// LOOKUP block, the whole conversation so far and the reply. Overflow is
/// not a clean failure: the model either errors or silently drops the
/// oldest part of the window, which is the question.
///
/// It lives in its own library rather than in `nova_context.dart`, which is
/// a `part of main.dart`: this is arithmetic and text matching with no
/// providers in it, and a test can take it on its own instead of loading
/// the whole app. The faults it fixes are the kind only a test finds.
/// `\bsat\b` matched "I sat". `\bsun\b` matched "the sun". The month pattern
/// allowed any suffix, so "2 decaf" read as 2 December and Nova answered
/// about a day in winter.
///
/// So the rule throughout: a word is a date only inside a date phrase, and
/// when in doubt nothing is added. A silent wrong date is worse than no
/// lookup, because the person cannot see what Nova was handed.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Target size of the DATA block. Short fields, not sentences.
const int kNovaDataTargetTokens = 150;

/// The most a LOOKUP block may cost before it becomes a summary.
///
/// Item 70: there was only a day cap of ten, and ten day lines run to
/// 200–280 tokens — on iOS that alone could pass the whole window before
/// the reply was started. The budget is counted in tokens because that is
/// what runs out; the day cap below is a sanity bound, not the rule.
const int kNovaLookupTokenCap = 120;

/// At most this many day lines before a LOOKUP block is summarised.
const int kNovaLookupMaxDays = 5;

/// Rough token count: about four characters to a token.
///
/// Deliberately an estimate, and deliberately a slight over-estimate for
/// the short dense lines here, which are mostly numbers and punctuation.
/// Being approximately right and on the cautious side is what is needed —
/// an exact count would mean running the model's own tokeniser on the
/// phone to decide what to send it.
int estimateNovaTokens(String text) {
  if (text.isEmpty) return 0;
  return (text.length / 4).ceil();
}

const List<String> _shortWeekdays = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const List<String> _shortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const List<String> _longMonths = [
  'january',
  'february',
  'march',
  'april',
  'may',
  'june',
  'july',
  'august',
  'september',
  'october',
  'november',
  'december',
];

/// Full weekday names, which are safe to match on their own — "sunday" is
/// not a word anyone uses for anything else.
const List<String> _longWeekdays = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

/// How a day is written in a block Nova reads.
String novaDayLabel(DateTime d) =>
    '${_shortWeekdays[d.weekday - 1]} ${d.day} ${_shortMonths[d.month - 1]}';

/// Seconds as "7h 20m", the way every block Nova reads writes a duration.
String novaHoursMinutes(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}

/// One day's numbers, for the DATA and LOOKUP blocks.
@immutable
class NovaDay {
  const NovaDay({
    required this.day,
    this.sleepSeconds,
    this.sleepScore,
    this.readiness,
    this.hrv,
    this.restingHr,
    this.nightMissing = false,
  });

  final DateTime day;
  final int? sleepSeconds;
  final int? sleepScore;
  final int? readiness;
  final int? hrv;
  final int? restingHr;
  final bool nightMissing;

  /// Whether anything was actually recorded. A day with no numbers is not
  /// evidence of a quiet night; it is evidence of a ring left on a shelf.
  ///
  /// Every field counts, including the derived ones. A first pass left out
  /// sleepScore and readiness, copying an older check that looked only at
  /// the measured values — which called a day holding nothing but a sleep
  /// score empty, and reported a week of them as "no data recorded".
  bool get hasNumbers =>
      sleepSeconds != null ||
      sleepScore != null ||
      readiness != null ||
      hrv != null ||
      restingHr != null;

  String get line {
    final parts = <String>[
      if (sleepSeconds != null) 'sleep ${novaHoursMinutes(sleepSeconds!)}',
      if (sleepScore != null) 'score $sleepScore',
      if (readiness != null) 'readiness $readiness',
      if (hrv != null) 'HRV $hrv',
      if (restingHr != null) 'resting HR $restingHr',
    ];
    if (parts.isEmpty) return '${novaDayLabel(day)}: no data';
    return '${novaDayLabel(day)}: ${parts.join(' · ')}';
  }
}

/// A past window the message is asking about, or null when it is about now.
@immutable
class NovaLookupRange {
  const NovaLookupRange({
    required this.from,
    required this.to,
    required this.label,
  });

  /// Inclusive first day.
  final DateTime from;

  /// Inclusive last day.
  final DateTime to;
  final String label;

  int get days => to.difference(from).inDays + 1;

  @override
  bool operator ==(Object other) =>
      other is NovaLookupRange &&
      other.from == from &&
      other.to == to &&
      other.label == label;

  @override
  int get hashCode => Object.hash(from, to, label);

  @override
  String toString() => 'NovaLookupRange($label, $from → $to)';
}

/// Formats the look-up for a past day or range.
///
/// Item 70: an empty range used to produce an empty string, so a question
/// about a week with nothing recorded reached Nova with no block at all and
/// she answered as though the days had been ordinary. Saying "no data" is
/// the difference between her telling someone their ring was off and her
/// inventing a quiet week.
String formatNovaLookup(List<NovaDay> days, {required String label}) {
  if (days.isEmpty || !days.any((d) => d.hasNumbers)) {
    return 'LOOKUP ($label)\nno data recorded for these days';
  }
  final sorted = [...days]..sort((a, b) => a.day.compareTo(b.day));
  if (sorted.length <= kNovaLookupMaxDays) {
    final full = ['LOOKUP ($label)', for (final d in sorted) d.line].join('\n');
    // The day cap is a bound; the token cap is the rule.
    if (estimateNovaTokens(full) <= kNovaLookupTokenCap) return full;
  }
  return 'LOOKUP ($label)\n${_summaryOf(sorted)}';
}

String _summaryOf(List<NovaDay> sorted) {
  final scores = [
    for (final d in sorted)
      if (d.sleepScore != null) d.sleepScore!,
  ];
  final missing = sorted.where((d) => d.nightMissing).length;
  return <String>[
    '${sorted.length} days',
    if (scores.isNotEmpty)
      'average score ${(scores.reduce((a, b) => a + b) / scores.length).round()}',
    if (scores.isNotEmpty) 'best ${scores.reduce(math.max)}',
    if (scores.isNotEmpty) 'worst ${scores.reduce(math.min)}',
    if (missing > 0) '$missing missing ${missing == 1 ? 'night' : 'nights'}',
  ].join(' · ');
}

/// Words that turn a bare weekday abbreviation into a date.
///
/// Item 70: "sat" and "sun" are ordinary English. They count as days only
/// when something around them says so — "on sat", "last sat", "sat night".
/// Full names need no such help.
const List<String> _datePrefixes = ['on', 'last', 'this', 'past', 'since'];
const List<String> _dayParts = [
  'night',
  'morning',
  'evening',
  'afternoon',
];

bool _mentionsWeekday(String text, int weekday) {
  final long = _longWeekdays[weekday - 1];
  if (RegExp('\\b$long\\b').hasMatch(text)) return true;
  final short = _shortWeekdays[weekday - 1].toLowerCase();
  // "on sat", "last sat" …
  if (RegExp('\\b(?:${_datePrefixes.join('|')})\\s+$short\\b')
      .hasMatch(text)) {
    return true;
  }
  // "sat night", "sat morning" …
  if (RegExp('\\b$short\\s+(?:${_dayParts.join('|')})\\b').hasMatch(text)) {
    return true;
  }
  // "sat's" — possessive, as in "sat's sleep".
  return RegExp("\\b$short's\\b").hasMatch(text);
}

/// A day and month written out, or null when the text has none.
///
/// Item 70: the old pattern allowed any suffix after the month, so `dec`
/// matched "decaf" and `jan` matched "janitor". Both the short and the full
/// name are matched exactly, with a boundary on each side.
({int month, int day})? _monthAndDay(String text) {
  for (var i = 0; i < _shortMonths.length; i++) {
    final names = '(?:${_shortMonths[i].toLowerCase()}|${_longMonths[i]})';
    final match = RegExp(
      '\\b(\\d{1,2})\\s+$names\\b|\\b$names\\s+(\\d{1,2})\\b',
    ).firstMatch(text);
    if (match == null) continue;
    final number = int.tryParse(match.group(1) ?? match.group(2) ?? '');
    if (number == null || number < 1 || number > 31) continue;
    return (month: i + 1, day: number);
  }
  return null;
}

/// Reads the message for a past day, a range, or a metric over time.
///
/// Returns null when it refers to nothing older than today — in which case
/// no LOOKUP block is added at all. Null is also the answer whenever the
/// text is merely *suggestive* of a date: adding nothing leaves Nova
/// working from the DATA block, which is correct, where a wrong guess has
/// her answering confidently about the wrong day.
NovaLookupRange? novaLookupRangeFor(String message, {DateTime? now}) {
  final at = now ?? DateTime.now();
  final today = DateTime(at.year, at.month, at.day);
  final text = message.toLowerCase();

  DateTime back(int days) => today.subtract(Duration(days: days));

  if (text.contains('last month')) {
    return NovaLookupRange(
      from: DateTime(today.year, today.month - 1, 1),
      to: DateTime(today.year, today.month, 0),
      label: 'last month',
    );
  }
  if (text.contains('this month')) {
    return NovaLookupRange(
      from: DateTime(today.year, today.month, 1),
      to: today,
      label: 'this month',
    );
  }
  if (text.contains('last week')) {
    return NovaLookupRange(from: back(13), to: back(7), label: 'last week');
  }
  if (text.contains('this week') ||
      text.contains('last 7') ||
      text.contains('past week') ||
      text.contains('past 7')) {
    return NovaLookupRange(from: back(6), to: today, label: 'last 7 days');
  }
  if (text.contains('last 30') ||
      text.contains('past 30') ||
      text.contains('past month')) {
    return NovaLookupRange(from: back(29), to: today, label: 'last 30 days');
  }
  if (text.contains('yesterday')) {
    return NovaLookupRange(from: back(1), to: back(1), label: 'yesterday');
  }

  // A weekday means the most recent one that has already happened.
  for (var weekday = 1; weekday <= 7; weekday++) {
    if (!_mentionsWeekday(text, weekday)) continue;
    var day = today.subtract(const Duration(days: 1));
    for (var i = 0; i < 7; i++) {
      if (day.weekday == weekday) {
        return NovaLookupRange(
          from: day,
          to: day,
          label: _shortWeekdays[weekday - 1],
        );
      }
      day = day.subtract(const Duration(days: 1));
    }
  }

  // "12 Oct" / "Oct 12".
  final written = _monthAndDay(text);
  if (written != null) {
    var year = today.year;
    var day = DateTime(year, written.month, written.day);
    if (day.isAfter(today)) day = DateTime(--year, written.month, written.day);
    return NovaLookupRange(from: day, to: day, label: novaDayLabel(day));
  }

  // A metric named over time, with no date: the last week is the useful
  // default — the same window Metrics opens on.
  if (RegExp(r'\b(trend|trending|average|over time|recently|lately)\b')
      .hasMatch(text)) {
    return NovaLookupRange(from: back(6), to: today, label: 'last 7 days');
  }
  return null;
}

/// How many concerns the DATA block will carry.
///
/// The block has a target of [kNovaDataTargetTokens], and item 70 widened
/// the window that feeds this list from one day to three — which is more
/// to say, not more room to say it in. The most recent come first.
const int kNovaMaxConcerns = 4;

/// "today" / "yesterday" / "3 days ago", for a concern's age.
String novaDaysAgoWord(int daysAgo) => switch (daysAgo) {
      <= 0 => 'today',
      1 => 'yesterday',
      _ => '$daysAgo days ago',
    };

/// The alerts the person was actually sent, within [within].
///
/// Item 70: "concerning" was derived from the dashboard alone, so it never
/// mentioned anything the alert service had notified someone about. Nova
/// could say the week looked unremarkable to a person whose phone had
/// buzzed about their resting heart rate two nights before.
///
/// Read from the "already fired" timestamps rather than re-derived from
/// thresholds, so what Nova is told is what the person was actually told.
/// The flags record when, not what, so these name the kind and the day and
/// claim nothing more.
List<String> recentAlertConcerns({
  required DateTime now,
  DateTime? healthFiredAt,
  DateTime? lowBatteryFiredAt,
  Duration within = const Duration(days: 3),
}) {
  final out = <String>[];
  void add(String what, DateTime? when) {
    if (when == null) return;
    final age = now.difference(when);
    if (age.isNegative || age > within) return;
    out.add('$what alert sent ${novaDaysAgoWord(age.inDays)}');
  }

  add('health', healthFiredAt);
  add('low battery', lowBatteryFiredAt);
  return out;
}

/// The DATA block for one message, with what decides whether it is sent.
///
/// Item 106: [block] is what Nova reads. [key] is only the parts that
/// matter enough to tell her again: the night, the readiness word, the
/// alerts and concerns, and whether the sync is stale or missing. The block
/// also carries the last-sync time and the battery, which move all day;
/// comparing the block text re-sent it on nearly every message.
/// [timeLine] is the time of day, which goes with every message as one
/// short line of its own, so a new minute never re-sends the numbers.
class NovaData {
  const NovaData({
    required this.block,
    required this.key,
    this.timeLine = '',
  });

  final String block;
  final String key;
  final String timeLine;

  static const NovaData none = NovaData(block: '', key: '');
}

/// Whether the DATA block still has to be sent.
///
/// Item 70: it was re-sent with every message. On Android that pushed the
/// conversation past the window by the third turn, and the part dropped to
/// make room is the oldest — the question.
///
/// Item 106 (decided 15 Nov): sent with the first message of each
/// conversation, and again only when [key] changes — a new night, a new
/// readiness word, a new alert, a sync going stale. Never because the time
/// changed. [lastSentKey] is null at the start of a conversation and after
/// the session was rebuilt.
///
/// [sessionRemembers] is the whole subtlety. An on-device chat keeps the
/// turns it has been given, so a block sent once is still in the window. A
/// request to someone's own server carries the entire context every time
/// and remembers nothing between calls, so there the block must always go.
bool novaDataNeedsSending({
  required String block,
  required String key,
  required String? lastSentKey,
  required bool sessionRemembers,
}) {
  if (block.trim().isEmpty) return false;
  if (!sessionRemembers) return true;
  return key != lastSentKey;
}

/// Assembles what is actually sent for one message.
///
/// Order matters: the question comes first, so that if the window does
/// overflow, the part most likely to survive is what was asked. The time
/// line is next: one short line, sent every time (item 106).
String composeNovaPrompt({
  required String message,
  String timeLine = '',
  String dataBlock = '',
  String lookupBlock = '',
}) {
  return [
    message,
    if (timeLine.trim().isNotEmpty) timeLine,
    if (dataBlock.trim().isNotEmpty) dataBlock,
    if (lookupBlock.trim().isNotEmpty) lookupBlock,
  ].join('\n\n');
}

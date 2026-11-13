part of '../../main.dart';

/// Item 51 — what Nova is told about the user, and how.
///
/// Nova used to be sent the typed message and nothing else, so asked why last
/// night's sleep score was not recorded she had nothing to answer with and
/// fell back on "let's focus on today". There was never a privacy reason for
/// it: the model and the data are both on this phone.
///
/// Every value here is read from the same source the screens read, so Nova
/// can never disagree with what Home and Metrics are showing.

/// Target size of the DATA block. Short fields, not sentences — the cap it
/// shares with the conversation is small (see the note on
/// [GuidePersonaPrefsService.maxTokensFor]).
const int kNovaDataTargetTokens = 150;

/// At most this many day lines in a LOOKUP block; beyond it, a summary.
const int kNovaLookupMaxDays = 10;

/// One day's numbers, for the DATA and LOOKUP blocks.
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

  String get line {
    final parts = <String>[
      if (sleepSeconds != null) 'sleep ${_hm(sleepSeconds!)}',
      if (sleepScore != null) 'score $sleepScore',
      if (readiness != null) 'readiness $readiness',
      if (hrv != null) 'HRV $hrv',
      if (restingHr != null) 'resting HR $restingHr',
    ];
    if (parts.isEmpty) return '${_date(day)}: no data';
    return '${_date(day)}: ${parts.join(' · ')}';
  }
}

String _hm(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}

String _date(DateTime d) =>
    '${kShortWeekdays[d.weekday - 1]} ${d.day} ${kShortMonths[d.month - 1]}';

String _stamp(DateTime d) =>
    '${_date(d)} ${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}';

String _momentWord(HomeMoment moment) => switch (moment) {
      HomeMoment.morning => 'morning',
      HomeMoment.day => 'day',
      HomeMoment.night => 'evening',
    };

/// Everything the DATA block is built from, gathered once so the formatter
/// stays pure and testable.
class NovaFacts {
  const NovaFacts({
    required this.now,
    required this.lastNight,
    required this.nightReason,
    required this.yesterday,
    required this.today,
    required this.intent,
    required this.intentConfirmed,
    required this.hasRing,
    this.hrvBase,
    this.restingHrBase,
    this.lastSyncedAt,
    this.batteryPercent,
    this.charging = false,
    this.suggestion,
    this.suggestionMinutes,
    this.plannedActivity,
    this.plannedDone = false,
    this.patterns = const [],
    this.concerns = const [],
  });

  final DateTime now;

  /// Null when no night was recorded for today.
  final NovaDay? lastNight;
  final MissingNightReason nightReason;
  final NovaDay? yesterday;
  final NovaDay today;

  final DayIntent intent;
  final bool intentConfirmed;
  final bool hasRing;

  final int? hrvBase;
  final int? restingHrBase;
  final DateTime? lastSyncedAt;
  final int? batteryPercent;
  final bool charging;

  /// The current suggestion from item 45, in the words the card uses.
  final String? suggestion;
  final int? suggestionMinutes;

  /// The planned practice from item 46, and whether it is done.
  final String? plannedActivity;
  final bool plannedDone;

  /// Active patterns, one line each — the top three.
  final List<String> patterns;

  /// Anything concerning in the last three days, from the app's existing
  /// rules only. No new thresholds.
  final List<String> concerns;
}

/// The block appended to every message. The user never sees or types it.
///
/// Short fields, not sentences; any line with nothing in it is omitted.
String formatNovaData(NovaFacts f) {
  final lines = <String>['DATA (from the ring and app, not the user)'];

  lines.add(
    'now: ${_stamp(f.now)} · ${_momentWord(homeMomentAt(f.now))}',
  );

  // Last night — recorded, partial or missing, and *why* when it is not
  // there (item 36). "I can't see one" is a useless answer on its own.
  if (f.lastNight case final night?) {
    final parts = <String>[
      if (night.sleepSeconds != null) _hm(night.sleepSeconds!),
      if (night.sleepScore != null) 'score ${night.sleepScore}',
    ];
    final suffix = f.nightReason == MissingNightReason.recorded
        ? ''
        : ' · partial (${f.nightReason.phrase})';
    lines.add('last night: ${parts.join(' · ')}$suffix');
  } else {
    final since = f.lastSyncedAt == null
        ? 'never synced'
        : 'no sync since ${_stamp(f.lastSyncedAt!)}';
    lines.add('last night: missing · ${f.nightReason.phrase} · $since');
  }

  if (f.yesterday case final y?) {
    final parts = <String>[
      if (y.sleepSeconds != null) 'sleep ${_hm(y.sleepSeconds!)}',
      if (y.sleepScore != null) 'score ${y.sleepScore}',
      if (y.readiness != null) 'readiness ${y.readiness}',
    ];
    if (parts.isNotEmpty) lines.add('yesterday: ${parts.join(' · ')}');
  }

  final todayParts = <String>[
    if (f.today.readiness != null) 'readiness ${f.today.readiness}',
    if (f.today.hrv != null)
      'HRV ${f.today.hrv}${f.hrvBase == null ? '' : ' (base ${f.hrvBase})'}',
    if (f.today.restingHr != null)
      'resting HR ${f.today.restingHr}'
          '${f.restingHrBase == null ? '' : ' (base ${f.restingHrBase})'}',
  ];
  if (todayParts.isNotEmpty) lines.add('today: ${todayParts.join(' · ')}');

  if (f.hasRing) {
    final ring = <String>[
      if (f.lastSyncedAt != null) 'last sync ${_stamp(f.lastSyncedAt!)}',
      if (f.batteryPercent != null)
        'battery ${f.batteryPercent}%${f.charging ? ' (charging)' : ''}',
    ];
    if (ring.isNotEmpty) lines.add('ring: ${ring.join(' · ')}');
  }

  final plan = <String>[
    'intent ${f.intent.label}'
        '${f.intentConfirmed ? '' : ' (not confirmed)'}',
    if (f.suggestion != null)
      'suggested ${f.suggestion}'
          '${f.suggestionMinutes == null ? '' : ' ${f.suggestionMinutes} min'}',
    if (f.plannedActivity != null)
      'planned ${f.plannedActivity} (${f.plannedDone ? 'done' : 'not done'})',
  ];
  lines.add("today's plan: ${plan.join(' · ')}");

  if (f.patterns.isNotEmpty) {
    lines.add('patterns: ${f.patterns.take(3).join(' · ')}');
  }
  if (f.concerns.isNotEmpty) {
    lines.add('concerning: ${f.concerns.join(' · ')}');
  }

  return lines.join('\n');
}

/// Formats the look-up for a past day or range (item 51 (2)). One line per
/// day up to [kNovaLookupMaxDays]; beyond that, a summary.
String formatNovaLookup(List<NovaDay> days, {required String label}) {
  if (days.isEmpty) return '';
  final sorted = [...days]..sort((a, b) => a.day.compareTo(b.day));
  if (sorted.length <= kNovaLookupMaxDays) {
    return ['LOOKUP ($label)', for (final d in sorted) d.line].join('\n');
  }
  final scores = [
    for (final d in sorted)
      if (d.sleepScore != null) d.sleepScore!,
  ];
  final missing = sorted.where((d) => d.nightMissing).length;
  final summary = <String>[
    '${sorted.length} days',
    if (scores.isNotEmpty)
      'average score ${(scores.reduce((a, b) => a + b) / scores.length).round()}',
    if (scores.isNotEmpty) 'best ${scores.reduce(math.max)}',
    if (scores.isNotEmpty) 'worst ${scores.reduce(math.min)}',
    if (missing > 0) '$missing missing ${missing == 1 ? 'night' : 'nights'}',
  ];
  return 'LOOKUP ($label)\n${summary.join(' · ')}';
}

// ── Does this message refer to a past day or range? ───────────────────────

const Map<String, int> _weekdayWords = {
  'monday': 1,
  'tuesday': 2,
  'wednesday': 3,
  'thursday': 4,
  'friday': 5,
  'saturday': 6,
  'sunday': 7,
  'mon': 1,
  'tue': 2,
  'wed': 3,
  'thu': 4,
  'fri': 5,
  'sat': 6,
  'sun': 7,
};

/// A past window the message is asking about, or null when it is about now.
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
}

/// Reads the message for a past day, a range, or a metric over time. Returns
/// null when it refers to nothing older than today — in which case no LOOKUP
/// block is added at all.
NovaLookupRange? novaLookupRangeFor(String message, {DateTime? now}) {
  final at = now ?? DateTime.now();
  final today = DateTime(at.year, at.month, at.day);
  final text = message.toLowerCase();

  DateTime back(int days) => today.subtract(Duration(days: days));

  if (text.contains('last month')) {
    final first = DateTime(today.year, today.month - 1, 1);
    return NovaLookupRange(
      from: first,
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
    return NovaLookupRange(
      from: back(1),
      to: back(1),
      label: 'yesterday',
    );
  }

  // A weekday name means the most recent one that has already happened.
  for (final entry in _weekdayWords.entries) {
    if (!RegExp(r'\b' + entry.key + r'\b').hasMatch(text)) continue;
    var day = today.subtract(const Duration(days: 1));
    for (var i = 0; i < 7; i++) {
      if (day.weekday == entry.value) {
        return NovaLookupRange(
          from: day,
          to: day,
          label: kShortWeekdays[entry.value - 1],
        );
      }
      day = day.subtract(const Duration(days: 1));
    }
  }

  // "12 Oct" / "Oct 12".
  final months = [
    for (final m in kShortMonths) m.toLowerCase(),
  ];
  for (var i = 0; i < months.length; i++) {
    final m = months[i];
    final match = RegExp(
      r'(?:(\d{1,2})\s+' + m + r'|' + m + r'\w*\s+(\d{1,2}))',
    ).firstMatch(text);
    if (match == null) continue;
    final dayNumber = int.tryParse(match.group(1) ?? match.group(2) ?? '');
    if (dayNumber == null || dayNumber < 1 || dayNumber > 31) continue;
    var year = today.year;
    var day = DateTime(year, i + 1, dayNumber);
    if (day.isAfter(today)) day = DateTime(--year, i + 1, dayNumber);
    return NovaLookupRange(from: day, to: day, label: _date(day));
  }

  // A metric named over time, with no date: the last week is the useful
  // default — the same window Metrics opens on.
  if (RegExp(r'\b(trend|trending|average|over time|recently|lately)\b')
      .hasMatch(text)) {
    return NovaLookupRange(from: back(6), to: today, label: 'last 7 days');
  }
  return null;
}

// ── Gathering the facts ───────────────────────────────────────────────────

/// Mean of [points] over [days], excluding today — the same window §14's
/// baselines use, so Nova's "base 55" is the number Metrics shows.
int? _baseOf(List<VitalHistoryPoint> points, DateTime now) {
  final since = now.subtract(const Duration(days: kBaselineWindowDays));
  final today = DateTime(now.year, now.month, now.day);
  final values = [
    for (final p in points)
      if (p.time.isAfter(since) && p.time.isBefore(today)) p.value,
  ];
  if (values.isEmpty) return null;
  return (values.reduce((a, b) => a + b) / values.length).round();
}

/// One day's numbers, built from the same helpers Home and Metrics use.
NovaDay _dayFrom(RingHistory history, DateTime day) {
  final nights = sleepDaySummaries(history.sleep);
  final target = DateTime(day.year, day.month, day.day);
  SleepDaySummary? night;
  for (final n in nights) {
    if (DateTime(n.day.year, n.day.month, n.day.day) == target) {
      night = n;
      break;
    }
  }
  final hrvPoints = vitalHistoryPoints(history, VitalsMetricKind.hrv);
  final hrPoints = vitalHistoryPoints(history, VitalsMetricKind.heartRate);
  final hrv = hrvForDay(hrvPoints: hrvPoints, night: night, day: target);
  final restingHr = restingHrForDay(
    hrPoints: hrPoints,
    day: target,
    night: night,
    sessions: sportWindows(history.sport, target),
  );
  final usable = night != null &&
      sleepNightStatus(night, now: night.day, history: history) ==
          SleepNightStatus.complete;
  return NovaDay(
    day: target,
    sleepSeconds: night?.breakdown.asleepSeconds,
    sleepScore: usable ? night.score : null,
    readiness: readinessScoreFrom(
      sleepScore: usable ? night.score : null,
      hrv: hrv,
    ),
    hrv: hrv,
    restingHr: restingHr,
    nightMissing: night == null,
  );
}

/// Anything concerning in the last three days, using the app's own rules
/// only — no new thresholds (item 51).
List<String> _concernsFrom({
  required HomeDashboard dashboard,
  required RingController controller,
  required RingHistory history,
  required DateTime now,
}) {
  final out = <String>[];

  // Bug 36: a missing or partial night, with its reason.
  switch (dashboard.sleepStatus) {
    case SleepNightStatus.missing:
      if (!dashboard.syncPending) {
        out.add('no sleep last night (${dashboard.nightReason.phrase})');
      }
    case SleepNightStatus.incomplete:
      out.add('partial night (${dashboard.nightReason.phrase})');
    case SleepNightStatus.complete:
      break;
  }

  // The stale-sync banner's own condition, and the low-battery alert's.
  if (ringIsStale(controller)) out.add('ring not synced for a day');
  final battery = controller.batteryPercent;
  if (battery != null &&
      battery > 0 &&
      battery <= kLowBatteryPercent &&
      !controller.wasChargingWhenLastSeen) {
    out.add('battery low ($battery%)');
  }

  // A Depleted readiness, in the same words the score shows.
  final score = dashboard.readinessScore;
  if (score != null && !dashboard.readinessIsHrvOnly && score < 50) {
    out.add('readiness $score (depleted)');
  }

  // A vital outside its personal or typical range (§14's ranges, unchanged).
  for (final kind in const [
    VitalsMetricKind.heartRate,
    VitalsMetricKind.spo2,
    VitalsMetricKind.temperature,
  ]) {
    final range = referenceRangeFor(kind);
    if (range == null) continue;
    final value = switch (kind) {
      VitalsMetricKind.heartRate => dashboard.restingHr?.toDouble(),
      VitalsMetricKind.spo2 => controller.vitals.bloodOxygen?.toDouble(),
      _ => controller.vitals.temperature,
    };
    if (value == null) continue;
    final verdict = vitalVerdict(kind: kind, range: range, value: value);
    if (verdict.quality == 'poor' || verdict.quality == 'watch') {
      out.add('${kind.name} $value ${verdict.captionSuffix ?? ''}'.trim());
    }
  }
  return out;
}

/// Builds the DATA block for the message about to be sent. Reads the same
/// providers the screens read, so Nova can never disagree with the screen.
String novaDataBlockFor(WidgetRef ref, {DateTime? at}) {
  final now = at ?? DateTime.now();
  final controller = ref.read(ringControllerProvider);
  final dashboard = HomeDashboard.from(controller);
  final history = controller.history;
  final intentState = ref.read(dayIntentProvider);
  final intent = intentState.intent ?? DayIntent.recover;
  final sessions = ref.read(recentSessionsProvider).valueOrNull ?? const [];
  final finished = [
    for (final s in sessions)
      if (s.endedAt != null) s,
  ];
  final today = todaysFinishedSessions(sessions, now: now);
  final plan = ref.read(weeklyPlanProvider);
  final suggestion = homeSuggestionFor(
    intent: intent,
    state: controller.currentWellnessState(),
    readiness: dashboard.readinessScore,
    moment: homeMomentAt(now),
    now: now,
    pins: ref.read(pinnedPracticesProvider),
    history: finished,
    todaysFinished: today,
    plan: plan,
  );
  final plannedDay = plan.forDay(now);
  final doneIds = {for (final s in today) s.vyanaActivityType};
  final planned = plannedDay.isEmpty ? null : plannedDay.activityIds.first;

  final todayDay = DateTime(now.year, now.month, now.day);
  final nights = sleepDaySummaries(history.sleep);
  final tonight = sleepNightForToday(nights, now: now);
  final patterns = ref.read(patternsProvider).valueOrNull ?? const [];

  return formatNovaData(
    NovaFacts(
      now: now,
      lastNight: tonight == null ? null : _dayFrom(history, tonight.day),
      nightReason: dashboard.nightReason,
      yesterday: _dayFrom(
        history,
        todayDay.subtract(const Duration(days: 1)),
      ),
      today: NovaDay(
        day: todayDay,
        readiness: dashboard.readinessScore,
        hrv: dashboard.overnightHrv,
        restingHr: dashboard.restingHr,
      ),
      hrvBase: _baseOf(
        vitalHistoryPoints(history, VitalsMetricKind.hrv),
        now,
      ),
      restingHrBase: _baseOf(
        vitalHistoryPoints(history, VitalsMetricKind.heartRate),
        now,
      ),
      intent: intent,
      intentConfirmed: intentState.confirmed,
      hasRing: controller.hasRingContext,
      lastSyncedAt: controller.lastSyncedAt,
      batteryPercent: controller.batteryPercent,
      charging: controller.isCharging,
      suggestion: suggestion.activity.name,
      suggestionMinutes: suggestion.minutes,
      plannedActivity: planned == null ? null : activityById(planned)?.name,
      plannedDone: planned != null && doneIds.contains(planned),
      patterns: [
        for (final p in patterns)
          if (p.endedAt == null) '${p.claim} (${p.status})',
      ],
      concerns: _concernsFrom(
        dashboard: dashboard,
        controller: controller,
        history: history,
        now: now,
      ),
    ),
  );
}

/// Builds the LOOKUP block for [message], or an empty string when it refers
/// to nothing older than today. Added to that message only.
String novaLookupBlockFor(
  WidgetRef ref,
  String message, {
  DateTime? at,
}) {
  final now = at ?? DateTime.now();
  final range = novaLookupRangeFor(message, now: now);
  if (range == null) return '';
  final history = ref.read(ringControllerProvider).history;
  final days = <NovaDay>[
    for (var i = 0; i < range.days; i++)
      _dayFrom(history, range.from.add(Duration(days: i))),
  ];
  // Nothing on record for any of those days: say nothing rather than
  // printing a wall of "no data".
  final hasData = days.any(
    (d) => d.sleepSeconds != null || d.hrv != null || d.restingHr != null,
  );
  if (!hasData) return '';
  return formatNovaLookup(days, label: range.label);
}

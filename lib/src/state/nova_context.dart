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

/// Item 70: the day label lives in nova_budget.dart now, with the rest of
/// what Nova is told. Aliased rather than duplicated.
String _date(DateTime d) => novaDayLabel(d);

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
    this.plannedSkipped = false,
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

  /// Item 94: whether it was stood down for today. Nova is told, because a
  /// plan someone has declined is not a plan they are ignoring — and asking
  /// why they have not walked yet would be reading the day wrong.
  final bool plannedSkipped;

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
      if (night.sleepSeconds != null) novaHoursMinutes(night.sleepSeconds!),
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
      if (y.sleepSeconds != null) 'sleep ${novaHoursMinutes(y.sleepSeconds!)}',
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
      'planned ${f.plannedActivity} ('
          '${f.plannedDone ? 'done' : f.plannedSkipped ? 'skipped today' : 'not done'})',
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
  final nights = history.sleepNights;
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
  List<String> alerts = const [],
}) {
  final out = <String>[];

  // Item 70: the alerts the person was actually sent come first, because
  // being asked about a week Nova calls unremarkable is worst when the
  // phone buzzed about it two nights ago.
  out.addAll(alerts);

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

  // Item 70: the doc comment above always said "the last three days" while
  // the code read the dashboard, which is today. The two days before last
  // night come from history, by the same rules.
  final today = DateTime(now.year, now.month, now.day);
  for (var back = 1; back <= 2; back++) {
    final day = _dayFrom(history, today.subtract(Duration(days: back)));
    final word = novaDaysAgoWord(back);
    if (day.nightMissing) {
      out.add('no sleep recorded $word');
    } else if (day.readiness != null && day.readiness! < 50) {
      out.add('readiness ${day.readiness} $word');
    }
  }

  // More to say, not more room to say it in: the DATA block still has to
  // fit the window it shares with the conversation.
  return out.take(kNovaMaxConcerns).toList();
}

/// Builds the DATA block for the message about to be sent. Reads the same
/// providers the screens read, so Nova can never disagree with the screen.
///
/// Item 70: asynchronous now, because the alerts someone was actually sent
/// live in preferences rather than in a provider. Worth the await — the
/// alternative was Nova describing a calm week to a person whose phone had
/// told them otherwise.
Future<String> novaDataBlockFor(WidgetRef ref, {DateTime? at}) async {
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
  final nights = history.sleepNights;
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
      plannedSkipped: planned != null &&
          ref.read(plannedSkipsProvider.notifier).today.contains(planned),
      patterns: [
        for (final p in patterns)
          if (p.endedAt == null) '${p.claim} (${p.status})',
      ],
      concerns: _concernsFrom(
        dashboard: dashboard,
        controller: controller,
        history: history,
        now: now,
        alerts: await _recentAlerts(now),
      ),
    ),
  );
}

/// What the alert service has notified this person about lately.
///
/// Reads the "already fired" stamps the alert evaluator writes, so Nova is
/// told what the person was told. A keystore or preferences failure here
/// returns nothing rather than failing the message: a DATA block missing
/// one line is better than no answer.
Future<List<String>> _recentAlerts(DateTime now) async {
  try {
    final store = await SharedPreferences.getInstance();
    DateTime? stamp(String key) {
      final millis = store.getInt(key);
      return millis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(millis);
    }

    return recentAlertConcerns(
      now: now,
      healthFiredAt: stamp(kRingAlertHealthFiredAtKey),
      lowBatteryFiredAt: stamp(kRingAlertLowBatteryFiredAtKey),
    );
  } on Object catch (error) {
    debugPrint('[Nova] could not read recent alerts: $error');
    return const [];
  }
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
  // Item 70: an empty range used to return nothing at all, so a question
  // about a week with the ring in a drawer reached Nova with no block and
  // she answered as though the days had been ordinary. formatNovaLookup
  // now says "no data recorded" in one line — which is the difference
  // between Nova telling someone their ring was off and Nova inventing a
  // quiet week.
  return formatNovaLookup(days, label: range.label);
}

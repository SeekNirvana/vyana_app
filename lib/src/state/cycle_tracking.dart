part of '../../main.dart';

/// §14b — opt-in cycle tracking, on device only.
///
/// Resting HR, HRV and skin temperature shift across the cycle (higher HR and
/// temperature, lower HRV after ovulation). Without the phase, §14's baselines
/// read that monthly shift as stress. Everything here is derived from the set
/// of logged period days, so correcting a wrong day is one tap in the
/// calendar and every number recomputes.

enum CyclePhase { menstrual, follicular, luteal }

extension CyclePhaseX on CyclePhase {
  String get label => switch (this) {
        CyclePhase.menstrual => 'Menstrual',
        CyclePhase.follicular => 'Follicular',
        CyclePhase.luteal => 'Luteal',
      };
}

/// Cycle length used until the user has two cycles of their own.
const int kDefaultCycleLength = 28;

/// Period length assumed until the first period has ended.
const int kDefaultPeriodLength = 5;

/// Ovulation is estimated this many days before the next period starts.
const int kLutealPhaseDays = 14;

/// A run of consecutive logged period days.
class PeriodRun {
  const PeriodRun({
    required this.start,
    required this.end,
    required this.endConfirmed,
  });

  final DateTime start;
  final DateTime end;

  /// True once the user tapped "Period ended" (or confirmed the date), so the
  /// length is recorded rather than assumed.
  final bool endConfirmed;

  int get lengthDays => end.difference(start).inDays + 1;
}

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Groups logged days into consecutive runs, newest first.
List<PeriodRun> periodRuns(List<CycleDayRow> rows) {
  if (rows.isEmpty) return const [];
  final days = rows.map((r) => _dayOf(r.day)).toSet().toList()..sort();
  final confirmed = {
    for (final r in rows)
      if (r.endConfirmed) _dayOf(r.day),
  };
  final runs = <PeriodRun>[];
  var start = days.first;
  var prev = days.first;
  for (final day in days.skip(1)) {
    if (day.difference(prev).inDays == 1) {
      prev = day;
      continue;
    }
    runs.add(PeriodRun(
      start: start,
      end: prev,
      endConfirmed: confirmed.contains(prev),
    ));
    start = day;
    prev = day;
  }
  runs.add(PeriodRun(
    start: start,
    end: prev,
    endConfirmed: confirmed.contains(prev),
  ));
  return runs.reversed.toList();
}

/// Everything the Cycle card and calendar show, derived from logged days.
class CycleStatus {
  const CycleStatus({
    required this.runs,
    required this.today,
    this.cycleDay,
    this.phase,
    this.nextPeriodStart,
    this.estimatedOvulation,
    this.averageCycleLength,
    this.averagePeriodLength,
    this.cycleCount = 0,
    this.periodCount = 0,
    this.cycleLengthSpread,
  });

  final List<PeriodRun> runs;
  final DateTime today;

  /// Day 1 is the first day of the current period.
  final int? cycleDay;
  final CyclePhase? phase;
  final DateTime? nextPeriodStart;
  final DateTime? estimatedOvulation;
  final int? averageCycleLength;
  final int? averagePeriodLength;

  /// How many complete cycles / finished periods the averages rest on, so the
  /// calendar can state the count beside each number.
  final int cycleCount;
  final int periodCount;

  /// ± spread of the user's own cycle lengths, for "around 9 Oct ± 2 days".
  final int? cycleLengthSpread;

  bool get hasData => runs.isNotEmpty;

  /// True while a period is running, so the pill reads "Period ended".
  bool get periodInProgress {
    if (runs.isEmpty) return false;
    final latest = runs.first;
    if (latest.endConfirmed) return false;
    // Still running if it includes today or yesterday — a day can be logged
    // late in the evening or the morning after.
    return today.difference(latest.end).inDays <= 1;
  }

  /// The end date a never-confirmed run is assumed to have.
  DateTime? get proposedEnd {
    if (runs.isEmpty) return null;
    final latest = runs.first;
    if (latest.endConfirmed) return null;
    final length = averagePeriodLength ?? kDefaultPeriodLength;
    return latest.start.add(Duration(days: length - 1));
  }

  /// Whether to ask "Did your period end on …?" — two days after the proposed
  /// end, so it never interrupts a longer-than-usual period.
  bool get shouldAskEnd {
    final proposed = proposedEnd;
    if (proposed == null) return false;
    return today.difference(proposed).inDays >= 2;
  }
}

/// Builds the status from logged days. [now] is injectable for tests.
CycleStatus cycleStatusFrom(List<CycleDayRow> rows, {DateTime? now}) {
  final today = _dayOf(now ?? DateTime.now());
  final runs = periodRuns(rows);
  if (runs.isEmpty) return CycleStatus(runs: const [], today: today);

  // Gaps between consecutive starts are the user's own cycle lengths.
  final starts = runs.map((r) => r.start).toList()..sort();
  final lengths = <int>[];
  for (var i = 1; i < starts.length; i++) {
    final gap = starts[i].difference(starts[i - 1]).inDays;
    // Ignore implausible gaps so one mislogged day cannot skew the average.
    if (gap >= 15 && gap <= 60) lengths.add(gap);
  }
  final avgCycle = lengths.isEmpty
      ? null
      : (lengths.reduce((a, b) => a + b) / lengths.length).round();
  final spread = lengths.length < 2
      ? null
      : ((lengths.reduce(math.max) - lengths.reduce(math.min)) / 2).round();

  final finished = runs.where((r) => r.endConfirmed).toList();
  final avgPeriod = finished.isEmpty
      ? null
      : (finished.map((r) => r.lengthDays).reduce((a, b) => a + b) /
              finished.length)
          .round();

  // Predictions work from day one: 28 days until two cycles exist.
  final effectiveCycle = avgCycle ?? kDefaultCycleLength;
  final latestStart = runs.first.start;
  var nextStart = latestStart.add(Duration(days: effectiveCycle));
  // If the predicted start has already passed without a log, roll it forward
  // rather than showing a date in the past.
  while (nextStart.isBefore(today)) {
    nextStart = nextStart.add(Duration(days: effectiveCycle));
  }
  final ovulation = nextStart.subtract(const Duration(days: kLutealPhaseDays));

  final cycleDay = today.difference(latestStart).inDays + 1;
  final periodLength = avgPeriod ?? kDefaultPeriodLength;
  final loggedToday = rows.any((r) => _dayOf(r.day) == today);
  CyclePhase phase;
  if (loggedToday || cycleDay <= periodLength) {
    phase = CyclePhase.menstrual;
  } else if (today.isBefore(ovulation)) {
    phase = CyclePhase.follicular;
  } else {
    phase = CyclePhase.luteal;
  }

  return CycleStatus(
    runs: runs,
    today: today,
    cycleDay: cycleDay >= 1 ? cycleDay : null,
    phase: phase,
    nextPeriodStart: nextStart,
    estimatedOvulation: ovulation,
    averageCycleLength: avgCycle,
    averagePeriodLength: avgPeriod,
    cycleCount: lengths.length,
    periodCount: finished.length,
    cycleLengthSpread: spread,
  );
}

/// The phase a past day fell in, so baselines can be grouped by phase.
CyclePhase? phaseForDay(DateTime day, List<PeriodRun> runs, {int? avgCycle}) {
  if (runs.isEmpty) return null;
  final target = _dayOf(day);
  // The run this day belongs to, or the most recent one before it.
  PeriodRun? current;
  for (final run in runs) {
    if (!run.start.isAfter(target)) {
      current = run;
      break;
    }
  }
  if (current == null) return null;
  if (!target.isBefore(current.start) && !target.isAfter(current.end)) {
    return CyclePhase.menstrual;
  }
  final length = avgCycle ?? kDefaultCycleLength;
  final nextStart = current.start.add(Duration(days: length));
  final ovulation = nextStart.subtract(const Duration(days: kLutealPhaseDays));
  if (target.isAfter(nextStart)) return null; // too far out to attribute
  return target.isBefore(ovulation)
      ? CyclePhase.follicular
      : CyclePhase.luteal;
}

/// Phase-aware base: once two cycles exist, a vital's base is the user's
/// average for the *same phase*, not their overall average (§14b "Effect on
/// baselines"). Returns null when there is not enough same-phase history, so
/// the caller falls back to the overall base.
double? phaseBaseFor({
  required CyclePhase phase,
  required List<(DateTime, double)> samples,
  required List<PeriodRun> runs,
  int? avgCycle,
  int minSamples = 3,
}) {
  final matching = <double>[];
  for (final (day, value) in samples) {
    if (phaseForDay(day, runs, avgCycle: avgCycle) == phase) {
      matching.add(value);
    }
  }
  if (matching.length < minSamples) return null;
  return matching.reduce((a, b) => a + b) / matching.length;
}

// ── Pregnancy (13d) ──────────────────────────────────────────────────────

/// Weeks and trimester from a due date. A pregnancy is 40 weeks, so the
/// elapsed weeks are 40 minus whatever remains.
class PregnancyStatus {
  const PregnancyStatus({required this.dueDate, required this.week});

  final DateTime dueDate;
  final int week;

  int get trimester => week <= 13 ? 1 : (week <= 27 ? 2 : 3);

  String get trimesterLabel => switch (trimester) {
        1 => 'First trimester',
        2 => 'Second trimester',
        _ => 'Third trimester',
      };

  /// 0.0–1.0 across the 40-week bar.
  double get progress => (week / 40).clamp(0.0, 1.0);
}

PregnancyStatus? pregnancyStatusFor(DateTime? dueDate, {DateTime? now}) {
  if (dueDate == null) return null;
  final today = _dayOf(now ?? DateTime.now());
  final daysRemaining = _dayOf(dueDate).difference(today).inDays;
  final week = (40 - (daysRemaining / 7)).round().clamp(1, 42);
  return PregnancyStatus(dueDate: _dayOf(dueDate), week: week);
}

/// Due date from the first day of the last period: 40 weeks on.
DateTime dueDateFromLastPeriod(DateTime lastPeriodStart) =>
    _dayOf(lastPeriodStart).add(const Duration(days: 280));

// ── Providers ────────────────────────────────────────────────────────────

final cycleDaysProvider = StreamProvider<List<CycleDayRow>>(
  (ref) => ref.watch(databaseProvider).watchCycleDays(),
);

/// Today's cycle status, or null until days are logged.
final cycleStatusProvider = Provider<CycleStatus?>((ref) {
  final rows = ref.watch(cycleDaysProvider).valueOrNull;
  if (rows == null || rows.isEmpty) return null;
  return cycleStatusFrom(rows);
});

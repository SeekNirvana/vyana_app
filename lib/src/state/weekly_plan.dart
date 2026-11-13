part of '../../main.dart';

/// Item 46 — "My week": an optional weekly plan.
///
/// **Fully optional.** Every day starts empty, and with no plan nothing in
/// the app changes anywhere. Up to [kWeeklyPlanMaxPerDay] practices per
/// weekday, in the user's own order, chosen from the whole catalogue (not
/// only pins). The limit is on planning only: any number of practices can
/// still be done in a day, and unplanned ones never count against the plan.
/// Set in You; there is no plan UI on Home or Practice.

/// One weekday's plan, resolved to activities.
class PlannedDay {
  const PlannedDay({required this.weekday, required this.activityIds});

  /// 1 = Monday … 7 = Sunday.
  final int weekday;
  final List<String> activityIds;

  bool get isEmpty => activityIds.isEmpty;

  List<Activity> get activities => [
        for (final id in activityIds) ?activityById(id),
      ];
}

/// The whole plan, keyed by weekday. Empty when nothing is planned.
class WeeklyPlan {
  const WeeklyPlan(this.days);

  final Map<int, PlannedDay> days;

  static const WeeklyPlan empty = WeeklyPlan({});

  bool get isEmpty => days.values.every((d) => d.isEmpty);

  PlannedDay forWeekday(int weekday) =>
      days[weekday] ?? PlannedDay(weekday: weekday, activityIds: const []);

  PlannedDay forDay(DateTime day) => forWeekday(day.weekday);

  static WeeklyPlan fromRows(List<WeeklyPlanRow> rows) {
    final byDay = <int, List<WeeklyPlanRow>>{};
    for (final row in rows) {
      if (activityById(row.activityId) == null) continue;
      byDay.putIfAbsent(row.weekday, () => []).add(row);
    }
    return WeeklyPlan({
      for (final entry in byDay.entries)
        entry.key: PlannedDay(
          weekday: entry.key,
          activityIds: [
            for (final row in entry.value..sort(
                  (a, b) => a.position.compareTo(b.position),
                ))
              row.activityId,
          ],
        ),
    });
  }
}

final weeklyPlanRowsProvider = StreamProvider<List<WeeklyPlanRow>>(
  (ref) => ref.watch(databaseProvider).watchWeeklyPlan(),
);

final weeklyPlanProvider = Provider<WeeklyPlan>((ref) {
  final rows = ref.watch(weeklyPlanRowsProvider).valueOrNull;
  if (rows == null || rows.isEmpty) return WeeklyPlan.empty;
  return WeeklyPlan.fromRows(rows);
});

/// After this hour a planned practice stops being today's suggestion: it has
/// not happened, and the evening belongs to winding down.
const int kPlannedPracticeUntilHour = 22;

/// A planned practice whose usual start time is before this shows from 05:00
/// instead of 12:00, so an early trainer sees it when they train.
const int kPlannedMorningBeforeHour = 12;

/// When a plan reminder fires if the user has never done that practice.
const int kPlanReminderDefaultHour = 18;

/// Where a planned day stands right now.
class PlannedState {
  const PlannedState({
    required this.activityId,
    required this.index,
    required this.total,
  });

  final String activityId;

  /// 1-based position of this practice among the day's planned ones.
  final int index;
  final int total;

  /// "PLANNED · 2 OF 3 · YOUR USUAL 40 MIN" — no "1 OF 1" when only one is
  /// planned, which would read as a countdown with nothing to count.
  String meta(int usualMinutes) {
    final position = total > 1 ? 'PLANNED · $index OF $total' : 'PLANNED';
    return '$position · YOUR USUAL $usualMinutes MIN';
  }
}

/// The first planned practice not yet done today, or null when the plan is
/// empty, finished, or it is past [kPlannedPracticeUntilHour].
PlannedState? plannedStateFor({
  required WeeklyPlan plan,
  required DateTime now,
  required List<SessionRow> todaysFinished,
  required List<SessionRow> history,
}) {
  if (now.hour >= kPlannedPracticeUntilHour) return null;
  final day = plan.forDay(now);
  if (day.isEmpty) return null;

  final done = {for (final s in todaysFinished) s.vyanaActivityType};
  for (var i = 0; i < day.activityIds.length; i++) {
    final id = day.activityIds[i];
    // Unplanned practices done today never count against the plan, so only
    // the planned ids are checked here.
    if (done.contains(id)) continue;
    // Before noon only an early trainer's practice shows — otherwise the
    // morning keeps its short practice.
    if (now.hour < kPlannedMorningBeforeHour &&
        !_usuallyStartsBefore(id, history, kPlannedMorningBeforeHour)) {
      return null;
    }
    return PlannedState(
      activityId: id,
      index: i + 1,
      total: day.activityIds.length,
    );
  }
  return null;
}

/// The user's usual start hour for [activityId] — the median of past
/// sessions, or null when they have never done it.
int? usualStartHourFor(String activityId, List<SessionRow> history) {
  final hours = <int>[
    for (final s in history)
      if (s.vyanaActivityType == activityId) s.startedAt.hour,
  ]..sort();
  if (hours.isEmpty) return null;
  return hours[hours.length ~/ 2];
}

bool _usuallyStartsBefore(
  String activityId,
  List<SessionRow> history,
  int hour,
) {
  final usual = usualStartHourFor(activityId, history);
  return usual != null && usual < hour;
}

/// When the plan reminder should fire for [activityId]: the user's usual
/// start time, or [kPlanReminderDefaultHour] when they have never done it.
DateTime planReminderTimeFor({
  required String activityId,
  required DateTime day,
  required List<SessionRow> history,
}) {
  final hour = usualStartHourFor(activityId, history) ??
      kPlanReminderDefaultHour;
  return DateTime(day.year, day.month, day.day, hour);
}

/// A planned sport or strength day pre-sets Perform (still dashed until the
/// user confirms it). Otherwise the weekday-history rule stands.
DayIntent? plannedIntentFor(WeeklyPlan plan, DateTime now) {
  final day = plan.forDay(now);
  for (final a in day.activities) {
    if (a.cat == 'sport' || a.kind == 'strength') return DayIntent.perform;
  }
  return null;
}

/// "Remind me" — off by default. One notification on planned days, at the
/// usual start time of the first planned practice, and only if it is not
/// done yet.
class WeeklyPlanReminderController extends StateNotifier<bool> {
  WeeklyPlanReminderController(this._ref) : super(false) {
    unawaited(_load());
  }

  static const _key = 'vyana.plan.remind';
  static const int notificationId = 4307;

  final Ref _ref;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    state = prefs.getBool(_key) ?? false;
    await reschedule();
  }

  Future<void> setEnabled(bool on) async {
    state = on;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, on);
    await reschedule();
  }

  /// Re-arms (or cancels) the next reminder. Called when the switch changes,
  /// when the plan changes, and when a planned practice is finished.
  Future<void> reschedule() async {
    final notify = VitalsNotificationService.instance;
    if (!state) {
      await notify.cancelPlanReminder();
      return;
    }
    final plan = _ref.read(weeklyPlanProvider);
    if (plan.isEmpty) {
      await notify.cancelPlanReminder();
      return;
    }
    final sessions = await _ref.read(databaseProvider).recentSessions(
          limit: 400,
        );
    final history = [
      for (final s in sessions)
        if (s.endedAt != null) s,
    ];
    final now = DateTime.now();
    final todaysFinished = todaysFinishedSessions(sessions, now: now);

    // The next planned day with something still to do, today included.
    for (var ahead = 0; ahead < 7; ahead++) {
      final day = DateTime(now.year, now.month, now.day + ahead);
      final planned = plan.forDay(day);
      if (planned.isEmpty) continue;
      final done = ahead == 0
          ? {for (final s in todaysFinished) s.vyanaActivityType}
          : <String>{};
      final next = planned.activityIds.firstWhere(
        (id) => !done.contains(id),
        orElse: () => '',
      );
      if (next.isEmpty) continue;
      final at = planReminderTimeFor(
        activityId: next,
        day: day,
        history: history,
      );
      if (!at.isAfter(now)) continue;
      await notify.schedulePlanReminder(
        at: at,
        activityName: activityById(next)?.name ?? 'your practice',
      );
      return;
    }
    await notify.cancelPlanReminder();
  }
}

final weeklyPlanReminderProvider =
    StateNotifierProvider<WeeklyPlanReminderController, bool>(
  (ref) => WeeklyPlanReminderController(ref),
);

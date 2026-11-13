part of '../../main.dart';

/// What the user intends to do about today — the one *chosen* thing on Home,
/// as opposed to everything measured above the intent row.
///
/// Pre-set from the user's own weekday history (trains most Tuesdays → Tuesday
/// opens on Perform; Sunday is a rest day → Recover) and changed with one tap.
/// A pre-set intent *is* a selected intent: chip, read copy, practice tile and
/// play button all carry the intent colour on first paint.
enum DayIntent { recover, perform, settle }

extension DayIntentX on DayIntent {
  String get label => switch (this) {
        DayIntent.recover => 'Recover',
        DayIntent.perform => 'Perform',
        DayIntent.settle => 'Settle',
      };

  String get eyebrow => label.toUpperCase();

  Color hue(VyanaColors t) => switch (this) {
        DayIntent.recover => t.intentRecover,
        DayIntent.perform => t.intentPerform,
        DayIntent.settle => t.intentSettle,
      };

  Color soft(VyanaColors t) => switch (this) {
        DayIntent.recover => t.intentRecoverSoft,
        DayIntent.perform => t.intentPerformSoft,
        DayIntent.settle => t.intentSettleSoft,
      };

  static DayIntent? fromName(String? name) {
    if (name == null) return null;
    for (final i in DayIntent.values) {
      if (i.name == name) return i;
    }
    return null;
  }
}

/// Today's intent plus whether the user confirmed it. A pre-set intent is
/// still a selected intent (full colour on first paint); [confirmed] only
/// drives the dashed-vs-solid chip border.
class DayIntentState {
  const DayIntentState(this.intent, {required this.confirmed});
  final DayIntent? intent;
  final bool confirmed;
}

class DayIntentController extends StateNotifier<DayIntentState> {
  DayIntentController(this._ref)
      : super(const DayIntentState(null, confirmed: false)) {
    unawaited(_load());
    // Item 46: a planned sport day pre-sets Perform, but the pre-set is
    // derived once at launch — so planning a run in You left the chip on
    // whatever the weekday rule had already chosen. Re-derive when the plan
    // changes; a value the user confirmed is still never overwritten.
    _ref.listen<WeeklyPlan>(
      weeklyPlanProvider,
      (_, _) => unawaited(ensureToday()),
    );
  }

  DayIntent? get intent => state.intent;

  final Ref _ref;
  String? _loadedFor;
  bool _computing = false;

  static String _keyFor(DateTime day) =>
      'vyana.intent.${day.year}-${day.month}-${day.day}';

  static String _today() => _keyFor(DateTime.now());

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = DayIntentX.fromName(prefs.getString(_today()));
    _loadedFor = _today();
    if (stored != null) {
      state = DayIntentState(stored, confirmed: true);
      return;
    }
    await _preset();
  }

  /// Re-derive the pre-set when the day rolls over or ring data arrives; a
  /// value the user chose today is never overwritten. An unconfirmed pre-set
  /// is recomputed every time because the first one often runs before the
  /// cache hydrates, with no readiness score at all.
  Future<void> ensureToday() async {
    if (_loadedFor != _today()) {
      state = const DayIntentState(null, confirmed: false);
      await _load();
      return;
    }
    if (!state.confirmed) await _preset();
  }

  Future<void> _preset() async {
    if (_computing) return;
    _computing = true;
    try {
      final sessions =
          await _ref.read(databaseProvider).recentSessions(limit: 400);
      final ring = _ref.read(ringControllerProvider);
      final wellness = ring.currentWellnessState();
      final readiness = HomeDashboard.from(ring).readinessScore;
      // Item 46: a planned sport or strength day opens on Perform — still
      // dashed until the user confirms it. Otherwise the weekday rule stands.
      final planned = plannedIntentFor(
        _ref.read(weeklyPlanProvider),
        DateTime.now(),
      );
      if (planned != null) {
        if (mounted && !state.confirmed && state.intent != planned) {
          state = DayIntentState(planned, confirmed: false);
        }
        return;
      }
      final intent = presetIntent(
        now: DateTime.now(),
        sessionStarts: [
          for (final s in sessions)
            if (s.category == 'sport') s.startedAt,
        ],
        readiness: readiness,
        tense: wellness.signals.any(
          (s) => s.label == 'Calm' && s.tone == WellnessTone.watch,
        ),
      );
      if (mounted && !state.confirmed && state.intent != intent) {
        state = DayIntentState(intent, confirmed: false);
      }
    } finally {
      _computing = false;
    }
  }

  Future<void> set(DayIntent intent) async {
    state = DayIntentState(intent, confirmed: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_today(), intent.name);
  }
}

/// Pure pre-set rule, kept testable. Looks at the same weekday over the last
/// six weeks: a training habit on that weekday opens on Perform, a consistent
/// rest day on Recover. Without a weekday habit, the body decides: a tense
/// stress signal opens on Settle, low readiness on Recover, otherwise Perform.
DayIntent presetIntent({
  required DateTime now,
  required List<DateTime> sessionStarts,
  int? readiness,
  bool tense = false,
}) {
  final today = DateTime(now.year, now.month, now.day);
  var sameWeekdays = 0;
  var trained = 0;
  for (var week = 1; week <= 6; week++) {
    final day = today.subtract(Duration(days: 7 * week));
    sameWeekdays++;
    final didTrain = sessionStarts.any((s) =>
        s.year == day.year && s.month == day.month && s.day == day.day);
    if (didTrain) trained++;
  }
  final anyHistory = sessionStarts.any(
    (s) => today.difference(s).inDays <= 42,
  );
  if (readiness != null && readiness < 50) return DayIntent.recover;
  if (tense) return DayIntent.settle;
  if (anyHistory) {
    if (trained * 2 >= sameWeekdays) return DayIntent.perform;
    return DayIntent.recover;
  }
  if (readiness != null && readiness >= 70) return DayIntent.perform;
  return DayIntent.recover;
}

final dayIntentProvider =
    StateNotifierProvider<DayIntentController, DayIntentState>(
  (ref) => DayIntentController(ref),
);

/// One sentence describing the *day* rather than the numbers; changes with the
/// selected intent so the chosen half of Home reads as a plan, not a report.
String readSentenceFor(
  DayIntent intent,
  WellnessState state,
  HomeDashboard dashboard,
) {
  final score = dashboard.readinessScore;
  // Bug 36: before last night has arrived nothing is known about today, so
  // any sentence about capacity would be a guess dressed as a read.
  if (dashboard.syncPending) {
    return 'Your ring is still handing over last night. Today\'s read '
        'settles in shortly.';
  }
  final hasData = state.hasData || score != null;
  if (!hasData) {
    return 'Sync your ring and today\'s read settles in here.';
  }
  final low = score != null && score < 50;
  final high = score != null && score >= 70;
  switch (intent) {
    case DayIntent.recover:
      if (low) {
        return 'Your body is asking for rest. Today is for giving it that, '
            'not for pushing through.';
      }
      if (high) {
        return 'Your body did the repair work overnight. Today is for '
            'protecting it, not spending it.';
      }
      return 'A little below your best. Keep the day light and let recovery '
          'catch up on its own.';
    case DayIntent.perform:
      if (high) {
        return 'You have real capacity today. A hard session will land well '
            'and you\'ll absorb it.';
      }
      if (low) {
        return 'Capacity is thin today. If you train, keep it short and '
            'easy — the hard day will keep.';
      }
      return 'There is room for a steady session today. Save the hardest '
          'effort for a better-rested morning.';
    case DayIntent.settle:
      final tense = state.signals.any(
        (s) => s.label == 'Calm' && s.tone == WellnessTone.watch,
      );
      if (tense) {
        return 'Your system is running hot. Keep the day level and it will '
            'come back down on its own.';
      }
      return 'Nothing is pulling you off balance. Keep the day even and '
          'protect the calm you already have.';
  }
}

/// Today's suggested practice for an intent — the same practice on Home and
/// Practice, from one rule.
String suggestedPracticeFor(
  DayIntent intent,
  WellnessState state,
  int? readiness,
  HomeMoment moment,
) {
  // Recover → Yoga Nidra / body scan, Perform → HRV breathing (primes a hard
  // session), Settle → breathwork. Always a short practice — the suggestion
  // is a dose of four minutes or less, not a workout.
  switch (intent) {
    case DayIntent.recover:
      return moment == HomeMoment.day && readiness != null && readiness >= 50
          ? 'bodyScan'
          : 'yogaNidra';
    case DayIntent.perform:
      return 'hrvBreathing';
    case DayIntent.settle:
      return 'breathwork';
  }
}

// ── The day's suggestion (bug 45) ─────────────────────────────────────────
// One card, in one place, choosing by HomeMoment. The morning keeps the short
// practice it always had; the afternoon suggests something the user actually
// does; the evening winds down. One rule, so Home and the Practice tab can
// never show two different "suggested today".

/// Gentle movement — what Recover suggests, and the only thing suggested at
/// all when readiness is under [kGentleOnlyReadiness].
const Set<String> kGentlePracticeIds = {
  'walk',
  'yogaFlow',
  'stretching',
  'mobility',
  'swimming',
};

/// What Settle suggests during the day.
const Set<String> kSettlePracticeIds = {'walk', 'yogaFlow', 'walkingMed'};

/// Below this, only gentle practices are suggested whatever the intent.
const int kGentleOnlyReadiness = 50;

/// The evening rotation, in order, at their catalogue lengths.
const List<String> kWindDownRotation = ['bodyScan', 'yogaNidra', 'soundBath'];

/// After this hour the wind-down may be Lucid Dreaming instead, on alternate
/// nights — it is a pre-sleep practice, so it is wrong at 18:00.
const int kLucidDreamingFromHour = 21;

/// What the suggestion card shows right now.
class HomeSuggestion {
  const HomeSuggestion({
    required this.activityId,
    required this.heading,
    required this.reason,
    required this.minutes,
    this.meta,
    this.offerPin = false,
    this.setsTarget = true,
    this.lowReadinessAlternative,
  });

  final String activityId;

  /// "Suggested practice" · "Suggested activity" · "Wind down" ·
  /// "Planned today" (item 46).
  final String heading;

  final String reason;

  /// What the card opens with. The morning slot is capped at
  /// [kSuggestedMaxMinutes]; the others use the practice's own length.
  final int minutes;

  /// The mono line in the card — "YOUR USUAL · 32 MIN", "PLANNED · 2 OF 3".
  final String? meta;

  /// Bug 45: shown when the suggestion came from a fallback rather than a
  /// pin, so the user can make it a pin in one tap.
  final bool offerPin;

  /// The day slot opens the practice with no target set.
  final bool setsTarget;

  /// Item 46: a gentler practice offered under a planned one on a low
  /// readiness day. Never swapped silently.
  final String? lowReadinessAlternative;

  Activity get activity =>
      activityById(activityId) ?? activityById('breathwork')!;
}

/// Suggested length in minutes — always four or less. A suggestion is the
/// smallest useful dose (rest 4 · prime 2 · settle 3), never the catalogue's
/// full default; the user can lengthen it on the activity screen.
///
/// Bug 45: the cap applies to the **morning slot only**. A 4-minute cap on an
/// afternoon walk or an evening Yoga Nidra would make both meaningless.
const int kSuggestedMaxMinutes = 4;

int suggestedMinutesFor(DayIntent intent, Activity activity) {
  final short = switch (intent) {
    DayIntent.recover => 4,
    DayIntent.perform => 2,
    DayIntent.settle => 3,
  };
  return math.min(math.min(short, kSuggestedMaxMinutes), activity.dur);
}

/// Whether [a] is something to suggest for [intent] right now.
bool _fitsIntent(Activity a, DayIntent intent, int? readiness) {
  // The safety rule first: a tired body gets gentle whatever the chip says.
  final gentleOnly = readiness != null && readiness < kGentleOnlyReadiness;
  if (gentleOnly) return kGentlePracticeIds.contains(a.id);
  return switch (intent) {
    DayIntent.perform => a.cat == 'sport' || a.kind == 'strength',
    DayIntent.recover => kGentlePracticeIds.contains(a.id),
    DayIntent.settle => kSettlePracticeIds.contains(a.id),
  };
}

/// The mindfulness practice each intent falls back to when the user has no
/// history to suggest from. Catalogue length, catalogue practice.
String _mindfulnessFallback(DayIntent intent, int? readiness) {
  if (readiness != null && readiness < kGentleOnlyReadiness) return 'bodyScan';
  return switch (intent) {
    DayIntent.recover => 'bodyScan',
    DayIntent.perform => 'hrvBreathing',
    DayIntent.settle => 'walkingMed',
  };
}

/// "YOUR USUAL · 32 MIN" — the median of the user's last five sessions of
/// this practice, or the catalogue default when they have never done it.
int usualMinutesFor(String activityId, List<SessionRow> history) {
  final durations = <int>[
    for (final s in history)
      if (s.vyanaActivityType == activityId && s.endedAt != null)
        s.endedAt!.difference(s.startedAt).inMinutes,
  ].where((m) => m > 0).take(5).toList()
    ..sort();
  if (durations.isEmpty) {
    return activityById(activityId)?.dur ?? kSuggestedMaxMinutes;
  }
  return durations[durations.length ~/ 2];
}

/// The wind-down practice for [now]. Rotates day by day so the evening is not
/// the same twenty minutes for ever; after [kLucidDreamingFromHour] it is
/// Lucid Dreaming on alternate nights.
String windDownFor(DateTime now) {
  final day = int.parse(
    '${now.year}${now.month.toString().padLeft(2, '0')}'
    '${now.day.toString().padLeft(2, '0')}',
  );
  if (now.hour >= kLucidDreamingFromHour && day.isEven) {
    return kLucidDreamingId;
  }
  return kWindDownRotation[day % kWindDownRotation.length];
}

/// A gentler practice to offer beside a planned one on a low-readiness day
/// (item 46). Uses the same gentle rule as the day slot.
String? _gentleAlternativeFor(
  DayIntent intent,
  List<String> pins,
  List<SessionRow> todaysFinished,
) {
  final done = {for (final s in todaysFinished) s.vyanaActivityType};
  for (final id in pins) {
    if (kGentlePracticeIds.contains(id) && !done.contains(id)) return id;
  }
  for (final id in kGentlePracticeIds) {
    if (!done.contains(id)) return id;
  }
  return null;
}

/// The whole rule behind the one suggestion card (bug 45), pure so Home, the
/// Practice tab and the tests all read the same answer.
///
/// [history] is every finished session, newest first. [todaysFinished] is
/// today's, so a practice already done is not suggested again.
HomeSuggestion homeSuggestionFor({
  required DayIntent intent,
  required WellnessState state,
  required int? readiness,
  required HomeMoment moment,
  required DateTime now,
  List<String> pins = const [],
  List<SessionRow> history = const [],
  List<SessionRow> todaysFinished = const [],
  WeeklyPlan plan = WeeklyPlan.empty,
}) {
  // Item 46: a planned day replaces the day suggestion, and the morning's
  // short practice too when the user usually trains before noon. Each stays
  // until it is done or 22:00 — after that the evening wind-down takes over.
  final planned = plannedStateFor(
    plan: plan,
    now: now,
    todaysFinished: todaysFinished,
    history: history,
  );
  if (planned != null) {
    final usual = usualMinutesFor(planned.activityId, history);
    final gentle = readiness != null && readiness < kGentleOnlyReadiness
        ? _gentleAlternativeFor(intent, pins, todaysFinished)
        : null;
    return HomeSuggestion(
      activityId: planned.activityId,
      heading: 'Planned today',
      reason: suggestedReasonFor(intent, readiness),
      minutes: usual,
      meta: planned.meta(usual),
      setsTarget: false,
      // Never swapped silently: the plan stands, with one line underneath.
      lowReadinessAlternative: gentle,
    );
  }

  switch (moment) {
    case HomeMoment.morning:
      // Unchanged: the short practice, four minutes or less.
      final id = suggestedPracticeFor(intent, state, readiness, moment);
      final activity = activityById(id) ?? activityById('breathwork')!;
      return HomeSuggestion(
        activityId: id,
        heading: 'Suggested practice',
        reason: suggestedReasonFor(intent, readiness),
        minutes: suggestedMinutesFor(intent, activity),
      );

    case HomeMoment.night:
      final id = windDownFor(now);
      return HomeSuggestion(
        activityId: id,
        heading: 'Wind down',
        reason: 'Helps your body and mind settle before sleep',
        minutes: activityById(id)?.dur ?? 15,
      );

    case HomeMoment.day:
      final doneToday = {
        for (final s in todaysFinished) s.vyanaActivityType,
      };
      bool usable(String id) {
        final a = activityById(id);
        return a != null &&
            !doneToday.contains(id) &&
            _fitsIntent(a, intent, readiness);
      }

      HomeSuggestion day(String id, {required bool offerPin}) =>
          HomeSuggestion(
            activityId: id,
            heading: 'Suggested activity',
            reason: suggestedReasonFor(intent, readiness),
            minutes: usualMinutesFor(id, history),
            meta: 'YOUR USUAL · ${usualMinutesFor(id, history)} MIN',
            offerPin: offerPin,
            // The day slot opens the practice with no target set.
            setsTarget: false,
          );

      // 1 · a pin that fits.
      for (final id in pins) {
        if (usable(id)) return day(id, offerPin: false);
      }
      // 2 · something done before, most recent first, even if not pinned.
      final seen = <String>{};
      for (final s in history) {
        final id = s.vyanaActivityType;
        if (!seen.add(id)) continue;
        if (usable(id)) return day(id, offerPin: true);
      }
      // 3 · a mindfulness practice from the catalogue, at its own length.
      final id = _mindfulnessFallback(intent, readiness);
      return HomeSuggestion(
        activityId: id,
        heading: 'Suggested activity',
        reason: suggestedReasonFor(intent, readiness),
        minutes: activityById(id)?.dur ?? kSuggestedMaxMinutes,
        meta: 'YOUR USUAL · ${activityById(id)?.dur ?? 0} MIN',
        offerPin: true,
        setsTarget: false,
      );
  }
}

/// The one-line reason under the suggested-practice heading.
String suggestedReasonFor(DayIntent intent, int? readiness) {
  switch (intent) {
    case DayIntent.recover:
      return readiness != null && readiness < 50
          ? 'Gives your body the rest it is asking for'
          : 'Holds the recovery you already earned';
    case DayIntent.perform:
      return 'Primes you before a hard session';
    case DayIntent.settle:
      return 'Brings a climbing stress line down fastest';
  }
}

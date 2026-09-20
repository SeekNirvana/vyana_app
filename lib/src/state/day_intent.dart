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

/// Suggested length in minutes — always four or less. A suggestion is the
/// smallest useful dose (rest 4 · prime 2 · settle 3), never the catalogue's
/// full default; the user can lengthen it on the activity screen.
const int kSuggestedMaxMinutes = 4;

int suggestedMinutesFor(DayIntent intent, Activity activity) {
  final short = switch (intent) {
    DayIntent.recover => 4,
    DayIntent.perform => 2,
    DayIntent.settle => 3,
  };
  return math.min(math.min(short, kSuggestedMaxMinutes), activity.dur);
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

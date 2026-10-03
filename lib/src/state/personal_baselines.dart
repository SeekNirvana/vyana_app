part of '../../main.dart';

/// §14 — "typical adult" → "your own normal".
///
/// Every verdict used to be a fixed population rule, so someone whose normal
/// is a 5h 40m night or a naturally low HRV read as permanently short-slept or
/// stressed however they felt. The fix is two phases and one question.
///
/// Days 1–14 the base is a typical adult, written `−17 vs typical 55`. From
/// day 14 the base is the user's own 30-day average, written `+2 vs base 36`.
/// A vital that sits outside its typical range but *steadily* is probably that
/// person's normal, so Nova asks — about the feeling, never the number — and
/// only an answer that says "this is fine" adopts the personal range.

/// The four vitals a personal baseline applies to. Stress is included because
/// it is derived from HRV, so it inherits HRV's personalisation (bug 7).
enum BaselineVital { hrv, restingHr, sleep, stress }

extension BaselineVitalX on BaselineVital {
  String get storageKey => name;

  /// The row label this baseline sits under.
  String get label => switch (this) {
        BaselineVital.hrv => 'HRV',
        BaselineVital.restingHr => 'Resting HR',
        BaselineVital.sleep => 'Sleep',
        BaselineVital.stress => 'Stress',
      };

  /// Stress and resting HR share one question — they are the same complaint
  /// ("your readings say stressed") read off two rows.
  BaselineVital get questionGroup =>
      this == BaselineVital.stress ? BaselineVital.restingHr : this;
}

/// What the user said when Nova asked about a vital.
enum BaselineAnswer {
  /// Never asked, or the answer expired.
  none,

  /// "I have felt calm" / "Mostly rested" → adopt the personal range.
  adopted,

  /// "It has been a lot" / "Usually tired" → the reading is real, keep typical.
  kept,

  /// "Not sure" / "It varies" / dismissed → keep typical, ask again later.
  deferred,
}

extension BaselineAnswerX on BaselineAnswer {
  /// How the answer reads in You, where it stays editable.
  String get label => switch (this) {
        BaselineAnswer.none => 'Not asked yet',
        BaselineAnswer.adopted => 'This is my normal',
        BaselineAnswer.kept => 'It is a real signal',
        BaselineAnswer.deferred => 'Not sure yet',
      };

  static BaselineAnswer fromStored(String? value) {
    for (final a in BaselineAnswer.values) {
      if (a.name == value) return a;
    }
    return BaselineAnswer.none;
  }
}

/// A deferred answer is re-asked after this long, not sooner.
const Duration kBaselineReaskAfter = Duration(days: 14);

/// Days of ring data before the base switches from typical to personal.
const int kBaselineLearningDays = 14;

/// Days of history the personal base averages over, once learned.
const int kBaselineWindowDays = 30;

/// Nova only asks when a vital is atypical on at least this many of the last
/// [kBaselineLearningDays] days.
const int kBaselineAtypicalDaysNeeded = 10;

/// …and only when it is steady: the spread stays inside this fraction of the
/// typical range's width. Erratic readings are a real signal, not a normal.
const double kBaselineSteadySpread = 0.6;

/// One vital's stored decision.
class BaselineRecord {
  const BaselineRecord({
    required this.vital,
    this.answer = BaselineAnswer.none,
    this.decidedAt,
  });

  final BaselineVital vital;
  final BaselineAnswer answer;
  final DateTime? decidedAt;

  bool get adopted => answer == BaselineAnswer.adopted;

  /// A deferred answer becomes askable again after [kBaselineReaskAfter].
  bool get askable {
    switch (answer) {
      case BaselineAnswer.none:
        return true;
      case BaselineAnswer.deferred:
        final at = decidedAt;
        return at == null || DateTime.now().difference(at) > kBaselineReaskAfter;
      case BaselineAnswer.adopted:
      case BaselineAnswer.kept:
        return false;
    }
  }

  Map<String, dynamic> toJson() => {
        'answer': answer.name,
        if (decidedAt != null) 'decidedAt': decidedAt!.toIso8601String(),
      };

  factory BaselineRecord.fromJson(BaselineVital vital, Map<String, dynamic> j) {
    return BaselineRecord(
      vital: vital,
      answer: BaselineAnswerX.fromStored(j['answer']?.toString()),
      decidedAt: DateTime.tryParse(j['decidedAt']?.toString() ?? ''),
    );
  }
}

class PersonalBaselinesState {
  const PersonalBaselinesState({
    this.records = const {},
    this.firstDataDay,
    this.lastAskedOn,
  });

  final Map<BaselineVital, BaselineRecord> records;

  /// The first day ring data exists for — day 1 of the learning phase.
  final DateTime? firstDataDay;

  /// Nova asks at most one baseline question per day.
  final DateTime? lastAskedOn;

  BaselineRecord recordFor(BaselineVital v) =>
      records[v] ?? BaselineRecord(vital: v);

  /// Stress follows HRV's decision, since it is computed from HRV.
  bool adopted(BaselineVital v) => recordFor(
        v == BaselineVital.stress ? BaselineVital.hrv : v,
      ).adopted;

  /// Day n of [kBaselineLearningDays], or null once learning is done.
  int? get learningDay {
    final start = firstDataDay;
    if (start == null) return null;
    final elapsed = DateTime.now().difference(start).inDays + 1;
    if (elapsed > kBaselineLearningDays) return null;
    return elapsed.clamp(1, kBaselineLearningDays);
  }

  bool get isLearning => learningDay != null;

  bool get askedToday {
    final at = lastAskedOn;
    if (at == null) return false;
    final now = DateTime.now();
    return at.year == now.year && at.month == now.month && at.day == now.day;
  }

  PersonalBaselinesState copyWith({
    Map<BaselineVital, BaselineRecord>? records,
    DateTime? firstDataDay,
    DateTime? lastAskedOn,
  }) {
    return PersonalBaselinesState(
      records: records ?? this.records,
      firstDataDay: firstDataDay ?? this.firstDataDay,
      lastAskedOn: lastAskedOn ?? this.lastAskedOn,
    );
  }
}

class PersonalBaselinesController
    extends StateNotifier<PersonalBaselinesState> {
  PersonalBaselinesController() : super(const PersonalBaselinesState()) {
    unawaited(_load());
  }

  static const _key = 'vyana.baselines';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_key);
    if (encoded == null || encoded.isEmpty) return;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return;
      final records = <BaselineVital, BaselineRecord>{};
      final raw = decoded['records'];
      if (raw is Map) {
        for (final v in BaselineVital.values) {
          final entry = raw[v.storageKey];
          if (entry is Map) {
            records[v] = BaselineRecord.fromJson(
              v,
              Map<String, dynamic>.from(entry),
            );
          }
        }
      }
      if (!mounted) return;
      state = PersonalBaselinesState(
        records: records,
        firstDataDay:
            DateTime.tryParse(decoded['firstDataDay']?.toString() ?? ''),
        lastAskedOn:
            DateTime.tryParse(decoded['lastAskedOn']?.toString() ?? ''),
      );
    } catch (_) {
      // A corrupt block must not block the app: fall back to typical ranges.
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'records': {
          for (final e in state.records.entries)
            e.key.storageKey: e.value.toJson(),
        },
        if (state.firstDataDay != null)
          'firstDataDay': state.firstDataDay!.toIso8601String(),
        if (state.lastAskedOn != null)
          'lastAskedOn': state.lastAskedOn!.toIso8601String(),
      }),
    );
  }

  /// Records the oldest day ring data covers, so the learning phase counts
  /// from real data rather than from install.
  Future<void> noteDataStart(DateTime day) async {
    final existing = state.firstDataDay;
    final normalised = DateTime(day.year, day.month, day.day);
    if (existing != null && !normalised.isBefore(existing)) return;
    state = state.copyWith(firstDataDay: normalised);
    await _persist();
  }

  Future<void> answer(BaselineVital vital, BaselineAnswer answer) async {
    final now = DateTime.now();
    final next = {...state.records};
    // Stress and resting HR are answered together, as they are asked together.
    final group = <BaselineVital>[
      vital,
      if (vital == BaselineVital.restingHr) BaselineVital.stress,
      if (vital == BaselineVital.hrv) BaselineVital.stress,
    ];
    for (final v in group) {
      next[v] = BaselineRecord(vital: v, answer: answer, decidedAt: now);
    }
    state = state.copyWith(records: next, lastAskedOn: now);
    await _persist();
  }

  /// Marks a question as shown, so only one is asked per day.
  /// Pushes the sleep target into [sleepScoreDurationTarget] so every score
  /// in the app — Home's verdict, Metrics, readiness — agrees. Called after a
  /// load or an answer, with the user's own recent nights.
  void applySleepTarget(List<int> recentAsleepSeconds) {
    sleepScoreDurationTarget = sleepDurationTarget(
      baselines: state,
      recentAsleepSeconds: recentAsleepSeconds,
    );
  }

  Future<void> markAsked() async {
    state = state.copyWith(lastAskedOn: DateTime.now());
    await _persist();
  }
}

final personalBaselinesProvider =
    StateNotifierProvider<PersonalBaselinesController, PersonalBaselinesState>(
  (_) => PersonalBaselinesController(),
);

// ── The base a row is judged against ─────────────────────────────────────

/// What a vitals row compares today's value to, and how it says so.
class VitalBase {
  const VitalBase({
    required this.value,
    required this.range,
    required this.isPersonal,
  });

  /// The number the delta is measured from.
  final double value;

  /// The range that decides the colour — the user's own once adopted, else
  /// the typical window, which stays visible in the caption either way.
  final VitalReferenceRange range;

  final bool isPersonal;

  /// `vs base 36` once personal, `vs typical 55` while learning.
  String get deltaSuffix =>
      isPersonal ? 'vs base ${value.round()}' : 'vs typical ${value.round()}';
}

/// Midpoint of a typical range — the placeholder base for the learning phase.
/// §15 leaves age/sex norms open for want of a source; the midpoint is what
/// the mock uses and it keeps the delta honest in the meantime.
double typicalBaseFor(VitalReferenceRange range) => (range.low + range.high) / 2;

/// The base for [vital]: the user's own average once there is enough history
/// and (for an atypical vital) they have said it is their normal; otherwise
/// the typical midpoint.
///
/// [personalAverage] is the caller's own [kBaselineWindowDays] mean, and
/// [personalRange] their own spread (e.g. 10th–90th percentile).
VitalBase vitalBaseFor({
  required BaselineVital vital,
  required VitalReferenceRange typical,
  required PersonalBaselinesState baselines,
  double? personalAverage,
  VitalReferenceRange? personalRange,
}) {
  final learned = !baselines.isLearning && personalAverage != null;
  if (!learned) {
    return VitalBase(
      value: typicalBaseFor(typical),
      range: typical,
      isPersonal: false,
    );
  }
  // Past the learning phase the delta is always measured from the user's own
  // average — that is just arithmetic about their history. The *colour* only
  // moves to their own range once they have said the readings are normal.
  final adopted = baselines.adopted(vital);
  return VitalBase(
    value: personalAverage,
    range: adopted ? (personalRange ?? typical) : typical,
    isPersonal: true,
  );
}

// ── When Nova asks ───────────────────────────────────────────────────────

/// A question Nova is ready to ask about one vital's normal.
class BaselineQuestion {
  const BaselineQuestion({
    required this.vital,
    required this.prompt,
    required this.options,
  });

  final BaselineVital vital;
  final String prompt;

  /// Answer label → what it means.
  final List<(String, BaselineAnswer)> options;
}

/// Pure candidacy rule, kept testable: a vital qualifies when it sits outside
/// its typical range on at least [kBaselineAtypicalDaysNeeded] of the last
/// [kBaselineLearningDays] days *and* holds steady while doing so.
bool baselineQuestionDue({
  required List<double> recentValues,
  required VitalReferenceRange typical,
}) {
  if (recentValues.length < kBaselineLearningDays) return false;
  final window = recentValues.take(kBaselineLearningDays).toList();
  final atypical = window
      .where((v) => v < typical.low || v > typical.high)
      .length;
  if (atypical < kBaselineAtypicalDaysNeeded) return false;
  final spread = window.reduce(math.max) - window.reduce(math.min);
  final width = (typical.high - typical.low).abs();
  if (width <= 0) return false;
  return spread <= width * kBaselineSteadySpread;
}

/// The question for [vital], with its counts computed from the data rather
/// than written into the copy. Asks about the feeling, never the value.
BaselineQuestion baselineQuestionFor(
  BaselineVital vital, {
  required int atypicalDays,
  required int windowDays,
  String? usualSleepLabel,
}) {
  switch (vital) {
    case BaselineVital.sleep:
      return BaselineQuestion(
        vital: BaselineVital.sleep,
        prompt: 'You have slept about ${usualSleepLabel ?? 'the same'} on most '
            'nights. Do you usually wake up feeling rested?',
        options: const [
          ('Mostly rested', BaselineAnswer.adopted),
          ('Usually tired', BaselineAnswer.kept),
          ('It varies', BaselineAnswer.deferred),
        ],
      );
    case BaselineVital.restingHr:
    case BaselineVital.stress:
      return BaselineQuestion(
        vital: BaselineVital.restingHr,
        prompt: 'Your readings have said stressed on $atypicalDays of the last '
            '$windowDays days. Has it felt that way to you?',
        options: const [
          ('No, I have felt calm', BaselineAnswer.adopted),
          ('Yes, it has been a lot', BaselineAnswer.kept),
          ('Not sure', BaselineAnswer.deferred),
        ],
      );
    case BaselineVital.hrv:
      return BaselineQuestion(
        vital: BaselineVital.hrv,
        prompt: 'Your recovery readings have been low on $atypicalDays of the '
            'last $windowDays days. Has it felt that way to you?',
        options: const [
          ('No, I have felt fine', BaselineAnswer.adopted),
          ('Yes, I have felt worn out', BaselineAnswer.kept),
          ('Not sure', BaselineAnswer.deferred),
        ],
      );
  }
}

// ── Safety floor ─────────────────────────────────────────────────────────

/// Never personalised, whatever the user has adopted: these are the readings
/// that matter clinically, and a personal "normal" must not hide them.
/// SpO₂ below this is always flagged.
const int kSafetySpo2Floor = 92;

/// Resting HR this far above the top of the band is always flagged.
const int kSafetyRestingHrMargin = 20;

/// True when a reading must be shown as a concern regardless of any adopted
/// personal range. [restingHrBandHigh] is the top of the user's own band.
bool breachesSafetyFloor({
  int? spo2,
  int? restingHr,
  double? restingHrBandHigh,
  bool afib = false,
}) {
  if (afib) return true;
  if (spo2 != null && spo2 > 0 && spo2 < kSafetySpo2Floor) return true;
  if (restingHr != null && restingHrBandHigh != null) {
    if (restingHr > restingHrBandHigh + kSafetyRestingHrMargin) return true;
  }
  return false;
}

// ── Sleep: the duration target follows the user's usual night ────────────

/// Shortest personal sleep target. Below this we keep the population target:
/// adopting a four-hour night as "normal" would score real deprivation as
/// fine, which is exactly what the safety floor exists to prevent.
const Duration kPersonalSleepFloor = Duration(hours: 6);

/// The duration the sleep score's 45 duration points are measured against.
///
/// Eight hours until the user says a shorter night leaves them rested, then
/// their own 14-night median (floored at [kPersonalSleepFloor]), so a normal
/// night stops scoring as short.
Duration sleepDurationTarget({
  required PersonalBaselinesState baselines,
  List<int> recentAsleepSeconds = const [],
}) {
  const fallback = Duration(hours: 8);
  if (!baselines.recordFor(BaselineVital.sleep).adopted) return fallback;
  if (recentAsleepSeconds.isEmpty) return fallback;
  final sorted = [...recentAsleepSeconds]..sort();
  final median = sorted[sorted.length ~/ 2];
  final personal = Duration(seconds: median);
  return personal < kPersonalSleepFloor ? kPersonalSleepFloor : personal;
}

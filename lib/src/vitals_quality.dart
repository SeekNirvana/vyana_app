part of '../main.dart';

/// Plausibility gates for ring vitals, so loose-contact garbage (all-zero
/// records) and sensor artefacts (e.g. HRV pinned at 175–179 ms) never reach
/// the user as a spooky reading, a polluted chart, or a skewed average.
///
/// Ranges are grounded in real PRANA ring data pulled from the device:
///   HR 48–139, SpO2 95–98 (0 = no contact), HRV normal 21–90 with a bogus
///   saturation cluster at 175–179, temp 35.5–37.0 (0.15 = no contact),
///   glucose 4.1–8.5 (0 = no contact), respiration always 0 (not supported).

// Inclusive plausible bounds per metric.
const int kHeartRateMin = 30;
const int kHeartRateMax = 220;
const int kSpo2Min = 70;
const int kSpo2Max = 100;
const int kHrvMin = 10;
const int kHrvMax = 150;
const double kGlucoseMin = 2.0;
const double kGlucoseMax = 35.0;
const int kRespirationMin = 4;
const int kRespirationMax = 45;
const int kUricAcidMin = 80;
const int kUricAcidMax = 900;
const double kCholesterolMin = 1.5;
const double kCholesterolMax = 15.0;
const int kSystolicMin = 60;
const int kSystolicMax = 260;
const int kDiastolicMin = 40;
const int kDiastolicMax = 160;

int? _inIntRange(int? v, int min, int max) =>
    (v == null || v < min || v > max) ? null : v;
double? _inDoubleRange(double? v, double min, double max) =>
    (v == null || v < min || v > max) ? null : v;

int? plausibleHeartRate(int? v) => _inIntRange(v, kHeartRateMin, kHeartRateMax);
int? plausibleSpo2(int? v) => _inIntRange(v, kSpo2Min, kSpo2Max);
int? plausibleHrv(int? v) => _inIntRange(v, kHrvMin, kHrvMax);
int? plausibleRespiration(int? v) =>
    _inIntRange(v, kRespirationMin, kRespirationMax);
int? plausibleUricAcid(int? v) => _inIntRange(v, kUricAcidMin, kUricAcidMax);
double? plausibleGlucose(double? v) =>
    _inDoubleRange(v, kGlucoseMin, kGlucoseMax);
double? plausibleCholesterol(double? v) =>
    _inDoubleRange(v, kCholesterolMin, kCholesterolMax);

/// Chart-filter form (operates on the `double?` a series reads from a record).
double? validHeartRateValue(double? v) =>
    _inDoubleRange(v, kHeartRateMin.toDouble(), kHeartRateMax.toDouble());
double? validSpo2Value(double? v) =>
    _inDoubleRange(v, kSpo2Min.toDouble(), kSpo2Max.toDouble());
double? validHrvValue(double? v) =>
    _inDoubleRange(v, kHrvMin.toDouble(), kHrvMax.toDouble());
double? validGlucoseValue(double? v) =>
    _inDoubleRange(v, kGlucoseMin, kGlucoseMax);
double? validUricAcidValue(double? v) =>
    _inDoubleRange(v, kUricAcidMin.toDouble(), kUricAcidMax.toDouble());
double? validCholesterolValue(double? v) =>
    _inDoubleRange(v, kCholesterolMin, kCholesterolMax);
double? validSystolicValue(double? v) =>
    _inDoubleRange(v, kSystolicMin.toDouble(), kSystolicMax.toDouble());
double? validTemperatureValue(double? v) => validTemperature(v);

/// Per-field validators keyed by the record field name, used to physically
/// scrub implausible values out of stored records (see [RingHistory.sanitized]).
const Map<String, double? Function(double?)> _fieldValidators = {
  'heartRate': validHeartRateValue,
  'bloodOxygen': validSpo2Value,
  'hrv': validHrvValue,
  'temperature': validTemperatureValue,
  'bloodGlucose': validGlucoseValue,
  'uricAcid': validUricAcidValue,
  'totalCholesterol': validCholesterolValue,
};

/// Returns a copy of [record] with any implausible numeric fields removed, so a
/// bogus HRV of 179 (in an otherwise-good record) never persists. Non-map
/// records or records with nothing to scrub are returned unchanged.
dynamic scrubRecordFields(dynamic record) {
  if (record is! Map) return record;
  Map<dynamic, dynamic>? copy;
  _fieldValidators.forEach((field, validate) {
    if (!record.containsKey(field)) return;
    final raw = readDouble(record, [field]);
    if (raw == null) return;
    if (validate(raw) == null) {
      copy ??= Map<dynamic, dynamic>.from(record);
      copy!.remove(field);
    }
  });
  return copy ?? record;
}

/// Validated "SYS/DIA" text, or null if either bound is implausible.
String? plausibleBloodPressure(String? text) {
  if (text == null) return null;
  final parts = text.split('/');
  if (parts.length != 2) return null;
  final sys = int.tryParse(parts[0].trim());
  final dia = int.tryParse(parts[1].trim());
  if (_inIntRange(sys, kSystolicMin, kSystolicMax) == null) return null;
  if (_inIntRange(dia, kDiastolicMin, kDiastolicMax) == null) return null;
  return text;
}

/// A combined-vitals record where the sensor clearly had no skin contact:
/// heart rate, SpO2 and HRV all read zero, or the temperature is impossibly
/// low. Such records must be dropped whole — every field in them is garbage.
bool isNoContactRecord(dynamic record) {
  final hr = readInt(record, const ['heartRate']) ?? 0;
  final spo2 = readInt(record, const ['bloodOxygen']) ?? 0;
  final hrv = readInt(record, const ['hrv']) ?? 0;
  if (hr == 0 && spo2 == 0 && hrv == 0) return true;
  final temp = readDouble(record, const ['temperature']);
  if (temp != null && temp > 0 && temp < 30) return true;
  return false;
}

/// Newest plausible value for [fields] across [records], skipping no-contact
/// records and out-of-range values. Used to build the "current vitals" so a
/// single bad reading never becomes the headline number.
double? latestPlausibleValue(
  List<dynamic> records,
  List<String> fields,
  double? Function(double?) validate, {
  bool skipNoContact = true,
}) {
  final sorted = [...records]
    ..sort((a, b) => (timestampOf(b) ?? 0).compareTo(timestampOf(a) ?? 0));
  for (final record in sorted) {
    if (skipNoContact && isNoContactRecord(record)) continue;
    final value = validate(readDouble(record, fields));
    if (value != null) return value;
  }
  return null;
}

int? latestPlausibleInt(
  List<dynamic> records,
  List<String> fields,
  double? Function(double?) validate,
) =>
    latestPlausibleValue(records, fields, validate)?.round();

/// Newest plausible "SYS/DIA" reading across [records].
String? latestPlausibleBloodPressure(List<dynamic> records) {
  final sorted = [...records]
    ..sort((a, b) => (timestampOf(b) ?? 0).compareTo(timestampOf(a) ?? 0));
  for (final record in sorted) {
    final text = plausibleBloodPressure(pressureText(record));
    if (text != null) return text;
  }
  return null;
}

// ── Stress, derived from HRV ──────────────────────────────────────────────
// The ring does not store a stress/"pressure" series, so we express stress the
// way these rings compute it internally — inversely from HRV. This gives a
// series that populates and refreshes whenever HRV syncs.

enum StressZone { calm, activated, stressed }

/// 0.0 (deeply calm) → 1.0 (highly stressed), from an HRV value in ms.
///
/// Bug 7: the fixed `(90 − hrv) / 70` scale is the same for everyone, so
/// anyone whose normal HRV sits low — common with age, or a naturally higher
/// resting HR — read as permanently Activated however calm they felt. Pass
/// [personalRange] (the user's own HRV spread) to score the deviation from
/// their own normal instead; without one the population scale still applies,
/// which is correct until a baseline exists.
double stressLevelForHrv(double hrv, {VitalReferenceRange? personalRange}) {
  final range = personalRange;
  if (range != null && range.high > range.low) {
    // Their own range maps to the same 0–1 scale, inverted: at or above the
    // top of their normal band is calm, at or below the bottom is stressed.
    return ((range.high - hrv) / (range.high - range.low)).clamp(0.0, 1.0);
  }
  return ((90 - hrv) / 70).clamp(0.0, 1.0);
}

/// The user's own HRV range from their history, as the 10th–90th percentile —
/// the spread §14 adopts for colour once they confirm it is their normal.
/// Null until there are enough days to be meaningful.
VitalReferenceRange? personalHrvRange(
  List<double> dailyValues, {
  int minDays = kBaselineLearningDays,
}) {
  if (dailyValues.length < minDays) return null;
  final sorted = [...dailyValues]..sort();
  double percentile(double p) {
    final idx = ((sorted.length - 1) * p).round().clamp(0, sorted.length - 1);
    return sorted[idx];
  }

  final low = percentile(0.1);
  final high = percentile(0.9);
  if (high <= low) return null;
  return VitalReferenceRange(
    low: low,
    high: high,
    caption: 'YOUR RANGE ${low.round()}–${high.round()} MS',
  );
}

StressZone stressZoneForLevel(double level) => level < 0.34
    ? StressZone.calm
    : level < 0.67
        ? StressZone.activated
        : StressZone.stressed;

StressZone stressZoneForHrv(double hrv, {VitalReferenceRange? personalRange}) =>
    stressZoneForLevel(
      stressLevelForHrv(hrv, personalRange: personalRange),
    );

/// Current stress index (0–100) derived from the latest plausible HRV in
/// [records], or null when no usable HRV exists.
double? latestStressFromHrv(
  List<dynamic> records, {
  VitalReferenceRange? personalRange,
}) {
  final hrv = latestPlausibleValue(records, const ['hrv'], validHrvValue);
  return hrv == null
      ? null
      : stressLevelForHrv(hrv, personalRange: personalRange) * 100;
}

String stressZoneLabel(StressZone zone) {
  switch (zone) {
    case StressZone.calm:
      return 'Calm';
    case StressZone.activated:
      return 'Activated';
    case StressZone.stressed:
      return 'Stressed';
  }
}

// ── Reference ranges ──────────────────────────────────────────────────────
// Each vital row on Metrics states its reference window in words (`TYPICAL
// 21–90 MS`) beside the user's own baseline. Four windows are the documented
// real-ring ranges above; sleep and resting HR are published norms added here
// because they are headline metrics and cannot be judged only against the
// user's own history. These live here, not in the view layer.

/// A named reference window for one vital, plus the caption that states it.
class VitalReferenceRange {
  const VitalReferenceRange({
    required this.low,
    required this.high,
    required this.caption,
  });

  final double low;
  final double high;

  /// Mono caption shown under the row, e.g. `TYPICAL 21–90 MS`.
  final String caption;

  bool contains(double value) => value >= low && value <= high;
}

/// Adult sleep recommendation (AASM / Sleep Foundation), in hours.
const double kSleepHoursMin = 7;
const double kSleepHoursMax = 9;

/// HRV normal band, in ms (real-ring range documented above).
const double kHrvTypicalMin = 21;
const double kHrvTypicalMax = 90;

/// SpO₂ typical band, in percent.
const double kSpo2TypicalMin = 95;
const double kSpo2TypicalMax = 98;

/// Body temperature typical band, in °C.
const double kTemperatureTypicalMin = 35.5;
const double kTemperatureTypicalMax = 37.0;

/// Stress index calm zone (0–100), from [stressZoneForLevel]'s calm cutoff.
const double kStressCalmMax = 34;

/// How often the user trains — asked as behaviour, never as identity. Maps to
/// a personal resting-HR band; unanswered falls back to the clinical range,
/// which errs in the harmless direction.
enum TrainingFrequency { mostDays, fewTimesAWeek, rarely }

extension TrainingFrequencyX on TrainingFrequency {
  String get label => switch (this) {
        TrainingFrequency.mostDays => 'Most days',
        TrainingFrequency.fewTimesAWeek => 'A few times a week',
        TrainingFrequency.rarely => 'Rarely, or just starting',
      };

  /// Short form for a trailing mono label.
  String get shortLabel => switch (this) {
        TrainingFrequency.mostDays => 'MOST DAYS',
        TrainingFrequency.fewTimesAWeek => 'FEW TIMES',
        TrainingFrequency.rarely => 'RARELY',
      };

  String get bandLabel => switch (this) {
        TrainingFrequency.mostDays => '40–60',
        TrainingFrequency.fewTimesAWeek => '50–70',
        TrainingFrequency.rarely => '60–100',
      };

  static TrainingFrequency? fromName(String? name) {
    if (name == null) return null;
    for (final f in TrainingFrequency.values) {
      if (f.name == name) return f;
    }
    return null;
  }
}

/// Resting-HR band for a training frequency. `null` (unanswered) is the
/// clinical 60–100.
VitalReferenceRange restingHrBand(TrainingFrequency? frequency) {
  final (low, high) = switch (frequency) {
    TrainingFrequency.mostDays => (40.0, 60.0),
    TrainingFrequency.fewTimesAWeek => (50.0, 70.0),
    TrainingFrequency.rarely || null => (60.0, 100.0),
  };
  final caption = frequency == null
      ? 'TYPICAL ${low.round()}–${high.round()} BPM'
      : 'YOUR BAND ${low.round()}–${high.round()} BPM';
  return VitalReferenceRange(low: low, high: high, caption: caption);
}

const VitalReferenceRange kHrvRange = VitalReferenceRange(
  low: kHrvTypicalMin,
  high: kHrvTypicalMax,
  caption: 'TYPICAL 21–90 MS',
);
const VitalReferenceRange kSleepRange = VitalReferenceRange(
  low: kSleepHoursMin,
  high: kSleepHoursMax,
  caption: 'RECOMMENDED 7–9 H',
);
const VitalReferenceRange kSpo2Range = VitalReferenceRange(
  low: kSpo2TypicalMin,
  high: kSpo2TypicalMax,
  caption: 'TYPICAL 95–98%',
);
const VitalReferenceRange kTemperatureRange = VitalReferenceRange(
  low: kTemperatureTypicalMin,
  high: kTemperatureTypicalMax,
  caption: 'TYPICAL 35.5–37 °C',
);
const VitalReferenceRange kStressRange = VitalReferenceRange(
  low: 0,
  high: kStressCalmMax,
  caption: 'CALM ZONE 0–34',
);
const VitalReferenceRange kSystolicRange = VitalReferenceRange(
  low: 90,
  high: 120,
  caption: 'NORMAL <120/80',
);
const VitalReferenceRange kGlucoseRange = VitalReferenceRange(
  low: 4.0,
  high: 5.6,
  caption: 'FASTING 4–5.6',
);

/// Reference window for a metric, or null for metrics with no published
/// window (they show a grey delta). Resting HR needs the user's band.
VitalReferenceRange? referenceRangeFor(
  VitalsMetricKind kind, {
  TrainingFrequency? trainingFrequency,
}) => switch (kind) {
      VitalsMetricKind.hrv => kHrvRange,
      VitalsMetricKind.sleep => kSleepRange,
      VitalsMetricKind.heartRate => restingHrBand(trainingFrequency),
      VitalsMetricKind.stress => kStressRange,
      VitalsMetricKind.spo2 => kSpo2Range,
      VitalsMetricKind.temperature => kTemperatureRange,
      VitalsMetricKind.bloodPressure => kSystolicRange,
      VitalsMetricKind.glucose => kGlucoseRange,
      _ => null,
    };

/// `7-DAY HIGH` / `30-DAY LOW` when [today] tops or bottoms its own history in
/// the selected window; computed from the series, so on most days none will.
String? peakBadgeFor({
  required double today,
  required List<double> window,
  required int windowDays,
}) {
  // Needs a week of prior days to mean anything; [window] excludes today.
  if (window.length < 5) return null;
  final max = window.reduce(math.max);
  final min = window.reduce(math.min);
  if (max == min) return null;
  if (today >= max) return '$windowDays-DAY HIGH';
  if (today <= min) return '$windowDays-DAY LOW';
  return null;
}

// ── Day-scoped vitals: one value per day, from the right window ───────────
// Bugs 11 and 16: Home and readiness used the newest spot reading, so a run,
// a coffee or a "Take a new reading" tap rewrote this morning's recovery
// numbers. A daily metric must come from a fixed window, not from whatever
// the ring reported last. Spot readings stay visible in the detail lists.

/// Width of the sustained-average bucket used for resting HR. Five minutes is
/// the wearable convention: short enough to catch a genuine trough, long
/// enough that one stray sample cannot create one.
const Duration kSustainedWindow = Duration(minutes: 5);

/// Mean of every point inside [start]–[end] (inclusive), or null when none.
double? _meanInWindow(
  List<VitalHistoryPoint> points,
  DateTime start,
  DateTime end,
) {
  var sum = 0.0;
  var count = 0;
  for (final p in points) {
    if (p.time.isBefore(start) || p.time.isAfter(end)) continue;
    sum += p.value;
    count++;
  }
  return count == 0 ? null : sum / count;
}

/// Lowest [kSustainedWindow] average across [points], ignoring buckets that
/// hold a single sample when a richer bucket exists — a lone low sample is an
/// artefact, a sustained trough is resting physiology.
double? _lowestSustainedAverage(List<VitalHistoryPoint> points) {
  if (points.isEmpty) return null;
  final sorted = [...points]..sort((a, b) => a.time.compareTo(b.time));
  final buckets = <int, List<double>>{};
  final epoch = sorted.first.time;
  for (final p in sorted) {
    final slot = p.time.difference(epoch).inSeconds ~/ kSustainedWindow.inSeconds;
    buckets.putIfAbsent(slot, () => []).add(p.value);
  }
  final means = <double>[];
  final richMeans = <double>[];
  for (final samples in buckets.values) {
    final mean = samples.reduce((a, b) => a + b) / samples.length;
    means.add(mean);
    if (samples.length > 1) richMeans.add(mean);
  }
  final pool = richMeans.isNotEmpty ? richMeans : means;
  return pool.reduce(math.min);
}

/// True while [time] falls inside a session window, or the 30 minutes after
/// one — heart rate is still elevated then, so it is not resting.
bool _inSessionShadow(DateTime time, List<DateTimeRange> sessions) {
  for (final s in sessions) {
    if (!time.isBefore(s.start) &&
        !time.isAfter(s.end.add(const Duration(minutes: 30)))) {
      return true;
    }
  }
  return false;
}

/// Resting heart rate for [day] — one value per day, the wearable standard.
///
/// Preferred source is the lowest sustained HR inside that night's sleep
/// window. With no sleep record, the lowest sustained daytime average,
/// excluding every session window plus 30 minutes after it. Null when neither
/// yields a usable trough.
int? restingHrForDay({
  required List<VitalHistoryPoint> hrPoints,
  required DateTime day,
  SleepDaySummary? night,
  List<DateTimeRange> sessions = const [],
}) {
  if (night != null) {
    final inWindow = hrPoints
        .where((p) =>
            !p.time.isBefore(night.windowStart) &&
            !p.time.isAfter(night.windowEnd))
        .toList();
    final sustained = _lowestSustainedAverage(inWindow);
    if (sustained != null) return sustained.round();
  }
  final target = DateTime(day.year, day.month, day.day);
  final dayPoints = hrPoints
      .where((p) =>
          DateTime(p.time.year, p.time.month, p.time.day) == target &&
          !_inSessionShadow(p.time, sessions))
      .toList();
  final sustained = _lowestSustainedAverage(dayPoints);
  return sustained?.round();
}

/// Overnight HRV for [day] — the mean of the HRV samples inside that night's
/// sleep window, which is the value recovery is actually read from. Null
/// without a night or without samples in it; callers must not silently fall
/// back to a spot reading.
int? hrvForDay({
  required List<VitalHistoryPoint> hrvPoints,
  SleepDaySummary? night,
  DateTime? day,
}) {
  if (night != null) {
    final mean = _meanInWindow(hrvPoints, night.windowStart, night.windowEnd);
    if (mean != null) return mean.round();
  }
  // No sleep record does not mean no overnight HRV: the ring still sampled
  // through the night. Fall back to the clock window so readiness and the
  // HRV card agree, instead of one showing a score the other cannot explain.
  if (day == null) return null;
  final start = DateTime(day.year, day.month, day.day);
  final mean = _meanInWindow(
    hrvPoints,
    start,
    start.add(const Duration(hours: kOvernightWindowEndHour)),
  );
  return mean?.round();
}

/// End of the clock-based overnight window, used only when a night was not
/// recorded. Deliberately generous: a late riser's recovery HRV still lands
/// inside it.
const int kOvernightWindowEndHour = 9;

// ── Sleep night completeness ──────────────────────────────────────────────
// Bug 14: a missing night was shown as today's, and a night that stopped
// early (flat battery, ring off) was scored as a real short night and then
// averaged into every baseline.

enum SleepNightStatus {
  /// A real night: enough sleep recorded, or a short one the ring kept
  /// measuring through.
  complete,

  /// The recording was cut off — too little sleep *and* nothing measured
  /// afterwards, which is what a flat battery or a removed ring looks like.
  incomplete,

  /// Nothing recorded for today.
  missing,
}

/// Below this, a night is too short to stand on its own and we look for
/// corroboration before trusting it.
const Duration kInadequateSleep = Duration(hours: 3);

/// Deprecated alias kept so older call sites keep compiling.
const Duration kImplausiblyShortNight = kInadequateSleep;

/// How long after the night we look for any further reading from the ring.
/// A ring that kept measuring was on the finger and alive, so the night ended
/// because the wearer got up — not because the recording died.
const Duration kPostSleepEvidenceWindow = Duration(hours: 6);

/// True when the ring reported anything at all in the hours after [after].
bool ringMeasuredAfter(RingHistory history, DateTime after) {
  final until = after.add(kPostSleepEvidenceWindow);
  final cutoff = after.millisecondsSinceEpoch ~/ 1000;
  final limit = until.millisecondsSinceEpoch ~/ 1000;
  for (final records in [history.combined, history.heartRate, history.steps]) {
    for (final record in records) {
      final ts = timestampOf(record);
      if (ts != null && ts > cutoff && ts <= limit) return true;
    }
  }
  return false;
}

/// Classifies [night] as last night's sleep relative to [now].
///
/// Only a night whose sleep day is today counts; an older night is
/// [SleepNightStatus.missing], never silently shown as today's.
///
/// A night is *incomplete* only when both things are true: too little sleep
/// was recorded, and the ring reported nothing afterwards. An earlier version
/// of this rule also demanded that the night end on an explicit `awake`
/// stage — but the ring emits one on barely a fifth of nights (it simply
/// stops recording when you get up), so ample, perfectly good nights were
/// being written off as incomplete.
SleepNightStatus sleepNightStatus(
  SleepDaySummary? night, {
  DateTime? now,
  RingHistory? history,
}) {
  final today = now ?? DateTime.now();
  final todayDay = DateTime(today.year, today.month, today.day);
  if (night == null) return SleepNightStatus.missing;
  final nightDay = DateTime(night.day.year, night.day.month, night.day.day);
  if (nightDay != todayDay) return SleepNightStatus.missing;

  // Enough sleep on the record is enough, full stop.
  if (night.breakdown.asleepSeconds >= kInadequateSleep.inSeconds) {
    return SleepNightStatus.complete;
  }
  // Short. If the ring went on measuring afterwards it was working and worn,
  // so this was a genuinely short night rather than a truncated recording.
  if (history != null && ringMeasuredAfter(history, night.windowEnd)) {
    return SleepNightStatus.complete;
  }
  return SleepNightStatus.incomplete;
}

/// The single readiness computation, so Home's score and the Metrics chart
/// can never disagree about the same day.
///
/// 65% last night's sleep score, 35% that night's HRV. Readiness is
/// deliberately about *today* — sleep debt is not accumulated into it — but
/// both callers must reach it the same way, which they previously did not:
/// the chart averaged a whole day's HRV readings (including daytime spot
/// measurements) while Home used the overnight window.
int? readinessScoreFrom({int? sleepScore, int? hrv}) {
  if (sleepScore == null && hrv == null) return null;
  final hrvComponent = hrv == null ? 50.0 : (hrv.clamp(20, 90) / 90 * 100);
  if (sleepScore == null) {
    // No usable night: HRV alone carries it, and the caller says so.
    return hrvComponent.round().clamp(0, 100);
  }
  return (sleepScore * 0.65 + hrvComponent * 0.35).round().clamp(0, 100);
}

/// The night to show as "last night", or null when today has none.
SleepDaySummary? sleepNightForToday(
  List<SleepDaySummary> nights, {
  DateTime? now,
}) {
  if (nights.isEmpty) return null;
  final today = now ?? DateTime.now();
  final todayDay = DateTime(today.year, today.month, today.day);
  for (final n in nights) {
    if (DateTime(n.day.year, n.day.month, n.day.day) == todayDay) return n;
  }
  return null;
}

/// Nights safe to average: complete, and excluding today's in-progress one.
/// Bases, peak badges, patterns and the §14 questions all read this, so a
/// partial night can never pull a baseline down.
List<SleepDaySummary> averageableNights(
  List<SleepDaySummary> nights, {
  DateTime? now,
  RingHistory? history,
}) {
  final today = now ?? DateTime.now();
  return [
    for (final n in nights)
      if (sleepNightStatus(n, now: n.day, history: history) !=
              SleepNightStatus.incomplete &&
          DateTime(n.day.year, n.day.month, n.day.day) !=
              DateTime(today.year, today.month, today.day))
        n,
  ];
}

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
double stressLevelForHrv(double hrv) => ((90 - hrv) / 70).clamp(0.0, 1.0);

StressZone stressZoneForLevel(double level) => level < 0.34
    ? StressZone.calm
    : level < 0.67
        ? StressZone.activated
        : StressZone.stressed;

StressZone stressZoneForHrv(double hrv) =>
    stressZoneForLevel(stressLevelForHrv(hrv));

/// Current stress index (0–100) derived from the latest plausible HRV in
/// [records], or null when no usable HRV exists.
double? latestStressFromHrv(List<dynamic> records) {
  final hrv = latestPlausibleValue(records, const ['hrv'], validHrvValue);
  return hrv == null ? null : stressLevelForHrv(hrv) * 100;
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

/// Translates raw ring vitals into a qualitative "state of being" so Vyana can
/// explain measurements in plain health language rather than abstract labels
/// or unexplained numbers. Shared by the home screen, the
/// completion notification, and the home-screen widgets.
///
/// Pure Dart on purpose: no Flutter imports, no `part of` coupling, so the
/// notification/widget services and the UI can all build it from primitives.
library;

enum WellnessTone { good, steady, watch, unknown }

// ── Readiness words ────────────────────────────────────────────────────────
//
// Item 74: there were two vocabularies with different cut-offs. The app said
// Ready >= 70 / Balanced >= 50 / Depleted; the notification and the
// home-screen widget said Primed >= 80 / Steady >= 65 / Settled >= 50 /
// Recovering. So a 68 was "Balanced" on the screen and "Steady" in the
// notification about the same reading, and nothing in the app could tell you
// which it meant.
//
// These live here, in a library both the screens and the background services
// can import, because a word about someone's body must not depend on which
// surface is saying it.

/// How long the ring has been quiet, for the stale banner.
///
/// Item 91: it was always hours, so a ring left in a drawer over a long
/// weekend produced "Today is missing 50 hours" — a true number that reads
/// as a fault in the app rather than a ring nobody has worn. Past a day it
/// counts days, which is how anyone would say it.
String staleGapLabel(Duration gap) {
  if (gap.inHours < 24) {
    final hours = gap.inHours;
    return hours <= 1 ? 'an hour' : '$hours hours';
  }
  final days = gap.inDays;
  return days == 1 ? 'a day' : '$days days';
}

/// At or above this, a readiness score reads as Ready.
const int kReadinessReadyFrom = 70;

/// At or above this (and below [kReadinessReadyFrom]), Balanced.
const int kReadinessBalancedFrom = 50;

/// The state word for a readiness score: Ready / Balanced / Depleted.
///
/// [hrvOnly] is a score built from HRV with no night behind it (bug 36). It
/// is half a reading, so it never earns a verdict - and "Depleted" in
/// particular must never come from a missing night.
String readinessStateWord(int? score, {bool hrvOnly = false}) {
  if (score == null) return 'No read yet';
  if (hrvOnly) return 'Partial read';
  if (score >= kReadinessReadyFrom) return 'Ready';
  if (score >= kReadinessBalancedFrom) return 'Balanced';
  return 'Depleted';
}

/// The colour band that goes with [readinessStateWord], so the word and the
/// colour can never disagree.
WellnessTone readinessTone(int? score, {bool hrvOnly = false}) {
  if (score == null || hrvOnly) return WellnessTone.unknown;
  if (score >= kReadinessReadyFrom) return WellnessTone.good;
  if (score >= kReadinessBalancedFrom) return WellnessTone.steady;
  return WellnessTone.watch;
}

/// One sentence to go under the word, in the same bands.
String readinessSummary(int? score, {bool hrvOnly = false}) {
  if (score == null) return 'Sync your ring to see where you are.';
  if (hrvOnly) {
    return 'Only HRV came through - last night is missing, so this is half '
        'a reading.';
  }
  if (score >= kReadinessReadyFrom) {
    return 'You are well recovered and ready for the day.';
  }
  if (score >= kReadinessBalancedFrom) {
    return 'You are in a balanced place - ease into anything hard.';
  }
  return 'Your body is asking for rest. Be gentle today.';
}

/// A single plain-language signal, e.g. Heart rate → "Elevated".
class WellnessSignal {
  const WellnessSignal({
    required this.label,
    required this.reading,
    required this.tone,
    this.detail,
  });

  /// Measurement name shown to the user.
  final String label;

  /// Short interpretation of the measurement.
  final String reading;

  final WellnessTone tone;

  /// Faint underlying number ("62 bpm"), surfaced small/secondary only.
  final String? detail;
}

/// The whole-person summary for a moment in time.
class WellnessState {
  const WellnessState({
    required this.title,
    required this.summary,
    required this.tone,
    required this.signals,
    required this.hasData,
  });

  /// Short headline: "Primed", "Steady", "Settled", "Recovering", "Let's check in".
  final String title;

  /// One gentle, plain-language sentence.
  final String summary;

  final WellnessTone tone;

  /// Felt signals with data, most meaningful first.
  final List<WellnessSignal> signals;

  /// Whether any vital was available to read.
  final bool hasData;

  bool get isEmpty => !hasData;

  /// Compact line for a notification body or widget subtitle.
  String get spokenLine {
    if (signals.isEmpty) return summary;
    return signals
        .take(4)
        .map((s) => '${s.label.toLowerCase()} ${s.reading.toLowerCase()}')
        .join(' · ');
  }

  factory WellnessState.empty() => const WellnessState(
        title: "Let's check in",
        summary: 'Run a quick scan to see how you are doing today.',
        tone: WellnessTone.unknown,
        signals: <WellnessSignal>[],
        hasData: false,
      );

  /// Build from already-extracted primitives. Callers pull these off
  /// `RingVitals` / `HomeDashboard` (both `part of main.dart`, hence primitives).
  factory WellnessState.from({
    int? heartRate,
    int? bloodOxygen,
    int? hrv,
    double? temperature,
    double? stressIndex,
    int? readinessScore,
    bool readinessIsHrvOnly = false,
  }) {
    final signals = <WellnessSignal>[];

    if (heartRate != null && heartRate > 0) {
      final tone = heartRate <= 70
          ? WellnessTone.good
          : heartRate <= 85
              ? WellnessTone.steady
              : WellnessTone.watch;
      final reading = heartRate < 55
          ? 'Resting'
          : heartRate <= 70
              ? 'Typical'
              : 'Elevated';
      signals.add(WellnessSignal(
        label: 'Heart rate',
        reading: reading,
        tone: tone,
        detail: '$heartRate bpm',
      ));
    }

    if (bloodOxygen != null && bloodOxygen > 0) {
      final tone = bloodOxygen >= 97
          ? WellnessTone.good
          : bloodOxygen >= 95
              ? WellnessTone.steady
              : WellnessTone.watch;
      final reading = bloodOxygen >= 95 ? 'Within range' : 'Low';
      signals.add(WellnessSignal(
        label: 'Blood oxygen',
        reading: reading,
        tone: tone,
        detail: '$bloodOxygen%',
      ));
    }

    if (hrv != null && hrv > 0) {
      final tone = hrv >= 55
          ? WellnessTone.good
          : hrv >= 35
              ? WellnessTone.steady
              : WellnessTone.watch;
      final reading = hrv >= 55
          ? 'Well recovered'
          : hrv >= 35
              ? 'Balanced'
              : 'Take it easy';
      signals.add(WellnessSignal(
        label: 'Recovery',
        reading: reading,
        tone: tone,
        detail: '$hrv ms',
      ));
    }

    if (temperature != null && temperature > 0) {
      final tone = (temperature >= 36.0 && temperature <= 37.3)
          ? WellnessTone.good
          : (temperature > 37.3 && temperature <= 37.8) || temperature >= 35.5
              ? WellnessTone.steady
              : WellnessTone.watch;
      final reading = temperature > 37.3
          ? 'Higher'
          : temperature < 35.8
              ? 'Lower'
              : 'Within range';
      signals.add(WellnessSignal(
        label: 'Temperature',
        reading: reading,
        tone: tone,
        detail: '${temperature.toStringAsFixed(1)}°',
      ));
    }

    if (stressIndex != null && stressIndex > 0) {
      final tone = stressIndex < 40
          ? WellnessTone.good
          : stressIndex <= 65
              ? WellnessTone.steady
              : WellnessTone.watch;
      final reading = stressIndex < 40
          ? 'Calm'
          : stressIndex <= 65
              ? 'Steady'
              : 'Tense';
      signals.add(WellnessSignal(
        label: 'Calm',
        reading: reading,
        tone: tone,
      ));
    }

    final hasData = signals.isNotEmpty || readinessScore != null;
    if (!hasData) return WellnessState.empty();

    // Prefer readiness (sleep + HRV trend) for the headline when we have it;
    // otherwise summarise the live signals we just took.
    if (readinessScore != null) {
      // Item 74: the same three words, cut-offs and sentence the readiness
      // ring on Home uses. The notification and the widget read this, so
      // they can no longer describe a 68 differently from the screen.
      return WellnessState(
        title: readinessStateWord(
          readinessScore,
          hrvOnly: readinessIsHrvOnly,
        ),
        summary: readinessSummary(
          readinessScore,
          hrvOnly: readinessIsHrvOnly,
        ),
        tone: readinessTone(readinessScore, hrvOnly: readinessIsHrvOnly),
        signals: signals,
        hasData: true,
      );
    }

    final watch = signals.where((s) => s.tone == WellnessTone.watch).length;
    final good = signals.where((s) => s.tone == WellnessTone.good).length;
    final overall = watch > 0 && watch >= good
        ? WellnessTone.watch
        : good > signals.length / 2
            ? WellnessTone.good
            : WellnessTone.steady;
    final title = overall == WellnessTone.good
        ? 'Steady & bright'
        : overall == WellnessTone.watch
            ? 'Running low'
            : 'Holding steady';
    final summary = overall == WellnessTone.good
        ? 'Your readings look calm and strong right now.'
        : overall == WellnessTone.watch
            ? 'A few signals are asking for some care today.'
            : 'You are in a balanced place right now.';
    return WellnessState(
      title: title,
      summary: summary,
      tone: overall,
      signals: signals,
      hasData: true,
    );
  }
}

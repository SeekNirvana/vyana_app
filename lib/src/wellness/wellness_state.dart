/// Translates raw ring vitals into a qualitative "state of being" so Vyana can
/// speak in felt language ("Calm", "Rested", "Strong") rather than clinical
/// numbers that leave the user guessing. Shared by the home screen, the
/// completion notification, and the home-screen widgets.
///
/// Pure Dart on purpose: no Flutter imports, no `part of` coupling, so the
/// notification/widget services and the UI can all build it from primitives.
library;

enum WellnessTone { good, steady, watch, unknown }

/// A single felt signal, e.g. Heart → "Calm".
class WellnessSignal {
  const WellnessSignal({
    required this.label,
    required this.reading,
    required this.tone,
    this.detail,
  });

  /// Concept name shown to the user: "Heart", "Oxygen", "Recovery", "Warmth".
  final String label;

  /// Felt descriptor: "Calm", "Strong", "Rested", "Normal"…
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

  /// Compact felt line for a notification body or widget subtitle, e.g.
  /// "heart calm · oxygen strong · recovery rested".
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
              ? 'Calm'
              : heartRate <= 85
                  ? 'Active'
                  : 'Elevated';
      signals.add(WellnessSignal(
        label: 'Heart',
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
      final reading = bloodOxygen >= 97
          ? 'Strong'
          : bloodOxygen >= 95
              ? 'Steady'
              : 'Low';
      signals.add(WellnessSignal(
        label: 'Oxygen',
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
          ? 'Rested'
          : hrv >= 35
              ? 'Balanced'
              : 'Strained';
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
          ? 'Warm'
          : temperature < 35.8
              ? 'Cool'
              : 'Normal';
      signals.add(WellnessSignal(
        label: 'Warmth',
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
      final tone = readinessScore >= 65
          ? WellnessTone.good
          : readinessScore >= 50
              ? WellnessTone.steady
              : WellnessTone.watch;
      final title = readinessScore >= 80
          ? 'Primed'
          : readinessScore >= 65
              ? 'Steady'
              : readinessScore >= 50
                  ? 'Settled'
                  : 'Recovering';
      final summary = readinessScore >= 80
          ? 'You are well recovered and ready for the day.'
          : readinessScore >= 65
              ? 'You are balanced and holding well today.'
              : readinessScore >= 50
                  ? 'A little below your best — ease into things.'
                  : 'Your body is asking for rest. Be gentle today.';
      return WellnessState(
        title: title,
        summary: summary,
        tone: tone,
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

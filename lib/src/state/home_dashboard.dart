part of '../../main.dart';

/// Ring-backed home dashboard metrics (replaces [HomeSeed] placeholders).
class HomeDashboard {
  const HomeDashboard({
    required this.stepStreak,
    required this.todaySteps,
    required this.todayDistanceMeters,
    required this.todayCalories,
    required this.readinessScore,
    required this.readinessLabel,
    required this.readinessDelta,
    required this.drivers,
    required this.insights,
    required this.practiceHint,
    required this.hasRingHistory,
  });

  final int stepStreak;
  final int todaySteps;
  final int todayDistanceMeters;
  final int todayCalories;
  final int? readinessScore;
  final String readinessLabel;
  final int? readinessDelta;
  final List<ReadinessDriver> drivers;
  final List<HomeInsight> insights;
  final String practiceHint;
  final bool hasRingHistory;

  factory HomeDashboard.from(RingController controller) {
    final history = controller.history;
    final vitals = controller.vitals;
    final stepDays = stepDaySummaries(history.steps);
    final sleepDays = sleepDaySummaries(history.sleep);
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    final todaySteps = stepDayForDate(history.steps, todayDay);
    final streak = computeStepStreak(stepDays);
    final hasHistory = history.totalRecords > 0;

    final latestSleep = sleepDays.isEmpty ? null : sleepDays.first;
    final priorSleep = sleepDays.length > 1 ? sleepDays[1] : null;
    final sleepScore = latestSleep?.score;
    final priorSleepScore = priorSleep?.score;

    final hrvPoints = vitalHistoryPoints(history, VitalsMetricKind.hrv);
    final latestHrv = vitals.hrv ?? (hrvPoints.isEmpty ? null : hrvPoints.last.value.round());
    final avgHrv = hrvPoints.isEmpty
        ? null
        : (hrvPoints.map((p) => p.value).reduce((a, b) => a + b) / hrvPoints.length)
            .round();

    int? readiness;
    if (sleepScore != null) {
      final hrvComponent = latestHrv == null
          ? 50
          : (latestHrv.clamp(20, 90) / 90 * 100).round();
      readiness = ((sleepScore * 0.65) + (hrvComponent * 0.35)).round().clamp(0, 100);
    } else if (latestHrv != null) {
      readiness = (latestHrv.clamp(20, 90) / 90 * 100).round();
    }

    final delta = sleepScore != null && priorSleepScore != null
        ? sleepScore - priorSleepScore
        : null;

    final drivers = <ReadinessDriver>[
      ReadinessDriver(
        'HRV',
        latestHrv == null ? '—' : '$latestHrv ms',
        good: latestHrv != null && avgHrv != null && latestHrv >= avgHrv,
      ),
      ReadinessDriver(
        'Resting HR',
        vitals.heartRate == null ? '—' : '${vitals.heartRate} bpm',
        good: vitals.heartRate != null && vitals.heartRate! < 75,
      ),
      ReadinessDriver(
        'Sleep',
        sleepScore == null ? '—' : _sleepLabel(sleepScore),
        good: sleepScore != null && sleepScore >= 70,
      ),
      ReadinessDriver(
        'Steps today',
        todaySteps == null ? '—' : '${todaySteps.steps}',
        good: todaySteps != null && todaySteps.steps >= kStepStreakGoal,
      ),
    ];

    final insights = _buildInsights(
      stepDays: stepDays,
      sleepDays: sleepDays,
      streak: streak,
      todaySteps: todaySteps?.steps,
      latestHrv: latestHrv,
      avgHrv: avgHrv,
    );

    final practiceHint = readiness == null
        ? 'Sync your ring to see readiness and tailor today\'s practice.'
        : readiness >= 75
        ? 'You look well recovered. A few quiet minutes of breath, or a walk in '
            'the light — whatever steadies you.'
        : readiness >= 55
        ? 'Recovery is moderate. Favour gentle movement and breath over intensity today.'
        : 'Take it easy today — rest, breathwork, or an early night will help most.';

    return HomeDashboard(
      stepStreak: streak,
      todaySteps: todaySteps?.steps ?? vitals.steps ?? 0,
      todayDistanceMeters: todaySteps?.distanceMeters ?? vitals.distanceMeters ?? 0,
      todayCalories: todaySteps?.calories ?? vitals.calories ?? 0,
      readinessScore: readiness,
      readinessLabel: _readinessLabel(readiness),
      readinessDelta: delta,
      drivers: drivers,
      insights: insights,
      practiceHint: practiceHint,
      hasRingHistory: hasHistory,
    );
  }

  static String _readinessLabel(int? score) {
    if (score == null) return 'Sync ring';
    if (score >= 80) return 'Primed';
    if (score >= 65) return 'Steady';
    if (score >= 50) return 'Moderate';
    return 'Recover';
  }

  static String _sleepLabel(int score) {
    if (score >= 80) return 'Good';
    if (score >= 65) return 'Fair';
    return 'Low';
  }

  static List<HomeInsight> _buildInsights({
    required List<StepDaySummary> stepDays,
    required List<SleepDaySummary> sleepDays,
    required int streak,
    required int? todaySteps,
    required int? latestHrv,
    required int? avgHrv,
  }) {
    final insights = <HomeInsight>[];

    if (todaySteps != null) {
      final remaining = kStepStreakGoal - todaySteps;
      if (remaining > 0 && remaining <= 1200) {
        insights.add(
          HomeInsight(
            'nova',
            'Activity',
            'You\'re $remaining steps from today\'s ${kStepStreakGoal ~/ 1000}k goal. '
                'A short evening walk closes it.',
            'steps',
          ),
        );
      } else if (streak >= 2) {
        insights.add(
          HomeInsight(
            'nova',
            'Activity',
            '$streak-day step streak at ${kStepStreakGoal ~/ 1000}k+ per day. Keep the rhythm going.',
            'steps',
          ),
        );
      }
    }

    if (sleepDays.length >= 2) {
      final latest = sleepDays[0];
      final prior = sleepDays[1];
      final drop = prior.score - latest.score;
      if (drop >= 12) {
        insights.add(
          HomeInsight(
            'luna',
            'Sleep',
            'Sleep score dipped ${drop}pts vs your previous night. Wind down earlier if you can.',
            'luna',
          ),
        );
      } else if (latest.score >= 80 && latest.score > prior.score) {
        insights.add(
          HomeInsight(
            'luna',
            'Sleep',
            'Last night scored ${latest.score} — one of your stronger recent sleeps.',
            'luna',
          ),
        );
      }
    }

    if (latestHrv != null && avgHrv != null) {
      final diff = latestHrv - avgHrv;
      if (diff >= 5) {
        insights.add(
          HomeInsight(
            'nova',
            'Recovery',
            'HRV is ${diff}ms above your recent average — a good window for steady effort.',
            'hrv',
          ),
        );
      } else if (diff <= -8) {
        insights.add(
          HomeInsight(
            'nova',
            'Recovery',
            'HRV is below your recent average. Favour recovery and calm minutes today.',
            'hrv',
          ),
        );
      }
    }

    if (insights.isEmpty && stepDays.isEmpty && sleepDays.isEmpty) {
      insights.add(
        const HomeInsight(
          'nova',
          'Ring',
          'Connect and sync your PRANA ring to unlock daily steps, sleep, and vitals here.',
          'readiness',
        ),
      );
    }

    return insights.take(3).toList();
  }
}

class HomeVitalTile {
  const HomeVitalTile({
    required this.kind,
    required this.label,
    required this.icon,
    required this.value,
    required this.unit,
    required this.accent,
  });

  final VitalsMetricKind kind;
  final String label;
  final String icon;
  final String value;
  final String unit;
  final String accent;
}

List<HomeVitalTile> homeVitalTiles({
  required RingVitals vitals,
  required RingHistory history,
  required HomeDashboard dashboard,
}) {
  String dash(num? value) => value == null ? '—' : '$value';
  String dashD(double? value, {int digits = 1}) =>
      value == null ? '—' : value.toStringAsFixed(digits);

  final tiles = <HomeVitalTile>[];

  void add(
    VitalsMetricKind kind,
    String label,
    String icon,
    String value,
    String unit,
    String accent, {
    bool requireValue = true,
  }) {
    if (requireValue && (value == '—' || value.isEmpty)) return;
    tiles.add(
      HomeVitalTile(
        kind: kind,
        label: label,
        icon: icon,
        value: value,
        unit: unit,
        accent: accent,
      ),
    );
  }

  if (dashboard.todaySteps > 0 ||
      vitals.steps != null ||
      history.steps.isNotEmpty) {
    tiles.add(
      HomeVitalTile(
        kind: VitalsMetricKind.steps,
        label: 'Steps today',
        icon: 'walk',
        value: '${dashboard.todaySteps > 0 ? dashboard.todaySteps : (vitals.steps ?? 0)}',
        unit: 'steps',
        accent: 'steps',
      ),
    );
  }
  add(VitalsMetricKind.heartRate, 'Heart rate', 'heart', dash(vitals.heartRate), 'bpm', 'hr');
  add(VitalsMetricKind.hrv, 'HRV', 'pulse', dash(vitals.hrv), 'ms', 'hrv');
  add(VitalsMetricKind.spo2, 'Blood oxygen', 'drop', dash(vitals.bloodOxygen), '%', 'spo2');
  add(
    VitalsMetricKind.sleep,
    'Sleep',
    'moon',
    vitals.sleepSummary ?? '—',
    '',
    'sleep',
  );
  add(
    VitalsMetricKind.calories,
    'Calories',
    'flame',
    dashboard.todayCalories > 0 ? '${dashboard.todayCalories}' : dash(vitals.calories),
    'cal',
    'cal',
  );
  add(
    VitalsMetricKind.distance,
    'Distance',
    'walk',
    dashboard.todayDistanceMeters > 0
        ? formatDistanceMeters(dashboard.todayDistanceMeters)
        : vitals.distanceMeters == null
        ? '—'
        : formatDistanceMeters(vitals.distanceMeters!),
    '',
    'steps',
  );
  add(
    VitalsMetricKind.bloodPressure,
    'Blood pressure',
    'activity',
    vitals.bloodPressure ?? '—',
    'mmHg',
    'bp',
  );
  add(
    VitalsMetricKind.temperature,
    'Temperature',
    'thermo',
    dashD(vitals.temperature),
    'C',
    'temp',
  );
  add(
    VitalsMetricKind.glucose,
    'Glucose',
    'drop',
    dashD(vitals.bloodGlucose),
    'mmol/L',
    'glucose',
  );
  add(
    VitalsMetricKind.uricAcid,
    'Uric acid',
    'drop',
    dash(vitals.uricAcid),
    'µmol/L',
    'glucose',
  );
  add(
    VitalsMetricKind.cholesterol,
    'Cholesterol',
    'activity',
    dashD(vitals.totalCholesterol),
    'mmol/L',
    'bp',
  );
  add(
    VitalsMetricKind.stress,
    'Stress',
    'brain',
    vitals.pressure == null
        ? '—'
        : stressZoneLabel(
            stressZoneForLevel((vitals.pressure! / 100).clamp(0.0, 1.0)),
          ),
    '',
    'stress',
  );

  return tiles;
}
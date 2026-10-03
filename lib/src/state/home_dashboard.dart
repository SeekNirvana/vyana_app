part of '../../main.dart';

/// Ring-backed home dashboard metrics (replaces [HomeSeed] placeholders).
class HomeDashboard {
  const HomeDashboard({
    required this.stepStreak,
    required this.todaySteps,
    required this.todayDistanceMeters,
    required this.todayCalories,
    required this.todayActiveMinutes,
    required this.lastSleepDuration,
    required this.readinessScore,
    required this.readinessLabel,
    required this.readinessDelta,
    required this.drivers,
    required this.insights,
    required this.practiceHint,
    required this.hasRingHistory,
    required this.sleepStatus,
    this.restingHr,
    this.overnightHrv,
    this.syncPending = false,
  });

  final int stepStreak;
  final int todaySteps;
  final int todayDistanceMeters;
  final int todayCalories;
  final int todayActiveMinutes;
  final String? lastSleepDuration;
  final int? readinessScore;
  final String readinessLabel;
  final int? readinessDelta;
  final List<ReadinessDriver> drivers;
  final List<HomeInsight> insights;
  final String practiceHint;
  final bool hasRingHistory;

  /// Whether last night was recorded, cut short, or is missing (bug 14). Home
  /// must never show an older night as today's.
  final SleepNightStatus sleepStatus;

  /// Resting HR for today — the lowest sustained HR in last night's sleep
  /// window, not the newest live reading (bug 11).
  final int? restingHr;

  /// Overnight HRV — the mean inside last night's sleep window, not a spot
  /// reading taken after coffee or a walk (bug 16).
  final int? overnightHrv;

  /// True while a sync is running and the cached night predates today's wake,
  /// so Home says data is on its way instead of showing yesterday (bug 17).
  final bool syncPending;

  bool get hasSleepTonight => sleepStatus == SleepNightStatus.complete;

  /// What the score line says about where readiness came from.
  String? get readinessSourceNote {
    switch (sleepStatus) {
      case SleepNightStatus.complete:
        return null;
      case SleepNightStatus.incomplete:
        return 'HRV only · sleep record incomplete';
      case SleepNightStatus.missing:
        return 'HRV only · sleep not recorded';
    }
  }

  factory HomeDashboard.from(RingController controller) {
    final history = controller.history;
    final vitals = controller.vitals;
    final stepDays = stepDaySummaries(history.steps);
    final sleepDays = sleepDaySummaries(history.sleep);
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    final todaySteps = stepDayForDate(history.steps, todayDay);
    final todayActiveMinutes = activeMinutesForDay(history.sport, todayDay);
    final streak = computeStepStreak(stepDays);
    final hasHistory = history.totalRecords > 0;

    // Bug 14a: only a night whose sleep day is today counts as last night.
    // An older night used to be shown as today's and scored into readiness.
    final tonight = sleepNightForToday(sleepDays, now: today);
    final sleepStatus =
        sleepNightStatus(tonight, now: today, history: history);
    final usableNight =
        sleepStatus == SleepNightStatus.complete ? tonight : null;
    final nights =
        averageableNights(sleepDays, now: today, history: history);
    final priorSleep = nights.isEmpty ? null : nights.first;
    final sleepScore = usableNight?.score;
    final priorSleepScore = priorSleep?.score;

    final hrvPoints = vitalHistoryPoints(history, VitalsMetricKind.hrv);
    final hrPoints = vitalHistoryPoints(history, VitalsMetricKind.heartRate);

    // Bugs 11 and 16: day-scoped values from the sleep window, so a daytime
    // reading cannot rewrite this morning's recovery.
    final overnightHrv = hrvForDay(
      hrvPoints: hrvPoints,
      night: tonight,
      day: todayDay,
    );
    final restingHr = restingHrForDay(
      hrPoints: hrPoints,
      day: todayDay,
      night: tonight,
      sessions: sportWindows(history.sport, todayDay),
    );

    // Readiness reads exactly the value the HRV card shows. It used to fall
    // back to the newest stored point, which produced a score beside three
    // cards that all said "No reading".
    final latestHrv = overnightHrv;
    final avgHrv = hrvPoints.isEmpty
        ? null
        : (hrvPoints.map((p) => p.value).reduce((a, b) => a + b) /
                  hrvPoints.length)
              .round();

    // Shared with the Metrics chart, so the big score and today's point on the
    // chart are the same number.
    final readiness =
        readinessScoreFrom(sleepScore: sleepScore, hrv: latestHrv);

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
        restingHr == null ? '—' : '$restingHr bpm',
        good: restingHr != null && restingHr < 75,
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
      sleepDays: nights,
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
      todayDistanceMeters:
          todaySteps?.distanceMeters ?? vitals.distanceMeters ?? 0,
      todayCalories: todaySteps?.calories ?? vitals.calories ?? 0,
      todayActiveMinutes: todayActiveMinutes,
      lastSleepDuration: usableNight == null
          ? (tonight == null
              ? null
              : durationText(tonight.breakdown.asleepSeconds))
          : durationText(usableNight.breakdown.asleepSeconds),
      readinessScore: readiness,
      readinessLabel: _readinessLabel(readiness),
      readinessDelta: delta,
      drivers: drivers,
      insights: insights,
      practiceHint: practiceHint,
      hasRingHistory: hasHistory,
      sleepStatus: sleepStatus,
      restingHr: restingHr,
      overnightHrv: overnightHrv,
      syncPending: controller.isAwaitingTonightSleep,
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
            'nova',
            'Sleep',
            'Sleep score dipped ${drop}pts vs your previous night. Wind down earlier if you can.',
            'luna',
          ),
        );
      } else if (latest.score >= 80 && latest.score > prior.score) {
        insights.add(
          HomeInsight(
            'nova',
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

/// Session windows on [day], from the ring's own sport records. Resting HR
/// excludes these plus the 30 minutes after each (bug 11) — heart rate is
/// still elevated then, so those samples are not resting.
List<DateTimeRange> sportWindows(List<dynamic> sportRecords, DateTime day) {
  final target = DateTime(day.year, day.month, day.day);
  final windows = <DateTimeRange>[];
  for (final record in sportRecords) {
    final timestamp = timestampOf(record);
    if (timestamp == null) continue;
    if (localDayFromEpochSeconds(timestamp) != target) continue;
    final start = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final seconds = readInt(record, const ['sportTime']) ?? 0;
    windows.add(
      DateTimeRange(start: start, end: start.add(Duration(seconds: seconds))),
    );
  }
  return windows;
}

int activeMinutesForDay(List<dynamic> sportRecords, DateTime day) {
  final target = DateTime(day.year, day.month, day.day);
  var seconds = 0;
  for (final record in sportRecords) {
    final timestamp = timestampOf(record);
    if (timestamp != null && localDayFromEpochSeconds(timestamp) == target) {
      seconds += readInt(record, const ['sportTime']) ?? 0;
    }
  }
  return (seconds / 60).round();
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
  final IconData icon;
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
    IconData icon,
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
        icon: Icons.directions_walk_rounded,
        value:
            '${dashboard.todaySteps > 0 ? dashboard.todaySteps : (vitals.steps ?? 0)}',
        unit: 'steps',
        accent: 'steps',
      ),
    );
  }
  add(
    VitalsMetricKind.heartRate,
    'Heart rate',
    Icons.favorite_rounded,
    dash(vitals.heartRate),
    'bpm',
    'hr',
  );
  add(
    VitalsMetricKind.hrv,
    'HRV',
    Icons.monitor_heart_rounded,
    dash(vitals.hrv),
    'ms',
    'hrv',
  );
  add(
    VitalsMetricKind.spo2,
    'Blood oxygen',
    Icons.bloodtype_rounded,
    dash(vitals.bloodOxygen),
    '%',
    'spo2',
  );
  add(
    VitalsMetricKind.sleep,
    'Sleep',
    Icons.airline_seat_individual_suite_rounded,
    vitals.sleepSummary ?? '—',
    '',
    'sleep',
  );
  add(
    VitalsMetricKind.calories,
    'Calories',
    Icons.local_fire_department_rounded,
    dashboard.todayCalories > 0
        ? '${dashboard.todayCalories}'
        : dash(vitals.calories),
    'cal',
    'cal',
  );
  add(
    VitalsMetricKind.distance,
    'Distance',
    Icons.near_me_rounded,
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
    Icons.health_and_safety_rounded,
    vitals.bloodPressure ?? '—',
    'mmHg',
    'bp',
  );
  add(
    VitalsMetricKind.temperature,
    'Temperature',
    Icons.thermostat_rounded,
    dashD(vitals.temperature),
    'C',
    'temp',
  );
  add(
    VitalsMetricKind.glucose,
    'Glucose',
    Icons.water_drop_rounded,
    dashD(vitals.bloodGlucose),
    'mmol/L',
    'glucose',
  );
  add(
    VitalsMetricKind.uricAcid,
    'Uric acid',
    Icons.science_rounded,
    dash(vitals.uricAcid),
    'µmol/L',
    'glucose',
  );
  add(
    VitalsMetricKind.cholesterol,
    'Cholesterol',
    Icons.biotech_rounded,
    dashD(vitals.totalCholesterol),
    'mmol/L',
    'bp',
  );
  add(
    VitalsMetricKind.stress,
    'Stress',
    Icons.psychology_rounded,
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

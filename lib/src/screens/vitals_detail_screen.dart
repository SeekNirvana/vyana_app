part of '../../main.dart';

Future<void> openVitalDetail(
  BuildContext context,
  RingController controller,
  VitalsMetricKind kind,
) {
  if (kind == VitalsMetricKind.sleep) {
    return openSleep(context, controller);
  }
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => VitalsDetailScreen(controller: controller, metric: kind),
    ),
  );
}

class VitalsDetailScreen extends StatelessWidget {
  const VitalsDetailScreen({
    super.key,
    required this.controller,
    required this.metric,
  });

  final RingController controller;
  final VitalsMetricKind metric;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final meta = _metricMeta(metric);
    final dashboard = HomeDashboard.from(controller);
    final points = vitalHistoryPoints(controller.history, metric);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: t.bgGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            children: [
              Row(
                children: [
                  IconBtn(
                    icon: 'chevL',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meta.eyebrow,
                          style: VyanaType.eyebrow.copyWith(color: t.gold),
                        ),
                        Text(
                          meta.title,
                          style: VyanaType.appBarSerif.copyWith(color: t.text),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (metric == VitalsMetricKind.steps)
                _StepsDetailBody(controller: controller, dashboard: dashboard)
              else ...[
                _MetricHero(
                  icon: meta.icon,
                  accent: meta.accent,
                  value: _currentValue(controller, metric),
                  unit: meta.unit,
                  caption: meta.caption,
                ),
                const SizedBox(height: 16),
                if (points.length >= 2) ...[
                  Panel(
                    pad: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          metric == VitalsMetricKind.stress
                              ? 'Stress rhythm'
                              : 'Trend',
                          style: VyanaType.label.copyWith(color: t.text),
                        ),
                        const SizedBox(height: 10),
                        if (metric == VitalsMetricKind.stress)
                          _StressBandChart(points: points)
                        else
                          Sparkline(
                            data: points.map((p) => p.value).toList(),
                            color: t.vit(meta.accent),
                            width: double.infinity,
                            height: 56,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (points.isEmpty)
                  AccessDeniedPanel(
                    title: 'No history yet',
                    message:
                        'Sync your ring to pull ${meta.title.toLowerCase()} readings.',
                    icon: 'refresh',
                    hint: 'You → Sync vitals & data after connecting.',
                    secondaryLabel: 'Sync now',
                    onSecondary: controller.isConnected && !controller.isSyncing
                        ? () => syncRingWithFeedback(context, controller)
                        : null,
                  )
                else
                  Panel(
                    pad: 4,
                    child: Column(
                      children: [
                        for (var i = 0; i < points.length && i < 12; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              color: t.borderSoft,
                              indent: 14,
                              endIndent: 14,
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    timeLabel(
                                      points[points.length - 1 - i].time,
                                    ),
                                    style: VyanaType.caption.copyWith(
                                      color: t.textSec,
                                    ),
                                  ),
                                ),
                                Text(
                                  points[points.length - 1 - i].label,
                                  style: VyanaType.label.copyWith(
                                    color: t.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 14),
              Panel(
                pad: 14,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VyanaIcon('info', size: 18, color: t.textMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        meta.footnote,
                        style: VyanaType.bodySm.copyWith(
                          color: t.textSec,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepsDetailBody extends StatelessWidget {
  const _StepsDetailBody({required this.controller, required this.dashboard});

  final RingController controller;
  final HomeDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final days = stepDaySummaries(controller.history.steps);
    final chartDays = days.take(7).toList().reversed.toList();
    final values = chartDays.map((d) => d.steps).toList();
    final labels = chartDays
        .map((d) => ['M', 'T', 'W', 'T', 'F', 'S', 'S'][d.day.weekday - 1])
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          grad: true,
          pad: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: t
                          .vit('steps')
                          .withValues(alpha: t.isDark ? 0.2 : 0.13),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Center(
                      child: VyanaIcon('walk', size: 22, color: t.vit('steps')),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Today',
                          style: VyanaType.caption.copyWith(color: t.textSec),
                        ),
                        Text(
                          '${dashboard.todaySteps}',
                          style: VyanaType.displaySerif.copyWith(color: t.text),
                        ),
                        Text(
                          'steps',
                          style: VyanaType.mono10.copyWith(color: t.textMuted),
                        ),
                      ],
                    ),
                  ),
                  if (dashboard.stepStreak > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: t.gold.withValues(alpha: t.isDark ? 0.16 : 0.1),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: t.gold.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          VyanaIcon('award', size: 14, color: t.gold),
                          const SizedBox(width: 5),
                          Text(
                            '${dashboard.stepStreak}d streak',
                            style: VyanaType.mono10.copyWith(color: t.gold),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _StepStat(
                    label: 'Distance',
                    value: formatDistanceMeters(dashboard.todayDistanceMeters),
                  ),
                  const SizedBox(width: 12),
                  _StepStat(
                    label: 'Calories',
                    value: '${dashboard.todayCalories}',
                  ),
                  const SizedBox(width: 12),
                  _StepStat(
                    label: 'Goal',
                    value: '${kStepStreakGoal ~/ 1000}k',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionHead(eyebrow: 'Activity', title: 'Last 7 days'),
        if (chartDays.isEmpty)
          AccessDeniedPanel(
            title: 'No step history',
            message: 'Sync your ring to see daily walking totals.',
            icon: 'walk',
            secondaryLabel: 'Sync now',
            onSecondary: controller.isConnected && !controller.isSyncing
                ? () => syncRingWithFeedback(context, controller)
                : null,
          )
        else
          Panel(
            pad: 16,
            child: _VitalBarChart(
              values: values,
              labels: labels,
              accent: t.vit('steps'),
              goal: kStepStreakGoal,
            ),
          ),
        if (days.isNotEmpty) ...[
          const SizedBox(height: 16),
          const SectionHead(eyebrow: 'Daily log', title: 'Recent days'),
          Panel(
            pad: 4,
            child: Column(
              children: [
                for (var i = 0; i < days.length && i < 10; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: t.borderSoft,
                      indent: 14,
                      endIndent: 14,
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _dayLabel(days[i].day),
                            style: VyanaType.label.copyWith(color: t.text),
                          ),
                        ),
                        Text(
                          '${days[i].steps} steps',
                          style: VyanaType.caption.copyWith(color: t.textSec),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          formatDistanceMeters(days[i].distanceMeters),
                          style: VyanaType.mono10.copyWith(color: t.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  static String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${day.month}/${day.day}';
  }
}

class _StepStat extends StatelessWidget {
  const _StepStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: t.isDark
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: VyanaType.mono10.copyWith(color: t.textMuted)),
            const SizedBox(height: 4),
            Text(value, style: VyanaType.label.copyWith(color: t.text)),
          ],
        ),
      ),
    );
  }
}

class _MetricHero extends StatelessWidget {
  const _MetricHero({
    required this.icon,
    required this.accent,
    required this.value,
    required this.unit,
    required this.caption,
  });

  final String icon;
  final String accent;
  final String value;
  final String unit;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final c = t.vit(accent);
    return Panel(
      grad: true,
      pad: 18,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: c.withValues(alpha: t.isDark ? 0.2 : 0.13),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Center(child: VyanaIcon(icon, size: 22, color: c)),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caption,
                  style: VyanaType.caption.copyWith(color: t.textSec),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: VyanaType.displaySerif.copyWith(color: t.text),
                    ),
                    if (unit.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        unit,
                        style: VyanaType.caption.copyWith(color: t.textMuted),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VitalBarChart extends StatelessWidget {
  const _VitalBarChart({
    required this.values,
    required this.labels,
    required this.accent,
    this.goal,
  });

  final List<int> values;
  final List<String> labels;
  final Color accent;
  final int? goal;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final maxV = [
      ...values,
      if (goal != null) goal!,
    ].fold<int>(1, (a, b) => a > b ? a : b);

    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${values[i]}',
                    style: VyanaType.mono10.copyWith(
                      color: values[i] >= (goal ?? 0) ? accent : t.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 96 * (values[i] / maxV),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: values[i] >= (goal ?? 0)
                          ? accent.withValues(alpha: 0.85)
                          : accent.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[i],
                    style: VyanaType.mono10.copyWith(color: t.textMuted),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricMeta {
  const _MetricMeta({
    required this.eyebrow,
    required this.title,
    required this.icon,
    required this.accent,
    required this.unit,
    required this.caption,
    required this.footnote,
  });

  final String eyebrow;
  final String title;
  final String icon;
  final String accent;
  final String unit;
  final String caption;
  final String footnote;
}

_MetricMeta _metricMeta(VitalsMetricKind kind) => switch (kind) {
  VitalsMetricKind.steps => const _MetricMeta(
    eyebrow: 'Activity',
    title: 'Steps',
    icon: 'walk',
    accent: 'steps',
    unit: 'steps',
    caption: 'Today',
    footnote:
        'Daily totals are summed from 30-minute ring intervals after each sync.',
  ),
  VitalsMetricKind.heartRate => const _MetricMeta(
    eyebrow: 'Vitals',
    title: 'Heart rate',
    icon: 'heart',
    accent: 'hr',
    unit: 'bpm',
    caption: 'Latest',
    footnote: 'Historical readings come from ring background monitoring.',
  ),
  VitalsMetricKind.hrv => const _MetricMeta(
    eyebrow: 'Recovery',
    title: 'HRV',
    icon: 'pulse',
    accent: 'hrv',
    unit: 'ms',
    caption: 'Latest',
    footnote: 'Heart rate variability from combined vitals history.',
  ),
  VitalsMetricKind.spo2 => const _MetricMeta(
    eyebrow: 'Vitals',
    title: 'Blood oxygen',
    icon: 'drop',
    accent: 'spo2',
    unit: '%',
    caption: 'Latest',
    footnote: 'SpO₂ readings from combined vitals history.',
  ),
  VitalsMetricKind.calories => const _MetricMeta(
    eyebrow: 'Activity',
    title: 'Calories',
    icon: 'flame',
    accent: 'cal',
    unit: 'cal',
    caption: 'Today',
    footnote: 'Active calories estimated from ring step intervals.',
  ),
  VitalsMetricKind.distance => const _MetricMeta(
    eyebrow: 'Activity',
    title: 'Distance',
    icon: 'walk',
    accent: 'steps',
    unit: '',
    caption: 'Today',
    footnote: 'Walking distance estimated from ring step intervals.',
  ),
  VitalsMetricKind.bloodPressure => const _MetricMeta(
    eyebrow: 'Vitals',
    title: 'Blood pressure',
    icon: 'activity',
    accent: 'bp',
    unit: 'mmHg',
    caption: 'Latest',
    footnote: 'Background blood pressure readings stored on the ring.',
  ),
  VitalsMetricKind.temperature => const _MetricMeta(
    eyebrow: 'Vitals',
    title: 'Temperature',
    icon: 'thermo',
    accent: 'temp',
    unit: 'C',
    caption: 'Latest',
    footnote: 'Skin temperature from combined vitals history.',
  ),
  VitalsMetricKind.glucose => const _MetricMeta(
    eyebrow: 'Biomarker',
    title: 'Glucose',
    icon: 'drop',
    accent: 'glucose',
    unit: 'mmol/L',
    caption: 'Latest',
    footnote: 'Non-invasive glucose estimates when supported by your ring.',
  ),
  VitalsMetricKind.uricAcid => const _MetricMeta(
    eyebrow: 'Biomarker',
    title: 'Uric acid',
    icon: 'drop',
    accent: 'glucose',
    unit: 'µmol/L',
    caption: 'Latest',
    footnote: 'Invasive biomarker readings from ring history.',
  ),
  VitalsMetricKind.cholesterol => const _MetricMeta(
    eyebrow: 'Biomarker',
    title: 'Cholesterol',
    icon: 'activity',
    accent: 'bp',
    unit: 'mmol/L',
    caption: 'Latest',
    footnote: 'Total cholesterol from invasive biomarker history.',
  ),
  VitalsMetricKind.stress => const _MetricMeta(
    eyebrow: 'Recovery',
    title: 'Stress',
    icon: 'brain',
    accent: 'stress',
    unit: '',
    caption: 'Now',
    footnote:
        'Stress is read from your heart-rate variability — higher HRV '
        'means calmer. It refreshes each time HRV syncs from the ring.',
  ),
  VitalsMetricKind.sleep => const _MetricMeta(
    eyebrow: 'Recovery',
    title: 'Sleep',
    icon: 'sleep',
    accent: 'sleep',
    unit: '',
    caption: 'Last night',
    footnote: 'Sleep opens in the dedicated sleep detail view.',
  ),
};

String _currentValue(RingController controller, VitalsMetricKind kind) {
  final v = controller.vitals;
  final dashboard = HomeDashboard.from(controller);
  return switch (kind) {
    VitalsMetricKind.steps => '${dashboard.todaySteps}',
    VitalsMetricKind.heartRate => valueOrDash(v.heartRate),
    VitalsMetricKind.hrv => valueOrDash(v.hrv),
    VitalsMetricKind.spo2 => valueOrDash(v.bloodOxygen),
    VitalsMetricKind.calories => '${dashboard.todayCalories}',
    VitalsMetricKind.distance => formatDistanceMeters(
      dashboard.todayDistanceMeters,
    ),
    VitalsMetricKind.bloodPressure => v.bloodPressure ?? '—',
    VitalsMetricKind.temperature => doubleOrDash(v.temperature, 1),
    VitalsMetricKind.glucose => doubleOrDash(v.bloodGlucose, 1),
    VitalsMetricKind.uricAcid => valueOrDash(v.uricAcid),
    VitalsMetricKind.cholesterol => doubleOrDash(v.totalCholesterol, 1),
    VitalsMetricKind.stress =>
      v.pressure == null
          ? '—'
          : stressZoneLabel(
              stressZoneForLevel((v.pressure! / 100).clamp(0.0, 1.0)),
            ),
    VitalsMetricKind.sleep => v.sleepSummary ?? '—',
  };
}

/// Qualitative stress "rhythm": a waveform banded into Calm / Activated /
/// Stressed, coloured by zone. Values are 0–100 stress levels derived from HRV.
class _StressBandChart extends StatelessWidget {
  const _StressBandChart({required this.points});

  final List<VitalHistoryPoint> points;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    var values = points.map((p) => p.value).toList();
    // Keep the rhythm readable — show the most recent stretch.
    if (values.length > 60) values = values.sublist(values.length - 60);
    const stressed = Color(0xFFD9975F);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 88,
          width: double.infinity,
          child: CustomPaint(
            painter: _StressBandPainter(
              values: values,
              calm: t.green,
              activated: t.gold,
              stressed: stressed,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _StressLegend(color: t.green, label: 'Calm'),
            const SizedBox(width: 16),
            _StressLegend(color: t.gold, label: 'Activated'),
            const SizedBox(width: 16),
            _StressLegend(color: stressed, label: 'Stressed'),
          ],
        ),
      ],
    );
  }
}

class _StressLegend extends StatelessWidget {
  const _StressLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: VyanaType.caption.copyWith(color: t.textSec)),
      ],
    );
  }
}

class _StressBandPainter extends CustomPainter {
  _StressBandPainter({
    required this.values,
    required this.calm,
    required this.activated,
    required this.stressed,
  });

  final List<double> values;
  final Color calm;
  final Color activated;
  final Color stressed;

  Color _zoneColor(double v) => v < 34 ? calm : (v < 67 ? activated : stressed);

  @override
  void paint(Canvas canvas, Size size) {
    // Faint band backgrounds, stressed at the top.
    final bands = <(double, double, Color)>[
      (0.0, 1 / 3, stressed),
      (1 / 3, 2 / 3, activated),
      (2 / 3, 1.0, calm),
    ];
    for (final band in bands) {
      final rect = Rect.fromLTRB(
        0,
        size.height * band.$1,
        size.width,
        size.height * band.$2,
      );
      canvas.drawRect(rect, Paint()..color = band.$3.withValues(alpha: 0.10));
    }
    if (values.length < 2) return;

    final dx = size.width / (values.length - 1);
    Offset at(int i) {
      final v = values[i].clamp(0.0, 100.0);
      return Offset(dx * i, size.height * (1 - v / 100));
    }

    for (var i = 0; i < values.length - 1; i++) {
      canvas.drawLine(
        at(i),
        at(i + 1),
        Paint()
          ..color = _zoneColor(values[i])
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }
    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(at(i), 2, Paint()..color = _zoneColor(values[i]));
    }
  }

  @override
  bool shouldRepaint(covariant _StressBandPainter oldDelegate) =>
      !listEquals(oldDelegate.values, values);
}

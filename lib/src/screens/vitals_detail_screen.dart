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

class VitalsDetailScreen extends StatefulWidget {
  const VitalsDetailScreen({
    super.key,
    required this.controller,
    required this.metric,
  });

  final RingController controller;
  final VitalsMetricKind metric;

  @override
  State<VitalsDetailScreen> createState() => _VitalsDetailScreenState();
}

class _VitalsDetailScreenState extends State<VitalsDetailScreen> {
  @override
  void dispose() {
    // The result belongs to this visit, so it does not greet the user again
    // the next time they open the screen.
    widget.controller.clearLastMeasurement();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Bug 15: the screen used to read vitals and history once in build with
    // no listener, so a reading that arrived changed nothing on screen.
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final controller = widget.controller;
    final metric = widget.metric;
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
                  // Bug 25 (1): say which value this is. Without it the big
                  // number looks like the reading just taken, and a spot
                  // measurement that did not move it looked like a failure.
                  caption: _heroCaption(metric, meta.caption),
                  spot: _spotReadingLine(controller, metric, meta.unit),
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
              // Bug 24: Stress is derived from HRV — the ring stores no
              // stress series — but its button asked the ring for a pressure
              // measurement this page never shows. It spun, finished, and
              // nothing changed. Stress is also not a moment reading: it
              // describes a stretch of time.
              if (metric == VitalsMetricKind.stress) ...[
                const SizedBox(height: 14),
                _StressSourceNote(controller: controller),
              ] else if (_retestActionFor(metric, controller) != null) ...[
                const SizedBox(height: 14),
                _RetestButton(controller: controller, metric: metric),
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
    this.spot,
  });

  final String icon;
  final String accent;
  final String value;
  final String unit;
  final String caption;

  /// The spot reading just taken, where the hero itself is a day value.
  final String? spot;

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
                if (spot case final line?) ...[
                  const SizedBox(height: 4),
                  Text(
                    line,
                    style: VyanaType.mono12.copyWith(color: t.textSec),
                  ),
                ],
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

/// Whose value the hero is showing. Only the two day-scoped vitals need
/// saying; everywhere else the hero is simply the latest reading.
String _heroCaption(VitalsMetricKind kind, String fallback) => switch (kind) {
      VitalsMetricKind.heartRate => 'Resting',
      VitalsMetricKind.hrv => 'Overnight',
      _ => fallback,
    };

/// `Just now · 72 ms · 09:31` — the spot reading the user just took, on its
/// own line, for the vitals whose hero is a day value (bug 25 (1)).
String? _spotReadingLine(
  RingController controller,
  VitalsMetricKind kind,
  String unit,
) {
  if (kind != VitalsMetricKind.heartRate && kind != VitalsMetricKind.hrv) {
    return null;
  }
  final outcome = controller.lastMeasurement;
  if (outcome == null || !outcome.captured || outcome.value == null) {
    return null;
  }
  return 'Just now · ${outcome.value}${unit.isEmpty ? '' : ' $unit'} · '
      '${outcome.clockLabel}';
}

String _currentValue(RingController controller, VitalsMetricKind kind) {
  final v = controller.vitals;
  final dashboard = HomeDashboard.from(controller);
  return switch (kind) {
    VitalsMetricKind.steps => '${dashboard.todaySteps}',
    // Bugs 16 and 25 (1): the hero is the day's value, the same one Home,
    // readiness and Metrics use. A spot reading appears on its own line
    // below rather than silently rewriting this morning's recovery number.
    VitalsMetricKind.heartRate => valueOrDash(dashboard.restingHr),
    VitalsMetricKind.hrv => valueOrDash(dashboard.overnightHrv),
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


/// The spot measurement behind a report, if the ring can take one on demand.
/// Gated on the metric's own `isSupportStart…Measurement` flag — the same
/// keys `info_panels.dart` threads through as `testKey` — so sleep, steps and
/// ECG (which have no such flag) show no control at all rather than a
/// disabled one.
MeasurementAction? _retestActionFor(
  VitalsMetricKind kind,
  RingController controller,
) {
  final features = controller.features;
  if (features == null) return null;
  final type = switch (kind) {
    VitalsMetricKind.heartRate => DeviceAppControlMeasureHealthDataType.heartRate,
    VitalsMetricKind.spo2 => DeviceAppControlMeasureHealthDataType.bloodOxygen,
    VitalsMetricKind.bloodPressure =>
      DeviceAppControlMeasureHealthDataType.bloodPressure,
    VitalsMetricKind.temperature =>
      DeviceAppControlMeasureHealthDataType.bodyTemperature,
    VitalsMetricKind.hrv => DeviceAppControlMeasureHealthDataType.hrv,
    VitalsMetricKind.stress => DeviceAppControlMeasureHealthDataType.pressure,
    VitalsMetricKind.glucose => DeviceAppControlMeasureHealthDataType.bloodGlucose,
    _ => null,
  };
  if (type == null) return null;
  for (final action in realtimeMeasurementActions) {
    if (action.type != type) continue;
    // Only the explicit start-measurement key counts as "re-testable".
    if (features.supports(action.featureKeys.first)) return action;
  }
  return null;
}

/// Bug 24: what stands where Stress's "Take a new reading" button was. One
/// grey line saying where the number comes from, linking to the page where a
/// reading actually changes it.
class _StressSourceNote extends StatelessWidget {
  const _StressSourceNote({required this.controller});

  final RingController controller;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Panel(
      pad: 14,
      onTap: () => openVitalDetail(context, controller, VitalsMetricKind.hrv),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Stress is worked out from your HRV through the day. Take an '
              'HRV reading to update it.',
              style: VyanaType.caption.copyWith(
                color: t.textSec,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(width: 8),
          VyanaIcon('chevR', size: 17, color: t.textMuted),
        ],
      ),
    );
  }
}

class _RetestButton extends StatelessWidget {
  const _RetestButton({required this.controller, required this.metric});
  final RingController controller;
  final VitalsMetricKind metric;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final action = _retestActionFor(metric, controller)!;
    final unit = _metricMeta(metric).unit;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final busy = controller.isMeasuring || controller.allVitalsRunning;
        final canRun = controller.isConnected && !busy;
        // Bug 15 (2): the result stays on the button after it finishes, so a
        // clean reading and a failed one no longer look the same.
        final outcome = controller.lastMeasurement;
        final showResult = !busy && outcome != null;
        // A reading only counts as a success if it actually produced a
        // number — see bug 25 (2) below.
        final success =
            (outcome?.captured ?? false) && outcome?.value != null;

        final String title;
        final String subtitle;
        if (busy) {
          title = 'Measuring…';
          subtitle = controller.testStatus.isEmpty
              ? 'Keep the ring on and still.'
              : controller.testStatus;
        } else if (showResult && success) {
          title = 'New reading';
          subtitle = '${outcome.value}${unit.isEmpty ? '' : ' $unit'} · '
              '${outcome.clockLabel}';
        } else if (showResult) {
          // Bug 25 (2): a measurement that captured nothing used to read
          // "Saved at 09:31." — a success message with no number in it. If
          // there is no value there is nothing to report but the failure.
          title = 'Take a new reading';
          subtitle =
              "Couldn't get a clean reading. Keep the ring snug and try again.";
        } else {
          title = 'Take a new reading';
          subtitle = controller.isConnected
              ? 'Runs a ${action.label.toLowerCase()} measurement on the ring now.'
              : 'Connect the ring to retest.';
        }

        return Panel(
          pad: 14,
          // Still tappable after a failure, so retrying is one tap.
          onTap: canRun ? () => unawaited(controller.runMeasurement(action)) : null,
          child: Row(
            children: [
              VyanaIconBadge(
                name: showResult && success ? 'check' : 'refresh',
                color: showResult && success ? t.green : t.heading,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: VyanaType.label.copyWith(
                        color: showResult && success ? t.green : t.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: VyanaType.caption.copyWith(color: t.textSec, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              VyanaIcon('chevR', size: 17, color: t.textMuted),
            ],
          ),
        );
      },
    );
  }
}

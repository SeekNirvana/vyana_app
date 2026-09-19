part of '../../main.dart';

/// Jump to the Metrics tab from anywhere (unwinding pushed routes first).
void openMetricsTab(BuildContext context, WidgetRef ref) {
  ref.read(tabIndexProvider.notifier).state = _VyanaShellState.metricsTab;
  Navigator.of(context).popUntil((route) => route.isFirst);
}

/// The readiness window the range control drives — every block on Metrics
/// (chart, trend note, peak badges, Movement averages) reads it.
enum MetricsRange { week, month, quarter }

extension MetricsRangeX on MetricsRange {
  int get days => switch (this) {
        MetricsRange.week => 7,
        MetricsRange.month => 30,
        MetricsRange.quarter => 90,
      };
  String get label => '${days}D';
  String get word => switch (this) {
        MetricsRange.week => 'weekly',
        MetricsRange.month => '30-day',
        MetricsRange.quarter => '90-day',
      };
  String get eyebrow => '$days DAYS';
}

final metricsRangeProvider =
    StateProvider<MetricsRange>((_) => MetricsRange.month);

/// Metrics answers "how does today compare, over time, and what is driving
/// it" — it owns the time axis. The score leads in a different register from
/// Home (62px numeral, no arc), every vital is placed against a range *and*
/// against the user's own baseline, and Movement lives here because steps,
/// distance and calories are measurements, not practices.
class MetricsScreen extends ConsumerStatefulWidget {
  const MetricsScreen({super.key});

  @override
  ConsumerState<MetricsScreen> createState() => _MetricsScreenState();
}

class _MetricsScreenState extends ConsumerState<MetricsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recomputePatterns());
  }

  void _recomputePatterns() {
    if (!mounted) return;
    final ring = ref.read(ringControllerProvider);
    unawaited(ref.read(patternEngineProvider).recompute(history: ring.history));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final c = ref.watch(ringControllerProvider);
    final range = ref.watch(metricsRangeProvider);
    final dashboard = HomeDashboard.from(c);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final band = TrainingFrequencyX.fromName(profile?.trainingFrequency);
    final patterns = ref.watch(patternsProvider).valueOrNull ?? const [];
    final pattern = currentPatternFor(patterns, 'metrics');
    final stale = ringUiStateOf(c) == RingUiState.stale ||
        ringUiStateOf(c) == RingUiState.disconnected;

    ref.listen<RingController>(ringControllerProvider, (prev, next) {
      if (prev?.history.totalRecords != next.history.totalRecords) {
        _recomputePatterns();
      }
    });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 176),
      children: [
        _MetricsHeader(controller: c, range: range),
        if (c.hasRingContext && stale)
          RingStaleBanner(
            controller: c,
            body: 'Every figure below is from your last sync.',
            margin: const EdgeInsets.only(bottom: 16),
          ),
        if (!c.hasRingContext)
          AccessDeniedPanel(
            title: 'Numbers arrive with PRANA',
            message:
                'Pair your ring and every score, trend, and chart fills in here.',
            icon: 'ring',
            primaryLabel: 'Buy ring',
            onPrimary: () => openRingOrder(context),
            secondaryLabel: 'Pair ring',
            onSecondary: () => openScanner(context, c),
          )
        else ...[
          _ReadinessBlock(controller: c, dashboard: dashboard, range: range),
          if (pattern != null)
            PatternCard(
              pattern: pattern,
              tint: patternLook(pattern, t).tint,
              glyph: patternLook(pattern, t).glyph,
              margin: const EdgeInsets.only(top: 22),
            ),
          const SizedBox(height: 24),
          _MovementBlock(controller: c, dashboard: dashboard, range: range),
          const SizedBox(height: 26),
          _AllVitalsBlock(
            controller: c,
            range: range,
            trainingFrequency: band,
            stale: stale,
          ),
          const SizedBox(height: 26),
          _EcgBlock(controller: c),
          const SizedBox(height: 22),
          _ExportLine(
            onTap: () => openExports(context, ref, section: ExportSection.health),
          ),
        ],
      ],
    );
  }
}

class _MetricsHeader extends StatelessWidget {
  const _MetricsHeader({required this.controller, required this.range});
  final RingController controller;
  final MetricsRange range;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    // Wrap so the range control drops under the title at large text sizes
    // or on narrow screens rather than squeezing it.
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 18),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 10,
        spacing: 12,
        children: [
          Text(
            'Metrics',
            style: VyanaType.appBarSerif.copyWith(color: t.text),
          ),
          if (controller.hasRingContext) _RangeControl(range: range),
        ],
      ),
    );
  }
}

// ── Readiness over the window ───────────────────────────────────────────────

/// One readiness point per night we have sleep for — the same blend Home uses
/// (65% sleep score, 35% HRV), so Home's number is the last point here.
List<({DateTime day, int score})> readinessSeries(
  RingHistory history,
  int days,
) {
  final now = DateTime.now();
  final since = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: days - 1));
  final hrvByDay = <DateTime, List<double>>{};
  for (final p in vitalHistoryPoints(history, VitalsMetricKind.hrv)) {
    final day = DateTime(p.time.year, p.time.month, p.time.day);
    hrvByDay.putIfAbsent(day, () => []).add(p.value);
  }
  final out = <({DateTime day, int score})>[];
  for (final night in sleepDaySummaries(history.sleep).reversed) {
    if (night.day.isBefore(since)) continue;
    final hrvs = hrvByDay[night.day];
    final hrv = hrvs == null || hrvs.isEmpty
        ? null
        : hrvs.reduce((a, b) => a + b) / hrvs.length;
    final hrvComponent =
        hrv == null ? 50.0 : (hrv.clamp(20, 90) / 90 * 100);
    final score = (night.score * 0.65 + hrvComponent * 0.35).round().clamp(0, 100);
    out.add((day: night.day, score: score));
  }
  return out;
}

class _ReadinessBlock extends StatelessWidget {
  const _ReadinessBlock({
    required this.controller,
    required this.dashboard,
    required this.range,
  });

  final RingController controller;
  final HomeDashboard dashboard;
  final MetricsRange range;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final score = dashboard.readinessScore;
    final look = scoreLook(score, t);
    final series = readinessSeries(controller.history, range.days);
    final values = series.map((e) => e.score).toList();
    final avg = values.isEmpty
        ? null
        : (values.reduce((a, b) => a + b) / values.length).round();
    final last7 = values.length > 7 ? values.sublist(values.length - 7) : values;
    final above = avg == null ? 0 : last7.where((v) => v > avg).length;

    String vsAvg() {
      if (score == null || avg == null) return 'No ${range.word} average yet';
      final d = score - avg;
      return '${d >= 0 ? '+' : '−'}${d.abs()} vs your ${range.word} average';
    }

    String trendLine() {
      if (avg == null || values.length < 3) {
        return 'A few more nights and your ${range.word} trend settles in here.';
      }
      final head = above == last7.length
          ? 'Every day this week sat above'
          : '$above of the last ${last7.length} days sat above';
      return '$head your ${range.word} average of $avg.';
    }

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: range.days - 1));
    const months = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
    final rangeStart = '${months[start.month - 1]} ${start.day}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MonoEyebrow('READINESS TODAY', size: 11, spacing: 0.9),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              score == null ? '—' : '$score',
              style: TextStyle(
                fontFamily: VyanaType.sans,
                fontSize: 62,
                height: 0.9,
                fontWeight: FontWeight.w700,
                letterSpacing: -2.5,
                color: look.hue,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    look.state,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: VyanaType.serif,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      height: 1,
                      color: look.hue,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    vsAvg(),
                    style: VyanaType.caption.copyWith(
                      color: t.textSec,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _ReadinessChart(series: values, avg: avg, hue: look.hue),
        const SizedBox(height: 6),
        Row(
          children: [
            MonoEyebrow(rangeStart, size: 10, spacing: 0.7),
            const Spacer(),
            MonoEyebrow(
              avg == null ? 'NO AVERAGE YET' : 'AVG $avg · ${range.eyebrow}',
              size: 10,
              spacing: 0.7,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          trendLine(),
          style: VyanaType.caption.copyWith(
            color: t.textSec,
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _RangeControl extends ConsumerWidget {
  const _RangeControl({required this.range});
  final MetricsRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.mutedInk.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in MetricsRange.values)
            InkWell(
              onTap: () => ref.read(metricsRangeProvider.notifier).state = r,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.fromLTRB(9, 6, 9, 7),
                decoration: BoxDecoration(
                  color: r == range
                      ? t.heading.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  r.label,
                  style: TextStyle(
                    fontFamily: VyanaType.mono,
                    fontSize: 12,
                    letterSpacing: 0.5,
                    fontWeight: r == range ? FontWeight.w700 : FontWeight.w400,
                    color: r == range ? t.text : t.mutedInk,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReadinessChart extends StatelessWidget {
  const _ReadinessChart({
    required this.series,
    required this.avg,
    required this.hue,
  });

  final List<int> series;
  final int? avg;
  final Color hue;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    if (series.length < 2) {
      return SizedBox(
        height: 92,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _EmptyChartPainter(
                  grid: t.mutedInk.withValues(alpha: 0.25),
                  hue: hue.withValues(alpha: 0.35),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 7),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: t.hairline),
              ),
              child: Text(
                series.isEmpty
                    ? 'Your trend draws itself after two nights of sleep'
                    : 'One night down — one more and the line appears',
                style: VyanaType.caption.copyWith(
                  color: t.textSec,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: 92,
      width: double.infinity,
      child: CustomPaint(
        painter: _ReadinessPainter(
          series: series,
          avg: avg,
          hue: hue,
          grid: t.mutedInk.withValues(alpha: 0.25),
          label: t.mutedInk,
        ),
      ),
    );
  }
}

class _ReadinessPainter extends CustomPainter {
  _ReadinessPainter({
    required this.series,
    required this.avg,
    required this.hue,
    required this.grid,
    required this.label,
  });

  final List<int> series;
  final int? avg;
  final Color hue;
  final Color grid;
  final Color label;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 9.0;
    final lo = series.reduce(math.min) - 4;
    final hi = series.reduce(math.max) + 4;
    double px(int i) => (i / (series.length - 1)) * size.width;
    double py(num v) =>
        size.height - pad - ((v - lo) / (hi - lo)) * (size.height - pad * 2);

    final line = Path()..moveTo(px(0), py(series[0]));
    for (var i = 1; i < series.length; i++) {
      line.lineTo(px(i), py(series[i]));
    }
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [hue.withValues(alpha: 0.22), hue.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    if (avg != null) {
      final y = py(avg!);
      final dash = Paint()
        ..color = grid
        ..strokeWidth = 1;
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, size.width), y), dash);
      }
    }
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = hue,
    );
    final last = Offset(size.width, py(series.last));
    canvas.drawCircle(last, 4, Paint()..color = hue);
  }

  @override
  bool shouldRepaint(_ReadinessPainter old) =>
      old.series != series || old.avg != avg || old.hue != hue;
}

/// The chart's ghost: a faint dashed average line and a flat baseline so the
/// block keeps its shape before there is anything to plot.
class _EmptyChartPainter extends CustomPainter {
  _EmptyChartPainter({required this.grid, required this.hue});
  final Color grid;
  final Color hue;

  @override
  void paint(Canvas canvas, Size size) {
    final dash = Paint()
      ..color = grid
      ..strokeWidth = 1;
    final y = size.height * 0.5;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, size.width), y), dash);
    }
    final base = Path()
      ..moveTo(0, size.height - 9)
      ..lineTo(size.width, size.height - 9);
    canvas.drawPath(
      base,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = hue,
    );
    canvas.drawCircle(Offset(size.width, size.height - 9), 4, Paint()..color = hue);
  }

  @override
  bool shouldRepaint(_EmptyChartPainter old) =>
      old.grid != grid || old.hue != hue;
}

// ── Movement ────────────────────────────────────────────────────────────────

class _MovementBlock extends StatelessWidget {
  const _MovementBlock({
    required this.controller,
    required this.dashboard,
    required this.range,
  });

  final RingController controller;
  final HomeDashboard dashboard;
  final MetricsRange range;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final now = DateTime.now();
    final since = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: range.days - 1));
    final days = stepDaySummaries(controller.history.steps)
        .where((d) => !d.day.isBefore(since))
        .toList();
    String avgOf(int Function(StepDaySummary) pick, String Function(int) fmt) {
      if (days.isEmpty) return 'AVG —';
      final total = days.fold<int>(0, (sum, d) => sum + pick(d));
      return 'AVG ${fmt((total / days.length).round())}';
    }

    final steps = dashboard.todaySteps;
    final distance = dashboard.todayDistanceMeters;
    final calories = dashboard.todayCalories;
    final tiles = [
      (
        label: 'STEPS',
        value: _thousands(steps),
        unit: '',
        avg: avgOf((d) => d.steps, _thousands),
        kind: VitalsMetricKind.steps,
      ),
      (
        label: 'DISTANCE',
        value: _km(distance),
        unit: 'km',
        avg: avgOf((d) => d.distanceMeters, _km),
        kind: VitalsMetricKind.distance,
      ),
      (
        label: 'CALORIES',
        value: '$calories',
        unit: 'cal',
        avg: avgOf((d) => d.calories, (v) => '$v'),
        kind: VitalsMetricKind.calories,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                'Movement',
                style: VyanaType.label.copyWith(
                  color: t.heading,
                  fontSize: 16.5,
                ),
              ),
            ),
            MonoEyebrow('TODAY', size: 11),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: HairlineCard(
                  padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
                  onTap: () =>
                      openVitalDetail(context, controller, tiles[i].kind),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MonoEyebrow(tiles[i].label, size: 10.5, spacing: 0.6),
                      const SizedBox(height: 7),
                      Text.rich(
                        TextSpan(
                          text: tiles[i].value,
                          children: [
                            if (tiles[i].unit.isNotEmpty)
                              TextSpan(
                                text: ' ${tiles[i].unit}',
                                style: VyanaType.caption.copyWith(
                                  color: t.textSec,
                                  fontSize: 12.5,
                                ),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: VyanaType.label.copyWith(
                          color: t.text,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      MonoEyebrow(tiles[i].avg, size: 10.5, spacing: 0.5),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        if (dashboard.stepStreak > 1) ...[
          const SizedBox(height: 8),
          Text(
            '${dashboard.stepStreak}-day streak at ${kStepStreakGoal ~/ 1000}k+ steps.',
            style: VyanaType.caption.copyWith(color: t.textSec, fontSize: 13),
          ),
        ],
      ],
    );
  }
}

String _thousands(int value) {
  final text = '$value';
  if (text.length <= 3) return text;
  return '${text.substring(0, text.length - 3)},${text.substring(text.length - 3)}';
}

String _km(int meters) => (meters / 1000).toStringAsFixed(1);

// ── All vitals ──────────────────────────────────────────────────────────────

/// One row of the vitals list, fully resolved for rendering.
class _VitalRowData {
  const _VitalRowData({
    required this.kind,
    required this.name,
    required this.icon,
    required this.ink,
    required this.supported,
    required this.value,
    required this.unit,
    required this.delta,
    required this.quality,
    required this.caption,
    required this.badge,
  });

  final VitalsMetricKind kind;
  final String name;
  final String icon;
  final Color? ink;
  final bool supported;
  final String? value;
  final String unit;
  final String delta;

  /// `good` (inside range) · `poor` (outside) · `level` (no range / no data)
  final String quality;
  final String? caption;
  final String? badge;
}

/// Baseline = mean of the window excluding today's reading.
double? _baseline(List<VitalHistoryPoint> points, int days) {
  final now = DateTime.now();
  final since = now.subtract(Duration(days: days));
  final today = DateTime(now.year, now.month, now.day);
  final vals = [
    for (final p in points)
      if (p.time.isAfter(since) && p.time.isBefore(today)) p.value,
  ];
  if (vals.isEmpty) return null;
  return vals.reduce((a, b) => a + b) / vals.length;
}

/// One value per *day* in the window (daily mean), excluding today, so a
/// peak badge compares today against real history rather than against the
/// last few readings of the same morning.
List<double> _window(List<VitalHistoryPoint> points, int days) {
  final now = DateTime.now();
  final since = now.subtract(Duration(days: days));
  final today = DateTime(now.year, now.month, now.day);
  final byDay = <DateTime, List<double>>{};
  for (final p in points) {
    if (!p.time.isAfter(since) || !p.time.isBefore(today)) continue;
    byDay.putIfAbsent(DateTime(p.time.year, p.time.month, p.time.day), () => [])
        .add(p.value);
  }
  return [
    for (final vals in byDay.values) vals.reduce((a, b) => a + b) / vals.length,
  ];
}

String _fmtDelta(double d, {int digits = 0, String unit = ''}) {
  final sign = d >= 0 ? '+' : '−';
  final mag = d.abs();
  final text = digits == 0 ? '${mag.round()}' : mag.toStringAsFixed(digits);
  if (mag < (digits == 0 ? 0.5 : math.pow(10, -digits) / 2)) return 'Flat';
  return '$sign$text$unit';
}

String _fmtHours(double hours) {
  final h = hours.floor();
  final m = ((hours - h) * 60).round();
  return '${h}h${m.toString().padLeft(2, '0')}';
}

List<_VitalRowData> _buildVitalRows(
  RingController c,
  MetricsRange range,
  TrainingFrequency? band,
  VyanaColors t,
) {
  final history = c.history;
  final vitals = c.vitals;
  final features = c.features;
  bool supported(List<String> keys) =>
      features == null ? true : features.supportsAny(keys);

  _VitalRowData numeric({
    required VitalsMetricKind kind,
    required String name,
    required String icon,
    required Color? ink,
    required List<String> keys,
    required double? today,
    required List<VitalHistoryPoint> points,
    required String unit,
    required String baseUnit,
    int digits = 0,
    String Function(double)? format,
    String? deltaOverride,
  }) {
    final range_ = referenceRangeFor(kind, trainingFrequency: band);
    final ok = supported(keys);
    final fmt = format ?? (v) => digits == 0 ? '${v.round()}' : v.toStringAsFixed(digits);
    if (!ok) {
      return _VitalRowData(
        kind: kind, name: name, icon: icon, ink: ink, supported: false,
        value: null, unit: unit, delta: 'Not measured by this ring',
        quality: 'level', caption: null, badge: null,
      );
    }
    if (today == null) {
      return _VitalRowData(
        kind: kind, name: name, icon: icon, ink: ink, supported: true,
        value: null, unit: unit, delta: 'No reading yet',
        quality: 'level', caption: range_?.caption, badge: null,
      );
    }
    final base = _baseline(points, range.days);
    final inRange = range_?.contains(today);
    final quality = inRange == null ? 'level' : (inRange ? 'good' : 'poor');
    final caption = range_ == null
        ? null
        : (inRange == true ? range_.caption : '${range_.caption} · OUTSIDE');
    final delta = deltaOverride ??
        (base == null
            ? 'First readings — no base yet'
            : '${_fmtDelta(today - base, digits: digits)} vs base ${fmt(base)}$baseUnit');
    final badge = peakBadgeFor(
      today: today,
      window: _window(points, range.days),
      windowDays: range.days,
    );
    return _VitalRowData(
      kind: kind, name: name, icon: icon, ink: ink, supported: true,
      value: fmt(today), unit: unit, delta: delta, quality: quality,
      caption: caption, badge: badge,
    );
  }

  final hrvPoints = vitalHistoryPoints(history, VitalsMetricKind.hrv);
  final hrvToday = vitals.hrv?.toDouble() ??
      (hrvPoints.isEmpty ? null : hrvPoints.last.value);

  final sleepPoints = [
    for (final d in sleepDaySummaries(history.sleep).reversed)
      VitalHistoryPoint(
        time: d.day,
        value: d.breakdown.asleepSeconds / 3600,
        label: '',
      ),
  ];
  final sleepToday = sleepPoints.isEmpty ? null : sleepPoints.last.value;

  final hrPoints = vitalHistoryPoints(history, VitalsMetricKind.heartRate);
  final hrToday = vitals.heartRate?.toDouble() ??
      (hrPoints.isEmpty ? null : hrPoints.last.value);

  final stressPoints = vitalHistoryPoints(history, VitalsMetricKind.stress);
  final stressToday = vitals.pressure ?? (stressPoints.isEmpty ? null : stressPoints.last.value);

  final spo2Points = vitalHistoryPoints(history, VitalsMetricKind.spo2);
  final spo2Today = vitals.bloodOxygen?.toDouble() ??
      (spo2Points.isEmpty ? null : spo2Points.last.value);

  final tempPoints = vitalHistoryPoints(history, VitalsMetricKind.temperature);
  final tempToday = vitals.temperature ?? (tempPoints.isEmpty ? null : tempPoints.last.value);

  final bpPoints = vitalHistoryPoints(history, VitalsMetricKind.bloodPressure);
  final bpText = vitals.bloodPressure ?? latestPlausibleBloodPressure(history.bloodPressure);
  final bpSys = bpText == null ? null : double.tryParse(bpText.split('/').first.trim());

  final gluPoints = vitalHistoryPoints(history, VitalsMetricKind.glucose);
  final gluToday = vitals.bloodGlucose ?? (gluPoints.isEmpty ? null : gluPoints.last.value);

  final stressRow = numeric(
    kind: VitalsMetricKind.stress,
    name: 'Stress',
    icon: 'brain',
    ink: t.idStress,
    keys: const ['isSupportHRV', 'isSupportPressure', 'isSupportStartPressureMeasurement'],
    today: stressToday,
    points: stressPoints,
    unit: 'idx',
    baseUnit: '',
    deltaOverride: stressToday == null
        ? null
        : '${stressZoneLabel(stressZoneForLevel((stressToday / 100).clamp(0.0, 1.0)))} · derived from HRV',
  );

  return [
    numeric(
      kind: VitalsMetricKind.hrv,
      name: 'HRV',
      icon: 'pulse',
      ink: t.idHrv,
      keys: const ['isSupportHRV', 'isSupportStartHRVMeasurement'],
      today: hrvToday,
      points: hrvPoints,
      unit: 'ms',
      baseUnit: '',
    ),
    numeric(
      kind: VitalsMetricKind.sleep,
      name: 'Sleep',
      icon: 'moon',
      ink: t.idSleep,
      keys: const ['isSupportSleep'],
      today: sleepToday,
      points: sleepPoints,
      unit: '',
      baseUnit: '',
      digits: 2,
      format: _fmtHours,
      deltaOverride: sleepToday == null
          ? null
          : (() {
              final base = _baseline(sleepPoints, range.days);
              if (base == null) return 'First nights — no base yet';
              final mins = ((sleepToday - base) * 60).round();
              if (mins.abs() < 5) return 'Level with base ${_fmtHours(base)}';
              return '${mins >= 0 ? '+' : '−'}${mins.abs()} min vs base ${_fmtHours(base)}';
            })(),
    ),
    numeric(
      kind: VitalsMetricKind.heartRate,
      name: 'Resting HR',
      icon: 'heart',
      ink: t.idRestHr,
      keys: const ['isSupportHeartRate', 'isSupportStartHeartRateMeasurement'],
      today: hrToday,
      points: hrPoints,
      unit: 'bpm',
      baseUnit: '',
    ),
    stressRow,
    numeric(
      kind: VitalsMetricKind.spo2,
      name: 'Blood oxygen',
      icon: 'drop',
      ink: null,
      keys: const ['isSupportBloodOxygen', 'isSupportStartBloodOxygenMeasurement'],
      today: spo2Today,
      points: spo2Points,
      unit: '%',
      baseUnit: '%',
    ),
    numeric(
      kind: VitalsMetricKind.temperature,
      name: 'Temperature',
      icon: 'thermo',
      ink: null,
      keys: const ['isSupportTemperature', 'isSupportStartBodyTemperatureMeasurement'],
      today: tempToday,
      points: tempPoints,
      unit: '°C',
      baseUnit: '',
      digits: 1,
    ),
    numeric(
      kind: VitalsMetricKind.bloodPressure,
      name: 'Blood pressure',
      icon: 'pulse',
      ink: null,
      keys: const ['isSupportBloodPressure', 'isSupportStartBloodPressureMeasurement'],
      today: bpSys,
      points: bpPoints,
      unit: '',
      baseUnit: '',
      format: (_) => bpText ?? '—',
      deltaOverride: bpSys == null
          ? null
          : (() {
              final base = _baseline(bpPoints, range.days);
              if (base == null) return 'First readings — no base yet';
              return '${_fmtDelta(bpSys - base)} vs base ${base.round()} systolic';
            })(),
    ),
    numeric(
      kind: VitalsMetricKind.glucose,
      name: 'Glucose',
      icon: 'drop',
      ink: null,
      keys: const ['isSupportBloodGlucose', 'isSupportStartBloodGlucoseMeasurement'],
      today: gluToday,
      points: gluPoints,
      unit: 'mmol/L',
      baseUnit: '',
      digits: 1,
    ),
  ];
}

class _AllVitalsBlock extends StatelessWidget {
  const _AllVitalsBlock({
    required this.controller,
    required this.range,
    required this.trainingFrequency,
    required this.stale,
  });

  final RingController controller;
  final MetricsRange range;
  final TrainingFrequency? trainingFrequency;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final rows = _buildVitalRows(controller, range, trainingFrequency, t);
    final key = rows.take(4).toList();
    final other = rows.skip(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'All vitals',
                style: VyanaType.label.copyWith(color: t.heading, fontSize: 16.5),
              ),
            ),
            BorderedPill(
              label: 'See all & test',
              onTap: () => openMeasurements(context, controller),
            ),
          ],
        ),
        const SizedBox(height: 12),
        MonoEyebrow('KEY METRICS', size: 10.5, spacing: 0.9),
        const SizedBox(height: 6),
        for (final r in key) _VitalRow(data: r, controller: controller, stale: stale),
        const SizedBox(height: 14),
        MonoEyebrow('OTHER VITALS', size: 10.5, spacing: 0.9),
        const SizedBox(height: 6),
        for (final r in other) _VitalRow(data: r, controller: controller, stale: stale),
      ],
    );
  }
}

class _VitalRow extends StatelessWidget {
  const _VitalRow({
    required this.data,
    required this.controller,
    required this.stale,
  });

  final _VitalRowData data;
  final RingController controller;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final ink = data.ink ?? t.idOther;
    final tile = data.ink != null
        ? data.ink!.withValues(alpha: 0.14)
        : t.mutedInk.withValues(alpha: t.isDark ? 0.14 : 0.1);
    final q = switch (data.quality) {
      'good' => t.qGoodSoft,
      'poor' => t.qPoorSoft,
      _ => t.mutedInk,
    };
    final caption = !data.supported ? 'NOT ON THIS RING' : data.caption;
    return HairlineCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      opacity: !data.supported ? 0.55 : (stale ? 0.7 : 1),
      onTap: data.supported
          ? () => openVitalDetail(context, controller, data.kind)
          : null,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 0),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: tile,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: VyanaIcon(data.icon, size: 16, color: ink)),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          data.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: VyanaType.caption.copyWith(
                            color: t.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                      if (data.badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.fromLTRB(5, 2, 5, 3),
                          decoration: BoxDecoration(
                            color: t.heading.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: MonoEyebrow(
                            data.badge!,
                            size: 10,
                            spacing: 0.5,
                            color: t.heading,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.delta,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: VyanaType.caption.copyWith(color: q, fontSize: 13),
                  ),
                  if (caption != null) ...[
                    const SizedBox(height: 3),
                    MonoEyebrow(caption, size: 10.5, spacing: 0.6),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text.rich(
              TextSpan(
                text: data.value ?? '—',
                children: [
                  if (data.unit.isNotEmpty && data.value != null)
                    TextSpan(
                      text: ' ${data.unit}',
                      style: VyanaType.caption.copyWith(
                        color: t.textSec,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              style: VyanaType.label.copyWith(
                color: t.text,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            VyanaIcon('chevR', size: 16, color: t.mutedInk),
          ],
        ),
      ),
    ).withBottomGap(6);
  }
}

extension _Gap on Widget {
  Widget withBottomGap(double gap) =>
      Padding(padding: EdgeInsets.only(bottom: gap), child: this);
}

// ── ECG ─────────────────────────────────────────────────────────────────────

/// ECG classification set — the classification equivalent of a range.
String ecgClassification(EcgRecordingRow r) {
  if (r.afFlag) return 'AFib';
  if (r.qrsType == 0 || r.qrsType == 14) return 'Inconclusive';
  final text = r.interpretation ?? '';
  if (text.startsWith('Suspected')) return 'Irregular';
  return 'Sinus';
}

class _EcgBlock extends ConsumerWidget {
  const _EcgBlock({required this.controller});
  final RingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final recordings = ref.watch(_ecgRecordingsProvider).valueOrNull ?? const [];
    final latest = recordings.isEmpty ? null : recordings.first;
    final canRecord = controller.supportsEcg && controller.isConnected;

    void openHistory() => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const EcgHistoryScreen()),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'ECG',
                style: VyanaType.label.copyWith(color: t.heading, fontSize: 16.5),
              ),
            ),
            if (controller.supportsEcg)
              BorderedPill(
                label: 'Record',
                icon: 'pulse',
                onTap: canRecord
                    ? () => openMeasurements(context, controller)
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 10),
        HairlineCard(
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
          onTap: recordings.isEmpty ? null : openHistory,
          child: latest == null
              ? Text(
                  controller.supportsEcg
                      ? 'No recordings yet. Record takes a 30-second trace from the ring.'
                      : 'This ring does not take an ECG.',
                  style: VyanaType.caption.copyWith(color: t.textSec),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ecgClassification(latest),
                            style: VyanaType.label.copyWith(
                              color: t.text,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        MonoEyebrow(_ecgWhen(latest.capturedAt), size: 10.5),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 56,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _EcgMiniPainter(
                          samples: _ecgSamples(latest),
                          color: t.idOther,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    MonoEyebrow(
                      [
                        '${(latest.durationMs / 1000).round()} SEC',
                        if (latest.heartRate != null) 'AVG ${latest.heartRate} BPM',
                        '${recordings.length} RECORDING${recordings.length == 1 ? '' : 'S'}',
                      ].join(' · '),
                      size: 10.5,
                      spacing: 0.7,
                    ),
                    const SizedBox(height: 4),
                    MonoEyebrow('SINUS · AFIB · IRREGULAR · INCONCLUSIVE',
                        size: 10, spacing: 0.5, color: t.mutedInk.withValues(alpha: 0.7)),
                  ],
                ),
        ),
      ],
    );
  }

  static String _ecgWhen(DateTime at) {
    final now = DateTime.now();
    final sameDay = at.year == now.year && at.month == now.month && at.day == now.day;
    final time = '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    if (sameDay) return 'TODAY · $time';
    const months = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
    return '${at.day} ${months[at.month - 1]} · $time';
  }

  static List<double> _ecgSamples(EcgRecordingRow row) {
    List<double> decode(String json) {
      try {
        final list = jsonDecode(json);
        if (list is List) return [for (final v in list) (v as num).toDouble()];
      } catch (_) {}
      return const [];
    }

    var s = decode(row.filteredSamplesJson);
    if (s.isEmpty) s = decode(row.rawSamplesJson);
    if (s.length <= 400) return s;
    // Show the middle ~4 seconds so the trace is legible at card width.
    final rate = row.sampleRateHz <= 0 ? 250 : row.sampleRateHz;
    final span = rate * 4;
    final start = ((s.length - span) / 2).floor().clamp(0, s.length - 1);
    return s.sublist(start, math.min(s.length, start + span));
  }
}

final _ecgRecordingsProvider = StreamProvider<List<EcgRecordingRow>>(
  (ref) => ref.watch(databaseProvider).watchEcgRecordings(),
);

class _EcgMiniPainter extends CustomPainter {
  _EcgMiniPainter({required this.samples, required this.color});
  final List<double> samples;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) return;
    final lo = samples.reduce(math.min);
    final hi = samples.reduce(math.max);
    final span = (hi - lo) == 0 ? 1 : (hi - lo);
    final path = Path();
    for (var i = 0; i < samples.length; i++) {
      final x = i / (samples.length - 1) * size.width;
      final y = size.height - 3 - ((samples[i] - lo) / span) * (size.height - 6);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_EcgMiniPainter old) =>
      old.samples != samples || old.color != color;
}

// ── Export line ─────────────────────────────────────────────────────────────

/// One quiet closing line: per-metric reports live here (tapping a vital *is*
/// the report); an exported artefact is an account object and lives in You.
class _ExportLine extends StatelessWidget {
  const _ExportLine({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Row(
          children: [
            VyanaIcon('download', size: 16, color: t.mutedInk),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'Export reports',
                style: VyanaType.caption.copyWith(
                  color: t.textSec,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            MonoEyebrow('IN YOU', size: 10.5, spacing: 0.6),
            const SizedBox(width: 4),
            VyanaIcon('chevR', size: 16, color: t.mutedInk),
          ],
        ),
      ),
    );
  }
}

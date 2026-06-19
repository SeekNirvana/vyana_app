part of '../main.dart';

enum SleepRangeMode { day, week, month }

class SleepDetailScreen extends StatefulWidget {
  const SleepDetailScreen({required this.history, super.key});

  final RingHistory history;

  @override
  State<SleepDetailScreen> createState() => _SleepDetailScreenState();
}

class _SleepDetailScreenState extends State<SleepDetailScreen> {
  SleepRangeMode _mode = SleepRangeMode.day;
  late DateTime _anchorDay;

  @override
  void initState() {
    super.initState();
    final days = sleepDaySummaries(widget.history.sleep);
    _anchorDay = _clampAnchorToToday(
      days.isEmpty ? _dateOnly(DateTime.now()) : days.first.day,
    );
  }

  @override
  void didUpdateWidget(covariant SleepDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.history.sleep != widget.history.sleep) {
      final days = sleepDaySummaries(widget.history.sleep);
      if (days.isNotEmpty && !_hasDay(days, _anchorDay)) {
        _anchorDay = _clampAnchorToToday(days.first.day);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = sleepDaySummaries(widget.history.sleep);
    final periodDays = _periodDays(days);
    final periodBreakdown = _breakdownForDays(periodDays);
    final score = _scoreForDays(periodDays);
    final title = _mode == SleepRangeMode.day
        ? 'Sleep Score'
        : 'Avg. Sleep Score';
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 180;
    final t = context.vyana;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: const Text('Sleep'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: t.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: t.bgGradient),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SleepModeTabs(
                        value: _mode,
                        onChanged: (mode) => setState(() {
                          _mode = mode;
                          _anchorDay = _clampAnchorToToday(_anchorDay);
                        }),
                      ),
                      const SizedBox(height: 16),
                      _SleepDateNavigator(
                        label: _periodLabel(),
                        onPrevious: () => _shiftPeriod(-1),
                        onNext: _canGoNext ? () => _shiftPeriod(1) : null,
                      ),
                      const SizedBox(height: 24),
                      _SleepScoreHeader(
                        label: title,
                        score: score,
                        asleep: periodBreakdown.asleepSeconds,
                      ),
                      const SizedBox(height: 20),
                      if (periodDays.isEmpty)
                        const _SleepEmptyState()
                      else if (_mode == SleepRangeMode.day)
                        _SleepDayAnalytics(
                          day: periodDays.first,
                          vitals: sleepVitalsForDay(
                            periodDays.first,
                            widget.history,
                          ),
                        )
                      else
                        _SleepPeriodAnalytics(
                          mode: _mode,
                          days: periodDays,
                          breakdown: periodBreakdown,
                          vitals: sleepVitalsForDays(
                            periodDays,
                            widget.history,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<SleepDaySummary> _periodDays(List<SleepDaySummary> days) {
    final range = _dateRangeForMode(_anchorDay, _mode);
    return days
        .where(
          (day) => !day.day.isBefore(range.$1) && !day.day.isAfter(range.$2),
        )
        .toList()
      ..sort((a, b) => a.day.compareTo(b.day));
  }

  String _periodLabel() {
    final range = _dateRangeForMode(_anchorDay, _mode);
    switch (_mode) {
      case SleepRangeMode.day:
        final today = _dateOnly(DateTime.now());
        return _sameDay(_anchorDay, today) ? 'Today' : _shortDate(_anchorDay);
      case SleepRangeMode.week:
        return '${_shortDate(range.$1)} - ${_shortDate(range.$2)}';
      case SleepRangeMode.month:
        return '${_monthName(_anchorDay.month)} ${_anchorDay.year}';
    }
  }

  void _shiftPeriod(int direction) {
    setState(() {
      DateTime nextAnchor;
      switch (_mode) {
        case SleepRangeMode.day:
          nextAnchor = _dateOnly(_anchorDay.add(Duration(days: direction)));
          break;
        case SleepRangeMode.week:
          nextAnchor = _dateOnly(_anchorDay.add(Duration(days: direction * 7)));
          break;
        case SleepRangeMode.month:
          nextAnchor = DateTime(_anchorDay.year, _anchorDay.month + direction);
          break;
      }
      _anchorDay = _clampAnchorToToday(nextAnchor);
    });
  }

  bool get _canGoNext {
    final currentRange = _dateRangeForMode(_dateOnly(DateTime.now()), _mode);
    final selectedRange = _dateRangeForMode(_anchorDay, _mode);
    return selectedRange.$1.isBefore(currentRange.$1);
  }

  DateTime _clampAnchorToToday(DateTime anchor) {
    final today = _dateOnly(DateTime.now());
    final currentRange = _dateRangeForMode(today, _mode);
    final range = _dateRangeForMode(anchor, _mode);
    if (range.$1.isAfter(currentRange.$1)) return today;
    return _dateOnly(anchor);
  }
}

class _SleepModeTabs extends StatelessWidget {
  const _SleepModeTabs({required this.value, required this.onChanged});

  final SleepRangeMode value;
  final ValueChanged<SleepRangeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: SleepRangeMode.values.map((mode) {
          final selected = mode == value;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => onChanged(mode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: selected ? t.green : Colors.transparent,
                  ),
                  child: Text(
                    _modeLabel(mode),
                    style: TextStyle(
                      color: selected ? Colors.white : t.textSec,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SleepDateNavigator extends StatelessWidget {
  const _SleepDateNavigator({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Center(
      child: Container(
        height: 48,
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: t.border),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Previous',
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left),
              color: t.green,
            ),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: t.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next',
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
              color: onNext == null ? t.textMuted : t.green,
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepScoreHeader extends StatelessWidget {
  const _SleepScoreHeader({
    required this.label,
    required this.score,
    required this.asleep,
  });

  final String label;
  final int? score;
  final int asleep;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: t.textSec,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              score == null ? '--' : '$score',
              style: TextStyle(
                color: t.text,
                fontSize: 64,
                fontWeight: FontWeight.w300,
                height: 0.95,
              ),
            ),
            const SizedBox(width: 14),
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Text(
                asleep > 0 ? durationText(asleep) : 'No sleep',
                style: TextStyle(color: t.textSec, fontSize: 15),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SleepDayAnalytics extends StatelessWidget {
  const _SleepDayAnalytics({required this.day, required this.vitals});

  final SleepDaySummary day;
  final SleepVitalsSummary vitals;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SleepPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Night Time Sleep',
                      style: TextStyle(
                        color: t.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    day.windowLabel,
                    style: TextStyle(color: t.textSec),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SleepWaveform(day: day, height: 184, dark: t.isDark),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SleepStageDurationGrid(
          breakdown: day.breakdown,
          average: false,
          divisor: 1,
        ),
        const SizedBox(height: 16),
        _SleepVitalsPanel(vitals: vitals, average: false),
        const SizedBox(height: 16),
        _SleepSectionsPanel(day: day),
      ],
    );
  }
}

class _SleepPeriodAnalytics extends StatelessWidget {
  const _SleepPeriodAnalytics({
    required this.mode,
    required this.days,
    required this.breakdown,
    required this.vitals,
  });

  final SleepRangeMode mode;
  final List<SleepDaySummary> days;
  final SleepStageBreakdown breakdown;
  final SleepVitalsSummary vitals;

  @override
  Widget build(BuildContext context) {
    final divisor = days.isEmpty ? 1 : days.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SleepPanel(
          child: SizedBox(
            height: mode == SleepRangeMode.week ? 258 : 280,
            child: SleepPeriodBarChart(days: days),
          ),
        ),
        const SizedBox(height: 16),
        _SleepStageDurationGrid(
          breakdown: breakdown,
          average: true,
          divisor: divisor,
        ),
        const SizedBox(height: 16),
        _SleepVitalsPanel(vitals: vitals, average: true),
      ],
    );
  }
}

class _SleepStageDurationGrid extends StatelessWidget {
  const _SleepStageDurationGrid({
    required this.breakdown,
    required this.average,
    required this.divisor,
  });

  final SleepStageBreakdown breakdown;
  final bool average;
  final int divisor;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'Deep sleep',
        breakdown.deepSeconds,
        sleepStageColor(SleepType.deepSleep),
      ),
      (
        'Light sleep',
        breakdown.lightSeconds,
        sleepStageColor(SleepType.lightSleep),
      ),
      ('REM', breakdown.remSeconds, sleepStageColor(SleepType.rem)),
      ('Awake', breakdown.awakeSeconds, sleepStageColor(SleepType.awake)),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 12.0;
        final columns = constraints.maxWidth < 520 ? 1 : 2;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: 12,
          children: items.map((item) {
            final seconds = average ? (item.$2 / divisor).round() : item.$2;
            return SizedBox(
              width: itemWidth,
              child: _SleepStageDurationCard(
                label: average ? 'Avg. ${item.$1}' : item.$1,
                value: durationText(seconds),
                color: item.$3,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _SleepStageDurationCard extends StatelessWidget {
  const _SleepStageDurationCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 50,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: t.text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: t.text,
              fontSize: 22,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SleepVitalsPanel extends StatelessWidget {
  const _SleepVitalsPanel({required this.vitals, required this.average});

  final SleepVitalsSummary vitals;
  final bool average;

  @override
  Widget build(BuildContext context) {
    final available = vitals.available;
    if (available.isEmpty) {
      return const _SleepPanel(
        child: _DarkEmptyInline(
          icon: Icons.monitor_heart,
          text: 'No overnight vital samples for this sleep period.',
        ),
      );
    }

    final t = context.vyana;
    return _SleepPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            average ? 'Average Sleep Vitals' : 'Overnight Averages',
            style: TextStyle(
              color: t.text,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: available.map((series) {
              return _SleepVitalAverageChip(series: series);
            }).toList(),
          ),
          const SizedBox(height: 14),
          ...available.map(
            (series) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SleepVitalSeriesChart(series: series),
            ),
          ),
        ],
      ),
    );
  }
}

class _SleepVitalAverageChip extends StatelessWidget {
  const _SleepVitalAverageChip({required this.series});

  final SleepVitalSeries series;

  @override
  Widget build(BuildContext context) {
    final decimals = _vitalDecimals(series);
    final t = context.vyana;
    return Container(
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.elevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            series.label,
            style: TextStyle(color: t.textSec, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            '${series.averageText(decimals)} ${series.unit}'.trim(),
            style: TextStyle(
              color: t.text,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _SleepVitalSeriesChart extends StatelessWidget {
  const _SleepVitalSeriesChart({required this.series});

  final SleepVitalSeries series;

  @override
  Widget build(BuildContext context) {
    final points = series.points
        .map(
          (point) => MeasurementSeriesPoint(
            time: point.time,
            value: point.value,
            label: '${point.value} ${series.unit}',
          ),
        )
        .toList();
    final t = context.vyana;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          series.label,
          style: TextStyle(
            color: t.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TimeSeriesChart(points: points),
      ],
    );
  }
}

class _SleepSectionsPanel extends StatelessWidget {
  const _SleepSectionsPanel({required this.day});

  final SleepDaySummary day;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return _SleepPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sleep Sections',
            style: TextStyle(
              color: t.text,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          ...day.sections.map(
            (section) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SleepSectionRow(section: section),
            ),
          ),
        ],
      ),
    );
  }
}

class _SleepSectionRow extends StatelessWidget {
  const _SleepSectionRow({required this.section});

  final SleepContinuousSection section;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.elevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Icon(Icons.bedtime, color: t.green, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              section.windowLabel,
              style: TextStyle(
                color: t.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            durationText(section.breakdown.asleepSeconds),
            style: TextStyle(color: t.textSec),
          ),
        ],
      ),
    );
  }
}

class _SleepPanel extends StatelessWidget {
  const _SleepPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.border),
        boxShadow: t.shadowSoft,
      ),
      child: child,
    );
  }
}

class _SleepEmptyState extends StatelessWidget {
  const _SleepEmptyState();

  @override
  Widget build(BuildContext context) {
    return const _SleepPanel(
      child: _DarkEmptyInline(
        icon: Icons.bedtime,
        text: 'No sleep stages have been synced for this period.',
      ),
    );
  }
}

class _DarkEmptyInline extends StatelessWidget {
  const _DarkEmptyInline({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Row(
      children: [
        Icon(icon, color: t.green),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(color: t.textSec)),
        ),
      ],
    );
  }
}

class SleepPeriodBarChart extends StatelessWidget {
  const SleepPeriodBarChart({required this.days, super.key});

  final List<SleepDaySummary> days;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return const _DarkEmptyInline(
        icon: Icons.bar_chart,
        text: 'No sleep stages have been synced for this period.',
      );
    }
    final t = context.vyana;
    return CustomPaint(
      painter: SleepPeriodBarChartPainter(
        days,
        gridColor: t.borderSoft,
        labelColor: t.textMuted,
        valueColor: t.text,
      ),
    );
  }
}

class SleepPeriodBarChartPainter extends CustomPainter {
  SleepPeriodBarChartPainter(
    this.days, {
    required this.gridColor,
    required this.labelColor,
    required this.valueColor,
  });

  final List<SleepDaySummary> days;
  final Color gridColor;
  final Color labelColor;
  final Color valueColor;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 38.0;
    const top = 16.0;
    const bottom = 34.0;
    final right = size.width - 8;
    final plotWidth = (right - left).clamp(1.0, double.infinity).toDouble();
    final plotHeight = size.height - top - bottom;
    final maxSeconds = days
        .map((day) => day.breakdown.totalSeconds)
        .fold<int>(8 * 3600, (max, value) => value > max ? value : max);
    final maxHours = ((maxSeconds / 3600).ceil()).clamp(1, 24);
    final scaleSeconds = maxHours * 3600;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final labelStyle = TextStyle(color: labelColor, fontSize: 10);

    for (var i = 0; i <= 4; i += 1) {
      final y = top + plotHeight * i / 4;
      canvas.drawLine(Offset(left, y), Offset(right, y), gridPaint);
      final hours = (maxHours * (1 - i / 4)).round();
      _paintText(canvas, '${hours}h', Offset(6, y - 6), labelStyle);
    }

    final slotWidth = plotWidth / days.length;
    final barWidth = slotWidth.clamp(18, 42).toDouble() * 0.52;
    for (var i = 0; i < days.length; i += 1) {
      final day = days[i];
      final centerX = left + slotWidth * i + slotWidth / 2;
      var cursorY = top + plotHeight;
      final stages = [
        (day.breakdown.deepSeconds, sleepStageColor(SleepType.deepSleep)),
        (day.breakdown.lightSeconds, sleepStageColor(SleepType.lightSleep)),
        (day.breakdown.remSeconds, sleepStageColor(SleepType.rem)),
        (day.breakdown.awakeSeconds, sleepStageColor(SleepType.awake)),
      ];
      for (final stage in stages) {
        if (stage.$1 <= 0) continue;
        final height = plotHeight * stage.$1 / scaleSeconds;
        final rect = Rect.fromLTRB(
          centerX - barWidth / 2,
          cursorY - height,
          centerX + barWidth / 2,
          cursorY,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          Paint()..color = stage.$2,
        );
        cursorY -= height;
      }
      _paintText(
        canvas,
        durationText(day.breakdown.asleepSeconds),
        Offset(centerX - 18, cursorY - 16),
        TextStyle(
          color: valueColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      );
      _paintText(
        canvas,
        '${day.day.month}/${day.day.day}',
        Offset(centerX - 14, size.height - 22),
        labelStyle,
      );
    }
  }

  void _paintText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant SleepPeriodBarChartPainter oldDelegate) {
    return oldDelegate.days != days ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.valueColor != valueColor;
  }
}

String _modeLabel(SleepRangeMode mode) {
  switch (mode) {
    case SleepRangeMode.day:
      return 'Day';
    case SleepRangeMode.week:
      return 'Week';
    case SleepRangeMode.month:
      return 'Month';
  }
}

(DateTime, DateTime) _dateRangeForMode(DateTime anchor, SleepRangeMode mode) {
  final day = _dateOnly(anchor);
  switch (mode) {
    case SleepRangeMode.day:
      return (day, day);
    case SleepRangeMode.week:
      final start = day.subtract(Duration(days: day.weekday - 1));
      return (start, start.add(const Duration(days: 6)));
    case SleepRangeMode.month:
      final start = DateTime(day.year, day.month);
      final end = DateTime(day.year, day.month + 1, 0);
      return (start, end);
  }
}

SleepStageBreakdown _breakdownForDays(List<SleepDaySummary> days) {
  return days.fold(
    _emptySleepStageBreakdown,
    (sum, day) => sum.merge(day.breakdown),
  );
}

int? _scoreForDays(List<SleepDaySummary> days) {
  if (days.isEmpty) return null;
  final total = days.fold<int>(0, (sum, day) => sum + day.score);
  return (total / days.length).round();
}

bool _hasDay(List<SleepDaySummary> days, DateTime day) {
  return days.any((item) => _sameDay(item.day, day));
}

bool _sameDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String _shortDate(DateTime date) => '${date.month}/${date.day}/${date.year}';

String _monthName(int month) {
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return names[month.clamp(1, 12) - 1];
}

int _vitalDecimals(SleepVitalSeries series) {
  return switch (series.label) {
    'Temperature' || 'Glucose' || 'Stress' => 1,
    _ => 0,
  };
}

class SleepDayCard extends StatelessWidget {
  const SleepDayCard({required this.day, super.key});

  final SleepDaySummary day;

  @override
  Widget build(BuildContext context) {
    final hasExactSegments = day.waveform.any(
      (segment) => !segment.approximate,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    day.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  day.windowLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              hasExactSegments
                  ? 'Timestamped SDK stages'
                  : 'Stage durations estimated across session time',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SleepWaveform(day: day),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StageMetric(
                  label: 'Asleep',
                  value: durationText(day.breakdown.asleepSeconds),
                  color: const Color(0xFF3F51B5),
                ),
                StageMetric(
                  label: 'Deep',
                  value: durationText(day.breakdown.deepSeconds),
                  color: sleepStageColor(SleepType.deepSleep),
                ),
                StageMetric(
                  label: 'Light',
                  value: durationText(day.breakdown.lightSeconds),
                  color: sleepStageColor(SleepType.lightSleep),
                ),
                StageMetric(
                  label: 'REM',
                  value: durationText(day.breakdown.remSeconds),
                  color: sleepStageColor(SleepType.rem),
                ),
                StageMetric(
                  label: 'Awake',
                  value: durationText(day.breakdown.awakeSeconds),
                  color: sleepStageColor(SleepType.awake),
                ),
                StageMetric(
                  label: 'Sessions',
                  value: '${day.sessions.length}',
                  color: const Color(0xFF52616B),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...day.sessions.map(
              (session) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SleepSessionTile(session: session),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SleepWaveform extends StatelessWidget {
  const SleepWaveform({
    required this.day,
    this.dark = false,
    this.height = 148,
    super.key,
  });

  final SleepDaySummary day;
  final bool dark;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _StageLegend(
              label: 'Awake',
              color: sleepStageColor(SleepType.awake),
              dark: dark,
            ),
            _StageLegend(
              label: 'REM',
              color: sleepStageColor(SleepType.rem),
              dark: dark,
            ),
            _StageLegend(
              label: 'Light',
              color: sleepStageColor(SleepType.lightSleep),
              dark: dark,
            ),
            _StageLegend(
              label: 'Deep',
              color: sleepStageColor(SleepType.deepSleep),
              dark: dark,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: dark ? const Color(0xFF211C21) : const Color(0xFFFBFCFD),
            border: Border.all(
              color: dark ? const Color(0xFF403542) : const Color(0xFFE1E7ED),
            ),
          ),
          child: CustomPaint(painter: SleepWaveformPainter(day, dark: dark)),
        ),
      ],
    );
  }
}

class _StageLegend extends StatelessWidget {
  const _StageLegend({
    required this.label,
    required this.color,
    this.dark = false,
  });

  final String label;
  final Color color;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: dark ? const Color(0xFFEAD8EB) : null,
          ),
        ),
      ],
    );
  }
}

class SleepWaveformPainter extends CustomPainter {
  SleepWaveformPainter(this.day, {this.dark = false});

  final SleepDaySummary day;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 42.0;
    const top = 10.0;
    const bottom = 26.0;
    final right = size.width - 8 < left + 1 ? left + 1 : size.width - 8;
    final plotWidth = (right - left).clamp(1.0, double.infinity).toDouble();
    final plotHeight = size.height - top - bottom;
    final laneHeight = plotHeight / 4;
    final windowStart = day.windowStart.millisecondsSinceEpoch / 1000;
    final windowSeconds = day.windowEnd
        .difference(day.windowStart)
        .inSeconds
        .clamp(1, 86400)
        .toDouble();
    final bottomY = top + plotHeight;

    final gridPaint = Paint()
      ..color = dark ? const Color(0xFF474047) : const Color(0xFFE1E7ED)
      ..strokeWidth = 1;
    final labelStyle = TextStyle(
      color: dark ? const Color(0xFFCDBFD0) : const Color(0xFF52616B),
      fontSize: 10,
    );

    for (var lane = 0; lane < 4; lane += 1) {
      final y = top + laneHeight * lane + laneHeight / 2;
      canvas.drawLine(Offset(left, y), Offset(right, y), gridPaint);
    }

    final stageLabels = ['Awake', 'REM', 'Light', 'Deep'];
    for (var lane = 0; lane < stageLabels.length; lane += 1) {
      _paintText(
        canvas,
        stageLabels[lane],
        Offset(8, top + laneHeight * lane + laneHeight / 2 - 6),
        labelStyle,
      );
    }

    for (var marker = 0; marker < 5; marker += 1) {
      final fraction = marker / 4;
      final markerTime = day.windowStart.add(
        Duration(seconds: (windowSeconds * fraction).round()),
      );
      final x = left + plotWidth * fraction;
      canvas.drawLine(
        Offset(x, top),
        Offset(x, top + plotHeight),
        gridPaint
          ..color = dark ? const Color(0xFF332E35) : const Color(0xFFE8EEF2),
      );
      _paintText(
        canvas,
        timeOfDayLabel(markerTime),
        Offset(x - 14, size.height - 18),
        labelStyle,
      );
    }

    final areaPath = Path();
    final lineSegments =
        <({Offset start, Offset end, int sleepType, bool approximate})>[];
    final dots = <({Offset offset, int type, bool approximate})>[];
    var hasCurve = false;
    Offset? lastPoint;

    for (final segment in day.waveform) {
      final clampedStart = segment.startTimeStamp
          .clamp(
            windowStart.toInt(),
            day.windowEnd.millisecondsSinceEpoch ~/ 1000,
          )
          .toDouble();
      final clampedEnd = segment.endTimeStamp
          .clamp(
            windowStart.toInt(),
            day.windowEnd.millisecondsSinceEpoch ~/ 1000,
          )
          .toDouble();
      if (clampedEnd <= clampedStart) continue;
      final rawStartX =
          left + ((clampedStart - windowStart) / windowSeconds) * plotWidth;
      final rawEndX =
          left + ((clampedEnd - windowStart) / windowSeconds) * plotWidth;
      final startX = rawStartX.clamp(left, right).toDouble();
      final endX = rawEndX.clamp(left, right).toDouble();
      if (endX <= startX) continue;
      final y = _stageY(segment.sleepType, top, laneHeight);
      final segmentPaint = Paint()
        ..color = sleepStageColor(
          segment.sleepType,
        ).withValues(alpha: segment.approximate ? 0.16 : 0.26);
      canvas.drawRect(Rect.fromLTRB(startX, y, endX, bottomY), segmentPaint);

      if (!hasCurve) {
        areaPath.moveTo(startX, bottomY);
        areaPath.lineTo(startX, y);
        hasCurve = true;
      } else if (lastPoint != null) {
        areaPath.lineTo(startX, lastPoint.dy);
        areaPath.lineTo(startX, y);
        lineSegments.add((
          start: Offset(startX, lastPoint.dy),
          end: Offset(startX, y),
          sleepType: segment.sleepType,
          approximate: segment.approximate,
        ));
      }
      lineSegments.add((
        start: Offset(startX, y),
        end: Offset(endX, y),
        sleepType: segment.sleepType,
        approximate: segment.approximate,
      ));
      areaPath.lineTo(endX, y);
      dots.add((
        offset: Offset(startX, y),
        type: segment.sleepType,
        approximate: segment.approximate,
      ));
      dots.add((
        offset: Offset(endX, y),
        type: segment.sleepType,
        approximate: segment.approximate,
      ));
      lastPoint = Offset(endX, y);
    }

    if (hasCurve && lastPoint != null) {
      areaPath.lineTo(lastPoint.dx, bottomY);
      areaPath.close();
      canvas.drawPath(
        areaPath,
        Paint()
          ..color = (dark ? const Color(0xFFAFA1FF) : const Color(0xFF5B8DEF))
              .withValues(alpha: 0.12),
      );
      for (final line in lineSegments) {
        canvas.drawLine(
          line.start,
          line.end,
          Paint()
            ..color = sleepStageColor(
              line.sleepType,
            ).withValues(alpha: line.approximate ? 0.72 : 0.95)
            ..strokeWidth = line.approximate ? 2.0 : 2.4
            ..strokeCap = StrokeCap.round,
        );
      }
      final dotStroke = Paint()
        ..color = dark ? const Color(0xFF211C21) : const Color(0xFFFBFCFD)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      for (final dot in dots) {
        final radius = dot.approximate ? 1.8 : 2.4;
        canvas.drawCircle(
          dot.offset,
          radius,
          Paint()..color = sleepStageColor(dot.type),
        );
        canvas.drawCircle(dot.offset, radius, dotStroke);
      }
    }
  }

  double _stageY(int type, double top, double laneHeight) {
    return top + laneHeight * sleepStageLane(type) + laneHeight / 2;
  }

  void _paintText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant SleepWaveformPainter oldDelegate) {
    return oldDelegate.day != day || oldDelegate.dark != dark;
  }
}

class SleepSessionTile extends StatelessWidget {
  const SleepSessionTile({required this.session, super.key});

  final SleepSessionSummary session;

  @override
  Widget build(BuildContext context) {
    final protocol = session.isNewSleepProtocol ? 'New protocol' : 'Legacy';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFFFBFCFD),
        border: Border.all(color: const Color(0xFFE1E7ED)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.rangeLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  '$protocol · ${durationText(session.breakdown.asleepSeconds)} asleep',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '${session.breakdown.segmentCount}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class SleepSessionCard extends StatelessWidget {
  const SleepSessionCard({required this.session, super.key});

  final SleepSessionSummary session;

  @override
  Widget build(BuildContext context) {
    final protocol = session.isNewSleepProtocol ? 'New protocol' : 'Legacy';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.rangeLabel,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(protocol, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 10),
            SleepStageBar(
              breakdown: session.breakdown,
              segments: session.segments,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StageMetric(
                  label: 'Deep',
                  value: durationText(session.breakdown.deepSeconds),
                  color: sleepStageColor(SleepType.deepSleep),
                ),
                StageMetric(
                  label: 'Light',
                  value: durationText(session.breakdown.lightSeconds),
                  color: sleepStageColor(SleepType.lightSleep),
                ),
                StageMetric(
                  label: 'REM',
                  value: durationText(session.breakdown.remSeconds),
                  color: sleepStageColor(SleepType.rem),
                ),
                StageMetric(
                  label: 'Awake',
                  value: durationText(session.breakdown.awakeSeconds),
                  color: sleepStageColor(SleepType.awake),
                ),
                StageMetric(
                  label: 'Segments',
                  value: '${session.breakdown.segmentCount}',
                  color: const Color(0xFF52616B),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SleepStageBar extends StatelessWidget {
  const SleepStageBar({required this.breakdown, this.segments, super.key});

  final SleepStageBreakdown breakdown;
  final List<SleepStageSegment>? segments;

  @override
  Widget build(BuildContext context) {
    final slices = _slices();
    if (slices.isEmpty) {
      return const SizedBox(height: 12);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 14,
        child: Row(
          children: slices
              .map(
                (slice) => Expanded(
                  flex: slice.seconds.clamp(1, 1000000),
                  child: ColoredBox(color: slice.color),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  List<_SleepStageSlice> _slices() {
    final detailSegments =
        segments
            ?.where((segment) => segment.durationSeconds > 0)
            .map(
              (segment) => _SleepStageSlice(
                segment.label,
                segment.durationSeconds,
                sleepStageColor(segment.sleepType),
              ),
            )
            .toList() ??
        const <_SleepStageSlice>[];
    if (detailSegments.isNotEmpty) return detailSegments;

    return [
      _SleepStageSlice(
        'Deep',
        breakdown.deepSeconds,
        sleepStageColor(SleepType.deepSleep),
      ),
      _SleepStageSlice(
        'Light',
        breakdown.lightSeconds,
        sleepStageColor(SleepType.lightSleep),
      ),
      _SleepStageSlice(
        'REM',
        breakdown.remSeconds,
        sleepStageColor(SleepType.rem),
      ),
      _SleepStageSlice(
        'Awake',
        breakdown.awakeSeconds,
        sleepStageColor(SleepType.awake),
      ),
    ].where((slice) => slice.seconds > 0).toList();
  }
}

class _SleepStageSlice {
  const _SleepStageSlice(this.label, this.seconds, this.color);

  final String label;
  final int seconds;
  final Color color;
}

class StageMetric extends StatelessWidget {
  const StageMetric({
    required this.label,
    required this.value,
    required this.color,
    super.key,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E7ED)),
        color: const Color(0xFFFBFCFD),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

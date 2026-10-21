part of '../../main.dart';

// §5 "This week + Your week / month" (mock 6, 15a–15b). Replaces Weekly
// Insights (bug 29), which showed WeeklySeed placeholder content to real
// users as if it were theirs: a fixed sentence about Zone-2 runs, an HRV
// trend that was always 48→58 ms, 40 calm minutes every week, and three
// "For your week" cards that were written before anyone used the app.
//
// Everything here is computed from the user's own sessions and ring history.
// Where there is nothing to show it says so; nothing falls back to a seed.
// Training load is deliberately absent: the bars are time, which people read
// without being told what it means.

Future<void> openYourWeek(BuildContext context, {bool month = false}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => YourWeekScreen(startOnMonth: month)),
  );
}

/// Week (Mon-anchored) or calendar month, [offset] periods back from the
/// current one. Forward past 0 is not a period anyone has lived yet.
class PracticePeriod {
  const PracticePeriod({required this.month, required this.offset});

  final bool month;
  final int offset;

  PracticePeriod get earlier =>
      PracticePeriod(month: month, offset: offset + 1);

  PracticePeriod? get later =>
      offset == 0 ? null : PracticePeriod(month: month, offset: offset - 1);

  DateTime start(DateTime now) {
    if (month) {
      return DateTime(now.year, now.month - offset, 1);
    }
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return monday.subtract(Duration(days: 7 * offset));
  }

  /// Exclusive end.
  DateTime end(DateTime now) {
    final from = start(now);
    return month
        ? DateTime(from.year, from.month + 1, 1)
        : from.add(const Duration(days: 7));
  }

  int dayCount(DateTime now) => end(now).difference(start(now)).inDays;

  String label(DateTime now) {
    final from = start(now);
    if (month) return '${_monthNames[from.month - 1]} ${from.year}';
    if (offset == 0) return 'This week';
    if (offset == 1) return 'Last week';
    final to = from.add(const Duration(days: 6));
    return '${from.day} ${_monthNames[from.month - 1]} – '
        '${to.day} ${_monthNames[to.month - 1]}';
  }
}

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// One practice's share of a period.
class PracticeTotal {
  const PracticeTotal({
    required this.activityId,
    required this.name,
    required this.count,
    required this.minutes,
  });

  final String activityId;
  final String name;
  final int count;
  final int minutes;
}

/// Everything "Your week / month" shows, from Sessions alone.
class PeriodSummary {
  const PeriodSummary({
    required this.sessions,
    required this.minutes,
    required this.activeDays,
    required this.dayCount,
    required this.buckets,
    required this.byPractice,
    required this.mindfulMinutes,
  });

  final int sessions;
  final int minutes;
  final int activeDays;
  final int dayCount;

  /// One bucket per day (week) or per calendar week (month). Each holds the
  /// minutes per activity id, so a bar can be stacked by practice.
  final List<Map<String, int>> buckets;

  final List<PracticeTotal> byPractice;

  /// Mindfulness + wellness minutes — the "Mindful" card. Renamed from "calm
  /// minutes", which sounded like a measurement rather than a total.
  final int mindfulMinutes;

  bool get isEmpty => sessions == 0;

  static PeriodSummary of(
    List<SessionRow> rows,
    PracticePeriod period, {
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final from = period.start(today);
    final to = period.end(today);
    final days = period.dayCount(today);
    final bucketCount = period.month ? ((days + 6) ~/ 7) : days;
    final buckets = [for (var i = 0; i < bucketCount; i++) <String, int>{}];

    final activeDays = <int>{};
    final counts = <String, int>{};
    final minutesBy = <String, int>{};
    var sessions = 0;
    var minutes = 0;
    var mindful = 0;

    for (final s in rows) {
      final ended = s.endedAt;
      // A session belongs to the day it finished on (bug 32).
      if (ended == null || ended.isBefore(from) || !ended.isBefore(to)) {
        continue;
      }
      final dayIndex = DateTime(
        ended.year,
        ended.month,
        ended.day,
      ).difference(from).inDays;
      if (dayIndex < 0 || dayIndex >= days) continue;
      final mins = ended.difference(s.startedAt).inMinutes.clamp(0, 600);

      final bucket = period.month ? (dayIndex ~/ 7) : dayIndex;
      if (bucket >= 0 && bucket < buckets.length) {
        buckets[bucket].update(
          s.vyanaActivityType,
          (v) => v + mins,
          ifAbsent: () => mins,
        );
      }
      activeDays.add(dayIndex);
      counts.update(s.vyanaActivityType, (v) => v + 1, ifAbsent: () => 1);
      minutesBy.update(
        s.vyanaActivityType,
        (v) => v + mins,
        ifAbsent: () => mins,
      );
      sessions++;
      minutes += mins;
      if (s.category == 'mind' || s.category == 'wellness') mindful += mins;
    }

    final byPractice = [
      for (final id in counts.keys)
        PracticeTotal(
          activityId: id,
          name: activityById(id)?.name ?? 'Session',
          count: counts[id]!,
          minutes: minutesBy[id] ?? 0,
        ),
    ]..sort((a, b) => b.minutes.compareTo(a.minutes));

    return PeriodSummary(
      sessions: sessions,
      minutes: minutes,
      activeDays: activeDays.length,
      dayCount: days,
      buckets: buckets,
      byPractice: byPractice,
      mindfulMinutes: mindful,
    );
  }
}

/// `3h 20m` / `45m` — the shape people say out loud.
String practiceTimeLabel(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

/// The hue for one practice's segment: its pin-slot colour where the user
/// pinned it, grey otherwise. Colour marks "this one is yours" (§11).
Color practiceHue(String activityId, List<String> pins, VyanaColors t) {
  final i = pins.indexOf(activityId);
  return i < 0 ? t.mutedInk : t.pinPalette[i % t.pinPalette.length];
}

// ── This week card (Practice, under Recent) ────────────────────────────────

/// Hidden until the first session ever: an empty chart is not an invitation.
class ThisWeekCard extends ConsumerWidget {
  const ThisWeekCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final rows = ref.watch(recentSessionsProvider).valueOrNull ?? const [];
    final finished = [
      for (final s in rows)
        if (s.endedAt != null) s,
    ];
    if (finished.isEmpty) return const SizedBox.shrink();

    final pins = ref.watch(pinnedPracticesProvider);
    const period = PracticePeriod(month: false, offset: 0);
    final now = DateTime.now();
    final summary = PeriodSummary.of(finished, period, now: now);
    final todayIndex = now.weekday - 1;

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: HairlineCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        onTap: () => openYourWeek(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: MonoEyebrow('THIS WEEK', size: 10.5)),
                VyanaIcon('chevR', size: 16, color: t.mutedInk),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              summary.isEmpty
                  ? 'No sessions yet this week'
                  : '${summary.sessions} '
                        '${summary.sessions == 1 ? 'session' : 'sessions'} · '
                        '${practiceTimeLabel(summary.minutes)}',
              style: VyanaType.label.copyWith(color: t.text, fontSize: 16),
            ),
            const SizedBox(height: 2),
            Text(
              '${summary.activeDays} of 7 days',
              style: VyanaType.caption.copyWith(color: t.textSec),
            ),
            const SizedBox(height: 12),
            // Mock 6a: the bar row owns 30px and the day letters sit under
            // it at 9px. Sharing one 40px box between the two left about
            // 19px of bar, so a mid-week day came out a 9px nub and the
            // stacked colours stopped reading as a chart at all.
            _StackedBars(
              buckets: summary.buckets,
              labels: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
              pins: pins,
              // Days that have not happened yet stay empty rather than
              // reading as days with nothing done.
              futureFrom: todayIndex + 1,
              barHeight: 30,
              labelSize: 9,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Your week / month ──────────────────────────────────────────────────────

class YourWeekScreen extends ConsumerStatefulWidget {
  const YourWeekScreen({this.startOnMonth = false, super.key});

  final bool startOnMonth;

  @override
  ConsumerState<YourWeekScreen> createState() => _YourWeekScreenState();
}

class _YourWeekScreenState extends ConsumerState<YourWeekScreen> {
  late PracticePeriod _period = PracticePeriod(
    month: widget.startOnMonth,
    offset: 0,
  );

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final now = DateTime.now();
    final rows = ref.watch(recentSessionsProvider).valueOrNull ?? const [];
    final finished = [
      for (final s in rows)
        if (s.endedAt != null) s,
    ];
    final pins = ref.watch(pinnedPracticesProvider);
    final summary = PeriodSummary.of(finished, _period, now: now);
    final patterns = ref.watch(patternsProvider).valueOrNull ?? const [];
    final ring = ref.watch(ringControllerProvider);

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
                    child: Text(
                      _period.month ? 'Your month' : 'Your week',
                      style: VyanaType.appBarSerif.copyWith(color: t.text),
                    ),
                  ),
                  IconBtn(
                    icon: 'calendar',
                    onTap: () => openSessionHistory(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _PeriodSwitch(
                month: _period.month,
                onPick: (month) => setState(
                  () => _period = PracticePeriod(month: month, offset: 0),
                ),
              ),
              const SizedBox(height: 12),
              _PeriodRow(
                label: _period.label(now),
                onEarlier: () => setState(() => _period = _period.earlier),
                // Forward stops at the current period: there is nothing
                // ahead to look at.
                onLater: _period.later == null
                    ? null
                    : () => setState(() => _period = _period.later!),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _PeriodStat(label: 'SESSIONS', value: '${summary.sessions}'),
                  _PeriodStat(
                    label: 'TIME',
                    value: practiceTimeLabel(summary.minutes),
                  ),
                  _PeriodStat(
                    label: 'DAYS',
                    value: '${summary.activeDays}/${summary.dayCount}',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (summary.isEmpty)
                Text(
                  _period.offset == 0
                      ? 'No sessions yet this ${_period.month ? 'month' : 'week'}.'
                      : 'No sessions in this period.',
                  style: VyanaType.caption.copyWith(
                    color: t.textSec,
                    height: 1.45,
                  ),
                )
              else ...[
                SizedBox(
                  height: 120,
                  child: _StackedBars(
                    buckets: summary.buckets,
                    labels: _bucketLabels(_period, now),
                    pins: pins,
                    futureFrom: _futureFrom(_period, now),
                    showScale: true,
                  ),
                ),
                const SizedBox(height: 20),
                const SectionHead(
                  eyebrow: 'Where it went',
                  title: 'By practice',
                ),
                for (final p in summary.byPractice)
                  _ByPracticeRow(total: p, pins: pins),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _MindfulCard(minutes: summary.mindfulMinutes),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HrvCard(controller: ring, period: _period),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // The patterns list already does the job "What works for you"
              // pretended to, from real evidence.
              _PatternsRow(count: patterns.length),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _bucketLabels(PracticePeriod period, DateTime now) {
    if (!period.month) return const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final weeks = (period.dayCount(now) + 6) ~/ 7;
    return [for (var i = 1; i <= weeks; i++) 'W$i'];
  }

  /// Index of the first bucket that has not happened yet, or -1 when the
  /// whole period is in the past.
  int _futureFrom(PracticePeriod period, DateTime now) {
    if (period.offset != 0) return -1;
    final elapsed = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(period.start(now)).inDays;
    return period.month ? (elapsed ~/ 7) + 1 : elapsed + 1;
  }
}

class _PeriodSwitch extends StatelessWidget {
  const _PeriodSwitch({required this.month, required this.onPick});

  final bool month;
  final ValueChanged<bool> onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    Widget option(String label, bool value) {
      final active = month == value;
      return Expanded(
        child: InkWell(
          onTap: () => onPick(value),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            decoration: BoxDecoration(
              color: active ? t.elevated : null,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: active ? t.green : t.hairline),
            ),
            child: Text(
              label,
              style: VyanaType.caption.copyWith(
                color: active ? t.text : t.textSec,
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        option('Week', false),
        const SizedBox(width: 8),
        option('Month', true),
      ],
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({
    required this.label,
    required this.onEarlier,
    required this.onLater,
  });

  final String label;
  final VoidCallback onEarlier;
  final VoidCallback? onLater;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Row(
      children: [
        IconBtn(icon: 'chevL', onTap: onEarlier),
        Expanded(
          child: Center(
            child: Text(
              label,
              style: VyanaType.label.copyWith(color: t.text, fontSize: 15.5),
            ),
          ),
        ),
        Opacity(
          opacity: onLater == null ? 0.35 : 1,
          child: IconBtn(icon: 'chevR', onTap: onLater),
        ),
      ],
    );
  }
}

class _PeriodStat extends StatelessWidget {
  const _PeriodStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: HairlineCard(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              MonoEyebrow(label, size: 9.5),
              const SizedBox(height: 5),
              Text(
                value,
                style: VyanaType.titleSerif.copyWith(
                  color: t.text,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stacked bars: one segment per practice, in its pin-slot hue. Time, not a
/// load index — people read minutes without being told what they mean.
class _StackedBars extends StatelessWidget {
  const _StackedBars({
    required this.buckets,
    required this.labels,
    required this.pins,
    this.futureFrom = -1,
    this.showScale = false,
    this.barHeight,
    this.labelSize = 11.5,
  });

  final List<Map<String, int>> buckets;
  final List<String> labels;
  final List<String> pins;

  /// Buckets from this index on have not happened yet.
  final int futureFrom;
  final bool showScale;

  /// Fixed height for the bar row. Null fills the parent, which needs a
  /// bounded height above it.
  final double? barHeight;
  final double labelSize;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final totals = [
      for (final b in buckets) b.values.fold<int>(0, (a, v) => a + v),
    ];
    final peak = totals.isEmpty ? 0 : totals.reduce(math.max);
    final bars = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < buckets.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: _Bar(
                segments: buckets[i],
                total: totals[i],
                peak: peak,
                pins: pins,
                isFuture: futureFrom >= 0 && i >= futureFrom,
              ),
            ),
          ),
      ],
    );
    return Column(
      mainAxisSize: barHeight == null ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (barHeight == null)
          Expanded(child: bars)
        else
          SizedBox(height: barHeight, child: bars),
        const SizedBox(height: 5),
        Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Center(
                  child: Text(
                    labels[i],
                    style: VyanaType.mono10.copyWith(
                      fontSize: labelSize,
                      color: futureFrom >= 0 && i >= futureFrom
                          ? t.textMuted
                          : t.mutedInk,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (showScale && peak > 0) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'peak ${practiceTimeLabel(peak)}',
              style: VyanaType.mono10.copyWith(color: t.textMuted),
            ),
          ),
        ],
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.segments,
    required this.total,
    required this.peak,
    required this.pins,
    required this.isFuture,
  });

  final Map<String, int> segments;
  final int total;
  final int peak;
  final List<String> pins;
  final bool isFuture;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    if (isFuture || total == 0 || peak == 0) {
      // An empty day is a hairline, not a zero-height nothing: the row still
      // reads as seven days.
      return Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 3,
          decoration: BoxDecoration(
            color: t.hairline,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
    }
    final ordered = segments.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    // Mock 6a: each practice is its own rounded segment with a 1.5px gap,
    // largest at the bottom. Clipping the whole bar instead ran the hues
    // together, so a day holding two practices read as one block.
    return FractionallySizedBox(
      heightFactor: (total / peak).clamp(0.06, 1.0),
      alignment: Alignment.bottomCenter,
      child: Column(
        children: [
          for (var i = ordered.length - 1; i >= 0; i--) ...[
            if (i < ordered.length - 1) const SizedBox(height: 1.5),
            Expanded(
              flex: ordered[i].value.clamp(1, 1 << 20),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: practiceHue(ordered[i].key, pins, t),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ByPracticeRow extends StatelessWidget {
  const _ByPracticeRow({required this.total, required this.pins});

  final PracticeTotal total;
  final List<String> pins;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final activity = activityById(total.activityId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: HairlineCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        onTap: activity == null
            ? null
            : () => openActivityDetail(context, activity),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: practiceHue(total.activityId, pins, t),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                total.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: VyanaType.caption.copyWith(
                  color: t.text,
                  fontSize: 14.5,
                ),
              ),
            ),
            Text(
              '${total.count} · ${practiceTimeLabel(total.minutes)}',
              style: VyanaType.mono12.copyWith(color: t.textSec),
            ),
            const SizedBox(width: 6),
            VyanaIcon('chevR', size: 15, color: t.textMuted),
          ],
        ),
      ),
    );
  }
}

class _MindfulCard extends StatelessWidget {
  const _MindfulCard({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return HairlineCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          MonoEyebrow('MINDFUL', size: 9.5),
          const SizedBox(height: 6),
          Text(
            practiceTimeLabel(minutes),
            style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 22),
          ),
          const SizedBox(height: 3),
          Text(
            'Mindfulness and wellness',
            style: VyanaType.caption.copyWith(color: t.textSec, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Overnight HRV per night (hrvForDay), with §14's base as a dashed line.
/// The old card drew a fixed 48→58 ms for everyone.
class _HrvCard extends StatelessWidget {
  const _HrvCard({required this.controller, required this.period});

  final RingController controller;
  final PracticePeriod period;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final history = controller.history;
    final hrvPoints = vitalHistoryPoints(history, VitalsMetricKind.hrv);
    final now = DateTime.now();
    final from = period.start(now);
    final to = period.end(now);
    final values = <double>[
      for (final n in sleepDaySummaries(history.sleep).reversed)
        if (!n.day.isBefore(from) && n.day.isBefore(to))
          ?hrvForDay(hrvPoints: hrvPoints, night: n, day: n.day)?.toDouble(),
    ];
    final base = readinessHrvRange;
    return HairlineCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          MonoEyebrow('HRV', size: 9.5),
          const SizedBox(height: 6),
          Text(
            values.isEmpty ? '—' : '${values.last.round()}',
            style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 22),
          ),
          const SizedBox(height: 3),
          Text(
            values.isEmpty ? 'No nights recorded' : 'ms · overnight',
            style: VyanaType.caption.copyWith(color: t.textSec, fontSize: 12),
          ),
          if (values.length >= 2) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 30,
              child: CustomPaint(
                size: Size.infinite,
                painter: _HrvSparkPainter(
                  values: values,
                  baseValue: (base.low + base.high) / 2,
                  line: t.vit('hrv'),
                  baseline: t.hairline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HrvSparkPainter extends CustomPainter {
  _HrvSparkPainter({
    required this.values,
    required this.baseValue,
    required this.line,
    required this.baseline,
  });

  final List<double> values;
  final double baseValue;
  final Color line;
  final Color baseline;

  @override
  void paint(Canvas canvas, Size size) {
    final all = [...values, baseValue];
    final lo = all.reduce(math.min);
    final hi = all.reduce(math.max);
    final span = (hi - lo).abs() < 0.001 ? 1.0 : hi - lo;
    double y(double v) => size.height - ((v - lo) / span) * size.height;
    double x(int i) =>
        values.length == 1 ? 0 : (i / (values.length - 1)) * size.width;

    // The base, dashed — what tonight is being compared with.
    final basePaint = Paint()
      ..color = baseline
      ..strokeWidth = 1;
    final by = y(baseValue);
    for (var dx = 0.0; dx < size.width; dx += 6) {
      canvas.drawLine(Offset(dx, by), Offset(dx + 3, by), basePaint);
    }

    final path = Path()..moveTo(x(0), y(values.first));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(x(i), y(values[i]));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _HrvSparkPainter old) =>
      old.values != values || old.baseValue != baseValue;
}

class _PatternsRow extends ConsumerWidget {
  const _PatternsRow({required this.count});

  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    return HairlineCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      onTap: () => openPatternsList(context),
      child: Row(
        children: [
          VyanaIcon('sparkles', size: 16, color: t.heading),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'Patterns',
              style: VyanaType.label.copyWith(color: t.text, fontSize: 15),
            ),
          ),
          Text(
            count == 0 ? 'None yet' : '$count holding',
            style: VyanaType.mono12.copyWith(color: t.textSec),
          ),
          const SizedBox(width: 6),
          VyanaIcon('chevR', size: 16, color: t.textMuted),
        ],
      ),
    );
  }
}

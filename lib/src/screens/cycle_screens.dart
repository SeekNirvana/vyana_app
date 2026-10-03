part of '../../main.dart';

/// §14b — the Cycle section at the end of Metrics, its calendar, the one-time
/// opt-in sheet, and pregnancy mode. Everything here renders only while the
/// profile says female *and* the user opted in; for any other value none of
/// it exists, and the stored data is kept so it returns if they change back.

// ── 13a · Opt-in sheet ───────────────────────────────────────────────────

Future<void> offerCycleTracking(BuildContext context, WidgetRef ref) async {
  final profile = ref.read(userProfileProvider).valueOrNull;
  if (profile == null || !profile.shouldOfferCycleSheet) return;
  final t = context.vyana;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        16, 0, 16, 16 + MediaQuery.paddingOf(sheetContext).bottom,
      ),
      child: Panel(
        pad: 18,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MonoEyebrow('ON THIS PHONE ONLY', size: 9),
            const SizedBox(height: 6),
            Text(
              'Your cycle',
              style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 21),
            ),
            const SizedBox(height: 6),
            Text(
              'Resting heart rate, HRV and temperature shift across the '
              'cycle. Knowing the phase keeps Vyana from reading that monthly '
              'change as stress.',
              style: VyanaType.caption.copyWith(color: t.textSec, height: 1.4),
            ),
            const SizedBox(height: 14),
            for (final (label, mode) in const [
              ('Track my cycle', CycleMode.tracking),
              ("I'm pregnant", CycleMode.pregnant),
              ('I no longer have periods', CycleMode.none),
              ('Not for me', CycleMode.off),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Panel(
                  pad: 13,
                  onTap: () async {
                    await ref.read(userProfileProvider.notifier).save(
                          profile.copyWith(
                            cycleMode: mode,
                            cycleSheetSeen: true,
                          ),
                        );
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: VyanaType.label.copyWith(color: t.text),
                        ),
                      ),
                      VyanaIcon('chevronRight', size: 17, color: t.mutedInk),
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

// ── 13b · The Cycle section on Metrics ───────────────────────────────────

class CycleBlock extends ConsumerWidget {
  const CycleBlock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    if (profile == null || !profile.showsCycle) return const SizedBox.shrink();
    if (profile.cycleMode == CycleMode.pregnant) {
      return _PregnancyCard(profile: profile);
    }
    return const _CycleCard();
  }
}

class _CycleCard extends ConsumerWidget {
  const _CycleCard();

  Future<void> _startPeriod(WidgetRef ref) async {
    await ref.read(databaseProvider).addCycleDay(DateTime.now());
  }

  Future<void> _endPeriod(WidgetRef ref, CycleStatus status) async {
    // "Period ended" records the length rather than assuming it: the last
    // logged day of the run becomes its confirmed end.
    final latest = status.runs.first;
    await ref.read(databaseProvider).confirmCycleEnd(latest.end);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final rows = ref.watch(cycleDaysProvider).valueOrNull ?? const [];
    final status = rows.isEmpty ? null : cycleStatusFrom(rows);
    final running = status?.periodInProgress ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Cycle',
                style:
                    VyanaType.label.copyWith(color: t.heading, fontSize: 16.5),
              ),
            ),
            BorderedPill(
              label: running ? 'Period ended' : 'Period started',
              color: t.idCycle,
              onTap: () => running && status != null
                  ? _endPeriod(ref, status)
                  : _startPeriod(ref),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (status == null)
          Text(
            'Tap Period started on the first day and the cycle builds itself '
            'from there. No setup questions.',
            style: VyanaType.caption.copyWith(
              color: t.textSec,
              fontSize: 13,
              height: 1.45,
            ),
          )
        else ...[
          if (status.shouldAskEnd) _CycleEndPrompt(status: status),
          InkWell(
            onTap: () => openCycleCalendar(context),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
              decoration: BoxDecoration(
                color: t.elevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: t.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Wraps so day + phase never squashes at large text.
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Day ${status.cycleDay}',
                        style: VyanaType.label.copyWith(
                          color: t.text,
                          fontSize: 15,
                        ),
                      ),
                      if (status.phase != null)
                        MonoEyebrow(
                          status.phase!.label.toUpperCase(),
                          size: 11.5,
                          spacing: 0.9,
                          color: t.idCycle,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _CycleStrip(status: status),
                  const SizedBox(height: 10),
                  Text(
                    status.nextPeriodStart == null
                        ? 'Next period fills in once a cycle completes.'
                        : 'Next period around ${_cycleDate(status.nextPeriodStart!)}',
                    style: VyanaType.caption.copyWith(
                      color: t.textSec,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Asks once, two days after the proposed end, so it never interrupts a
/// longer-than-usual period. No answer leaves the average length stored.
class _CycleEndPrompt extends ConsumerWidget {
  const _CycleEndPrompt({required this.status});

  final CycleStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final proposed = status.proposedEnd;
    if (proposed == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: BoxDecoration(
        color: t.elevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Did your period end on ${_cycleDate(proposed)}?',
            style: VyanaType.bodySm.copyWith(color: t.text, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              BorderedPill(
                label: 'Yes',
                onTap: () async {
                  final db = ref.read(databaseProvider);
                  // Log through to the proposed end, then confirm it.
                  var day = status.runs.first.start;
                  while (!day.isAfter(proposed)) {
                    await db.addCycleDay(day);
                    day = day.add(const Duration(days: 1));
                  }
                  await db.confirmCycleEnd(proposed);
                },
              ),
              BorderedPill(
                label: 'Pick a day',
                onTap: () => openCycleCalendar(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A strip of the current cycle — logged days filled, expected days dashed.
class _CycleStrip extends StatelessWidget {
  const _CycleStrip({required this.status});

  final CycleStatus status;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final length = status.averageCycleLength ?? kDefaultCycleLength;
    final day = status.cycleDay ?? 1;
    final periodLength = status.averagePeriodLength ?? kDefaultPeriodLength;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            for (var i = 1; i <= length; i++)
              Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(right: i == length ? 0 : 1.5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: i <= periodLength
                        ? t.idCycle.withValues(alpha: i <= day ? 0.95 : 0.3)
                        : (i == day
                            ? t.text.withValues(alpha: 0.65)
                            : t.hairline),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── 13d · Pregnancy ──────────────────────────────────────────────────────

class _PregnancyCard extends ConsumerWidget {
  const _PregnancyCard({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final status = pregnancyStatusFor(profile.dueDate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pregnancy',
          style: VyanaType.label.copyWith(color: t.heading, fontSize: 16.5),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
          decoration: BoxDecoration(
            color: t.elevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.hairline),
          ),
          child: status == null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add your due date and the weeks fill in here.',
                      style: VyanaType.bodySm
                          .copyWith(color: t.textSec, fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    BorderedPill(
                      label: 'Add due date',
                      onTap: () => openPregnancyDueDate(context, ref),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Week ${status.week}',
                          style: VyanaType.label
                              .copyWith(color: t.text, fontSize: 15),
                        ),
                        MonoEyebrow(
                          status.trimesterLabel.toUpperCase(),
                          size: 11.5,
                          spacing: 0.9,
                          color: t.idCycle,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: status.progress,
                        minHeight: 6,
                        backgroundColor: t.hairline,
                        valueColor: AlwaysStoppedAnimation(t.idCycle),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Due ${_cycleDate(status.dueDate)} · 40 weeks',
                      style: VyanaType.caption
                          .copyWith(color: t.textSec, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your personal baselines are paused: resting heart rate '
                      'rises and HRV falls through pregnancy, so flagging '
                      'that would be wrong. Vitals read against the typical '
                      'range only.',
                      style: VyanaType.caption.copyWith(
                        color: t.mutedInk,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

Future<void> openPregnancyDueDate(BuildContext context, WidgetRef ref) async {
  final profile = ref.read(userProfileProvider).valueOrNull;
  if (profile == null) return;
  final now = DateTime.now();
  final picked = await showDatePicker(
    context: context,
    initialDate: profile.dueDate ?? now.add(const Duration(days: 180)),
    firstDate: now.subtract(const Duration(days: 60)),
    lastDate: now.add(const Duration(days: 300)),
    helpText: 'Due date',
  );
  if (picked == null) return;
  await ref
      .read(userProfileProvider.notifier)
      .save(profile.copyWith(dueDate: picked));
}

// ── 13c · Calendar ───────────────────────────────────────────────────────

void openCycleCalendar(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const CycleCalendarScreen()),
  );
}

class CycleCalendarScreen extends ConsumerStatefulWidget {
  const CycleCalendarScreen({super.key});

  @override
  ConsumerState<CycleCalendarScreen> createState() =>
      _CycleCalendarScreenState();
}

class _CycleCalendarScreenState extends ConsumerState<CycleCalendarScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  Future<void> _toggle(DateTime day, Set<DateTime> logged) async {
    final db = ref.read(databaseProvider);
    if (logged.contains(day)) {
      await db.removeCycleDay(day);
    } else {
      await db.addCycleDay(day);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(cycleDaysProvider).valueOrNull ?? const [];
    final logged = {
      for (final r in rows) DateTime(r.day.year, r.day.month, r.day.day),
    };
    final status = rows.isEmpty ? null : cycleStatusFrom(rows);

    return _EditorScaffold(
      title: 'Cycle',
      sub: 'Metrics',
      ctaLabel: 'Done',
      ctaIcon: 'check',
      onSave: () => Navigator.of(context).pop(),
      children: [
          _MonthHeader(
            month: _month,
            onPrev: () => setState(
              () => _month = DateTime(_month.year, _month.month - 1),
            ),
            onNext: () {
              final now = DateTime.now();
              final next = DateTime(_month.year, _month.month + 1);
              // Never page past the current month: there is nothing to log.
              if (next.isAfter(DateTime(now.year, now.month))) return;
              setState(() => _month = next);
            },
          ),
          const SizedBox(height: 10),
          _MonthGrid(
            month: _month,
            logged: logged,
            status: status,
            onTapDay: (day) => _toggle(day, logged),
          ),
          const SizedBox(height: 18),
          _CycleLegend(),
        const SizedBox(height: 20),
        if (status != null) _CycleFacts(status: status),
      ],
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  static const _names = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Row(
      children: [
        InkWell(
          onTap: onPrev,
          borderRadius: BorderRadius.circular(100),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: VyanaIcon('chevronLeft', size: 20, color: t.textSec),
          ),
        ),
        Expanded(
          child: Text(
            '${_names[month.month - 1]} ${month.year}',
            textAlign: TextAlign.center,
            style: VyanaType.label.copyWith(color: t.text, fontSize: 15.5),
          ),
        ),
        InkWell(
          onTap: onNext,
          borderRadius: BorderRadius.circular(100),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: VyanaIcon('chevronRight', size: 20, color: t.textSec),
          ),
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.logged,
    required this.status,
    required this.onTapDay,
  });

  final DateTime month;
  final Set<DateTime> logged;
  final CycleStatus? status;
  final ValueChanged<DateTime> onTapDay;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Monday-first, matching the rest of the app's day labels.
    final leading = first.weekday - 1;
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);

    final expected = <DateTime>{};
    final ovulation = <DateTime>{};
    final s = status;
    if (s != null) {
      final next = s.nextPeriodStart;
      if (next != null) {
        final length = s.averagePeriodLength ?? kDefaultPeriodLength;
        for (var i = 0; i < length; i++) {
          expected.add(next.add(Duration(days: i)));
        }
      }
      final ov = s.estimatedOvulation;
      if (ov != null) ovulation.add(ov);
    }

    return Column(
      children: [
        Row(
          children: [
            for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: Center(
                  child: MonoEyebrow(d, size: 11.5, spacing: 0.9),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var week = 0; week < ((leading + daysInMonth + 6) ~/ 7); week++)
          Row(
            children: [
              for (var slot = 0; slot < 7; slot++)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final dayNumber = week * 7 + slot - leading + 1;
                      if (dayNumber < 1 || dayNumber > daysInMonth) {
                        return const SizedBox(height: 44);
                      }
                      final day =
                          DateTime(month.year, month.month, dayNumber);
                      final isLogged = logged.contains(day);
                      final isExpected = expected.contains(day);
                      final isOvulation = ovulation.contains(day);
                      final isToday = day == todayDay;
                      final inFuture = day.isAfter(todayDay);
                      return _DayCell(
                        label: '$dayNumber',
                        logged: isLogged,
                        expected: isExpected,
                        ovulation: isOvulation,
                        today: isToday,
                        // Logging a future day makes no sense; predictions
                        // still render there.
                        onTap: inFuture ? null : () => onTapDay(day),
                        ink: t,
                      );
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.label,
    required this.logged,
    required this.expected,
    required this.ovulation,
    required this.today,
    required this.onTap,
    required this.ink,
  });

  final String label;
  final bool logged;
  final bool expected;
  final bool ovulation;
  final bool today;
  final VoidCallback? onTap;
  final VyanaColors ink;

  @override
  Widget build(BuildContext context) {
    final t = ink;
    return SizedBox(
      height: 44,
      child: Center(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(100),
          child: CustomPaint(
            painter: _DayMarkPainter(
              logged: logged,
              expected: expected,
              ovulation: ovulation,
              today: today,
              cycle: t.idCycle,
              muted: t.mutedInk,
              outline: t.text,
            ),
            child: SizedBox(
              width: 34,
              height: 34,
              child: Center(
                child: Text(
                  label,
                  style: VyanaType.caption.copyWith(
                    fontSize: 13,
                    color: logged ? Colors.white : t.textSec,
                    fontWeight: logged || today
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayMarkPainter extends CustomPainter {
  _DayMarkPainter({
    required this.logged,
    required this.expected,
    required this.ovulation,
    required this.today,
    required this.cycle,
    required this.muted,
    required this.outline,
  });

  final bool logged;
  final bool expected;
  final bool ovulation;
  final bool today;
  final Color cycle;
  final Color muted;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;

    if (logged) {
      canvas.drawCircle(center, radius, Paint()..color = cycle);
    } else if (expected) {
      _dashedCircle(canvas, center, radius, cycle);
    } else if (ovulation) {
      _dashedCircle(canvas, center, radius, muted);
    }
    if (today) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = outline,
      );
    }
  }

  void _dashedCircle(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = color;
    const dashes = 14;
    const sweep = math.pi * 2 / dashes;
    for (var i = 0; i < dashes; i += 2) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * sweep,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DayMarkPainter old) =>
      old.logged != logged ||
      old.expected != expected ||
      old.ovulation != ovulation ||
      old.today != today ||
      old.cycle != cycle;
}

class _CycleLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        _LegendDot(label: 'Logged', color: t.idCycle, filled: true),
        _LegendDot(label: 'Expected', color: t.idCycle, filled: false),
        _LegendDot(label: 'Ovulation (est.)', color: t.mutedInk, filled: false),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.label,
    required this.color,
    required this.filled,
  });

  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? color : null,
            border: filled ? null : Border.all(color: color, width: 1.4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: VyanaType.caption.copyWith(color: t.textSec, fontSize: 12.5),
        ),
      ],
    );
  }
}

/// Each number states the count it is from, so a one-cycle average never
/// passes for a settled one.
class _CycleFacts extends StatelessWidget {
  const _CycleFacts({required this.status});

  final CycleStatus status;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final spread = status.cycleLengthSpread;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MonoEyebrow('YOUR CYCLE', size: 11.5, spacing: 0.9),
        const SizedBox(height: 8),
        _FactRow(
          label: 'Next period',
          value: status.nextPeriodStart == null
              ? '—'
              : '${_cycleDate(status.nextPeriodStart!)}'
                  '${spread != null && spread > 0 ? ' ± $spread d' : ''}',
          note: status.cycleCount == 0
              ? 'from a 28-day estimate'
              : 'from ${status.cycleCount} '
                  '${status.cycleCount == 1 ? 'cycle' : 'cycles'}',
        ),
        _FactRow(
          label: 'Estimated ovulation',
          value: status.estimatedOvulation == null
              ? '—'
              : _cycleDate(status.estimatedOvulation!),
          note: 'estimated',
        ),
        _FactRow(
          label: 'Average cycle',
          value: status.averageCycleLength == null
              ? '—'
              : '${status.averageCycleLength} days',
          note: status.cycleCount == 0
              ? 'needs two periods'
              : 'from ${status.cycleCount} '
                  '${status.cycleCount == 1 ? 'cycle' : 'cycles'}',
        ),
        _FactRow(
          label: 'Average period',
          value: status.averagePeriodLength == null
              ? '—'
              : '${status.averagePeriodLength} days',
          note: status.periodCount == 0
              ? 'needs one finished period'
              : 'from ${status.periodCount} '
                  '${status.periodCount == 1 ? 'period' : 'periods'}',
        ),
        const SizedBox(height: 10),
        Text(
          'Tap any day to add or remove it. Correcting a missed start or a '
          'wrong end is one tap, and every number here follows.',
          style: VyanaType.caption.copyWith(
            color: t.mutedInk,
            fontSize: 12.5,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.label,
    required this.value,
    required this.note,
  });

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.hairline)),
      ),
      // Wraps rather than squashing when the note is long or text is large.
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 2,
        children: [
          Text(
            label,
            style: VyanaType.bodySm.copyWith(color: t.text, fontSize: 14),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: VyanaType.label.copyWith(color: t.text, fontSize: 14),
              ),
              MonoEyebrow(note.toUpperCase(), size: 11.5, spacing: 0.9),
            ],
          ),
        ],
      ),
    );
  }
}

String _cycleDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day} ${months[d.month - 1]}';
}

/// One line describing what the cycle row is doing, in the row's own voice.
String cycleSubtitleFor(CycleMode mode) => switch (mode) {
      CycleMode.off => 'Not tracking · phase-aware baselines are off',
      CycleMode.tracking => 'Phase-aware baselines for HR, HRV and temperature',
      CycleMode.pregnant => 'Pregnancy mode · personal baselines paused',
      CycleMode.none => 'Not tracking',
    };

/// Changeable any time, as §14b requires. Switching away from tracking keeps
/// the logged days, so turning it back on restores the history.
Future<void> showCycleModeSheet(BuildContext context, WidgetRef ref) {
  final t = context.vyana;
  final profile =
      ref.read(userProfileProvider).valueOrNull ?? const UserProfile();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        16, 0, 16, 16 + MediaQuery.paddingOf(sheetContext).bottom,
      ),
      child: Panel(
        pad: 18,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MonoEyebrow('ON THIS PHONE ONLY', size: 9),
            const SizedBox(height: 6),
            Text(
              'Cycle tracking',
              style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 21),
            ),
            const SizedBox(height: 6),
            Text(
              'Turning this off hides the cycle screens and keeps what you '
              'have logged, so it returns if you switch back on.',
              style: VyanaType.caption.copyWith(color: t.textSec, height: 1.4),
            ),
            const SizedBox(height: 14),
            for (final mode in CycleMode.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Panel(
                  pad: 13,
                  onTap: () async {
                    final navigator = Navigator.of(sheetContext);
                    await ref.read(userProfileProvider.notifier).save(
                          profile.copyWith(
                            cycleMode: mode,
                            cycleSheetSeen: true,
                            clearDueDate: mode != CycleMode.pregnant,
                          ),
                        );
                    if (navigator.canPop()) navigator.pop();
                    // Pregnancy needs a due date before it can say anything.
                    if (mode == CycleMode.pregnant && context.mounted) {
                      await openPregnancyDueDate(context, ref);
                    }
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          mode.label,
                          style: VyanaType.label.copyWith(
                            color: profile.cycleMode == mode
                                ? t.green
                                : t.text,
                          ),
                        ),
                      ),
                      if (profile.cycleMode == mode)
                        VyanaIcon('check', size: 16, color: t.green),
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

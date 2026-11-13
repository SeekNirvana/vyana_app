part of '../../main.dart';

/// Item 46 — "My week" (mock 17d–17e): the optional weekly plan.
///
/// Up to [kWeeklyPlanMaxPerDay] practices per weekday, in the user's order,
/// chosen from the whole catalogue rather than only from pins. Every day
/// starts empty; with no plan nothing changes anywhere else in the app.

void openMyWeek(BuildContext context) {
  Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => const MyWeekScreen()),
  );
}

/// The subtitle on the You row: the planned days, or the invitation.
String weeklyPlanSubtitle(WeeklyPlan plan) {
  if (plan.isEmpty) {
    return 'Plan up to three practices a day — entirely optional';
  }
  final days = [
    for (var weekday = 1; weekday <= 7; weekday++)
      if (!plan.forWeekday(weekday).isEmpty) kShortWeekdays[weekday - 1],
  ];
  final count = plan.days.values.fold<int>(
    0,
    (sum, d) => sum + d.activityIds.length,
  );
  return '${days.join(' · ')} · $count '
      '${count == 1 ? 'practice' : 'practices'}';
}

class MyWeekScreen extends ConsumerWidget {
  const MyWeekScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final plan = ref.watch(weeklyPlanProvider);
    final remind = ref.watch(weeklyPlanReminderProvider);
    final today = DateTime.now().weekday;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: t.bgGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
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
                          'PRACTICE',
                          style: VyanaType.eyebrow.copyWith(color: t.gold),
                        ),
                        Text(
                          'My week',
                          style: VyanaType.appBarSerif.copyWith(color: t.text),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Entirely optional. Plan up to three practices on any day and '
                'the first one you have not done becomes that day\'s '
                'suggestion. Anything else you do still counts — the limit is '
                'on planning, not on doing.',
                style: VyanaType.caption.copyWith(
                  color: t.textSec,
                  height: 1.5,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 16),
              for (var weekday = 1; weekday <= 7; weekday++) ...[
                _PlannedDayRow(
                  weekday: weekday,
                  day: plan.forWeekday(weekday),
                  isToday: weekday == today,
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 10),
              HairlineCard(
                padding: const EdgeInsets.fromLTRB(13, 11, 11, 11),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Remind me',
                            style: VyanaType.label.copyWith(
                              color: t.text,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'One notification on a planned day, at the time '
                            'you usually start — and only if it is not done.',
                            style: VyanaType.caption.copyWith(
                              color: t.textSec,
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Switch(
                      value: remind,
                      onChanged: plan.isEmpty
                          ? null
                          : (on) => unawaited(
                                ref
                                    .read(weeklyPlanReminderProvider.notifier)
                                    .setEnabled(on),
                              ),
                    ),
                  ],
                ),
              ),
              if (!plan.isEmpty) ...[
                const SizedBox(height: 14),
                BorderedPill(
                  label: 'Clear the whole week',
                  onTap: () async {
                    await ref.read(databaseProvider).clearWeeklyPlan();
                    await ref
                        .read(weeklyPlanReminderProvider.notifier)
                        .reschedule();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One weekday: its planned practices in order, and a way to add another.
class _PlannedDayRow extends ConsumerWidget {
  const _PlannedDayRow({
    required this.weekday,
    required this.day,
    required this.isToday,
  });

  final int weekday;
  final PlannedDay day;
  final bool isToday;

  static const _names = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final picked = await pickActivity(context, title: _names[weekday - 1]);
    if (picked == null) return;
    await ref.read(databaseProvider).setWeeklyPlanDay(
          weekday,
          [...day.activityIds, picked.id],
        );
    await ref.read(weeklyPlanReminderProvider.notifier).reschedule();
  }

  Future<void> _remove(WidgetRef ref, String activityId) async {
    await ref.read(databaseProvider).setWeeklyPlanDay(
          weekday,
          [
            for (final id in day.activityIds)
              if (id != activityId) id,
          ],
        );
    await ref.read(weeklyPlanReminderProvider.notifier).reschedule();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final full = day.activityIds.length >= kWeeklyPlanMaxPerDay;
    return HairlineCard(
      padding: const EdgeInsets.fromLTRB(13, 11, 11, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _names[weekday - 1],
                  style: VyanaType.label.copyWith(
                    color: isToday ? t.heading : t.text,
                    fontSize: 15,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
              if (isToday)
                MonoEyebrow('TODAY', size: 9.5, spacing: 0.8, color: t.gold),
            ],
          ),
          if (day.isEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Nothing planned',
              style: VyanaType.caption.copyWith(
                color: t.mutedInk,
                fontSize: 13,
              ),
            ),
          ] else
            for (var i = 0; i < day.activities.length; i++) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  MonoEyebrow(
                    '${i + 1}',
                    size: 10.5,
                    spacing: 0.8,
                    color: t.mutedInk,
                  ),
                  const SizedBox(width: 10),
                  VyanaIcon(
                    day.activities[i].icon,
                    size: 16,
                    color: t.heading,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      day.activities[i].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VyanaType.caption.copyWith(
                        color: t.text,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () =>
                        unawaited(_remove(ref, day.activityIds[i])),
                    borderRadius: BorderRadius.circular(100),
                    child: const SizedBox(
                      width: 44,
                      height: 36,
                      child: Center(child: VyanaIcon('close', size: 15)),
                    ),
                  ),
                ],
              ),
            ],
          const SizedBox(height: 8),
          BorderedPill(
            label: full ? 'Three is the limit' : 'Add a practice',
            onTap: full ? null : () => unawaited(_add(context, ref)),
          ),
        ],
      ),
    );
  }
}

/// A searchable catalogue picker — the whole catalogue, not only pins.
Future<Activity?> pickActivity(
  BuildContext context, {
  required String title,
}) {
  return showModalBottomSheet<Activity>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _ActivityPickerSheet(title: title),
  );
}

class _ActivityPickerSheet extends ConsumerStatefulWidget {
  const _ActivityPickerSheet({required this.title});

  final String title;

  @override
  ConsumerState<_ActivityPickerSheet> createState() =>
      _ActivityPickerSheetState();
}

class _ActivityPickerSheetState extends ConsumerState<_ActivityPickerSheet> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    // Watched so the user's own sports appear here too.
    ref.watch(userActivitiesProvider);
    final text = _query.text.trim();
    // The whole catalogue, not only pins — that is the point of planning.
    final results = text.isEmpty ? allActivities() : searchActivities(text);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Panel(
        pad: 16,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 20),
            ),
            const SizedBox(height: 10),
            _FieldBox(
              child: TextField(
                controller: _query,
                onChanged: (_) => setState(() {}),
                style: VyanaType.body.copyWith(color: t.text),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Search the catalogue',
                  hintStyle: VyanaType.body.copyWith(color: t.textMuted),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 320,
              child: ListView.builder(
                itemCount: results.length,
                itemBuilder: (_, i) {
                  final a = results[i];
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(a),
                    borderRadius: BorderRadius.circular(10),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Row(
                        children: [
                          VyanaIcon(a.icon, size: 17, color: t.heading),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              a.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: VyanaType.caption.copyWith(
                                color: t.text,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          MonoEyebrow(
                            '${a.dur} MIN',
                            size: 10,
                            spacing: 0.8,
                            color: t.mutedInk,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

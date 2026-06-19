part of '../../main.dart';

Future<void> openWeeklyInsights(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => const WeeklyInsightsScreen()),
  );
}

/// Weekly insights — the north-star correlation view. Active days, training
/// load and calm minutes are computed from the local vault (this week's
/// sessions); the longer-horizon correlation narrative stays seeded until
/// enough history accumulates.
class WeeklyInsightsScreen extends ConsumerWidget {
  const WeeklyInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final computed = ref.watch(weeklyComputedProvider).valueOrNull;
    final hasData = computed?.hasData ?? false;
    // Real load when we have sessions this week, else the seed for layout.
    final load = hasData ? computed!.loadByDay : WeeklySeed.load;
    final activeDays = hasData ? computed!.activeDays : WeeklySeed.activeDays;
    final calmMinutes = hasData ? computed!.calmMinutes : null;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: t.bgGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            children: [
              Row(
                children: [
                  IconBtn(icon: 'chevL', onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('THIS WEEK',
                            style: VyanaType.eyebrow.copyWith(color: t.gold)),
                        Text('Your patterns',
                            style: VyanaType.appBarSerif.copyWith(color: t.text)),
                      ],
                    ),
                  ),
                  IconBtn(icon: 'calendar', onTap: () => openSessionHistoryFromWeekly(context)),
                ],
              ),
              const SizedBox(height: 14),
              // North-star correlation
              Panel(
                grad: true,
                pad: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        VyanaIcon('sparkles', size: 16, color: t.gold),
                        const SizedBox(width: 8),
                        Text('WHAT WORKS FOR YOU',
                            style: VyanaType.eyebrow.copyWith(color: t.gold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      WeeklySeed.northStar,
                      style: VyanaType.titleSerif.copyWith(
                          color: t.text, fontSize: 22, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Training load
              const SectionHead(eyebrow: 'Effort', title: 'Training load'),
              Panel(
                pad: 16,
                child: _LoadBars(days: WeeklySeed.days, load: load),
              ),
              const SizedBox(height: 16),
              // HRV + calm
              Row(
                children: [
                  Expanded(
                    child: _TrendCard(
                      title: 'HRV trend',
                      data: WeeklySeed.hrvTrend,
                      accent: t.vit('hrv'),
                      suffix: 'ms',
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: _TrendCard(
                      title: 'Calm minutes',
                      data: WeeklySeed.calmMin,
                      accent: t.vit('luna'),
                      suffix: 'min',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Consistency
              Panel(
                pad: 18,
                child: Row(
                  children: [
                    ProgressRing(
                      value: activeDays / 7 * 100,
                      size: 72,
                      stroke: 7,
                      color: t.green,
                      track: t.border,
                      child: Text('$activeDays/7',
                          style: VyanaType.titleSerif.copyWith(
                              color: t.text, fontSize: 18)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Consistency',
                              style: VyanaType.label.copyWith(color: t.text)),
                          const SizedBox(height: 4),
                          Text(
                            calmMinutes != null
                                ? '$activeDays active days · $calmMinutes calm minutes this week.'
                                : '${WeeklySeed.strainLabel} · ${WeeklySeed.strainValue}. ${WeeklySeed.strainDetail}',
                            style: VyanaType.caption.copyWith(
                                color: t.textSec, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const SectionHead(eyebrow: 'Insights', title: 'For your week'),
              for (final c in WeeklySeed.cards)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Panel(
                    pad: 16,
                    accent: t.vit(c.accent),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.tag.toUpperCase(),
                            style: VyanaType.mono10.copyWith(color: t.vit(c.accent))),
                        const SizedBox(height: 6),
                        Text(c.text,
                            style: VyanaType.bodySm.copyWith(
                                color: t.textSec, height: 1.5)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Cta(
                label: 'Ask Nova about your week',
                icon: 'sparkles',
                solid: false,
                onTap: () {
                  ref.read(activeGuideIdProvider.notifier).state = 'nova';
                  ref.read(tabIndexProvider.notifier).state = 3;
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> openSessionHistoryFromWeekly(BuildContext context) =>
    openSessionHistory(context);

class _LoadBars extends StatelessWidget {
  const _LoadBars({required this.days, required this.load});
  final List<String> days;
  final List<int> load;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final maxV = load.fold<int>(1, (a, b) => a > b ? a : b);
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 90 * (load[i] / maxV),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: load[i] >= 70
                          ? t.vit('hr').withValues(alpha: 0.85)
                          : t.green.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(days[i],
                      style: VyanaType.mono10.copyWith(color: t.textMuted)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.title,
    required this.data,
    required this.accent,
    required this.suffix,
  });
  final String title;
  final List<int> data;
  final Color accent;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Panel(
      pad: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: VyanaType.caption.copyWith(color: t.textSec)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${data.last}',
                  style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 24)),
              const SizedBox(width: 3),
              Text(suffix, style: VyanaType.caption.copyWith(color: t.textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          Sparkline(
            data: data.map((e) => e.toDouble()).toList(),
            color: accent,
            width: double.infinity,
            height: 40,
          ),
        ],
      ),
    );
  }
}

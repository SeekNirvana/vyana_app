part of '../../main.dart';

Future<void> openTrends(BuildContext context) {
  return Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => const TrendsScreen()));
}

/// "Health metrics" — the one place where Vyana speaks in figures. Hosts the
/// readiness score, live vital tiles, today's movement stats, and numeric
/// insights that used to crowd the Home tab, plus doorways into every deeper
/// data view (measurements, sleep, weekly patterns, data log).
class TrendsScreen extends ConsumerWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final controller = ref.watch(ringControllerProvider);
    final dashboard = HomeDashboard.from(controller);
    final tiles = homeVitalTiles(
      vitals: controller.vitals,
      history: controller.history,
      dashboard: dashboard,
    );

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
                          'IN DEPTH',
                          style: VyanaType.eyebrow.copyWith(color: t.gold),
                        ),
                        Text(
                          'Health metrics',
                          style: VyanaType.appBarSerif.copyWith(color: t.text),
                        ),
                      ],
                    ),
                  ),
                  IconBtn(
                    icon: 'chart',
                    onTap: () => openWeeklyInsights(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (!controller.hasRingContext)
                AccessDeniedPanel(
                  title: 'Numbers arrive with PRANA',
                  message:
                      'Pair your ring and every score, trend, and chart fills in here.',
                  icon: 'ring',
                  primaryLabel: 'Buy ring',
                  onPrimary: () => openRingOrder(context),
                  secondaryLabel: 'Pair ring',
                  onSecondary: () => openScanner(context, controller),
                )
              else ...[
                _ReadinessPanel(dashboard: dashboard),
                const SizedBox(height: 16),
                _MovementPanel(dashboard: dashboard),
                const SizedBox(height: 20),
                SectionHead(
                  eyebrow: 'Live',
                  title: 'Vitals',
                  action: 'See all & test',
                  onAction: () => openMeasurements(context, controller),
                ),
                if (tiles.isEmpty)
                  Text(
                    'Run a check-in from Home and your readings will settle in here.',
                    style: VyanaType.bodySm.copyWith(color: t.textSec),
                  )
                else
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.42,
                    children: [
                      for (final tile in tiles)
                        _MiniVital(
                          tile: tile,
                          onTap: () =>
                              openVitalDetail(context, controller, tile.kind),
                        ),
                    ],
                  ),
                if (dashboard.insights.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const SectionHead(
                    eyebrow: 'On-device AI',
                    title: 'Insights for you',
                  ),
                  for (final ins in dashboard.insights)
                    _InsightCard(insight: ins),
                ],
                const SizedBox(height: 20),
                const SectionHead(eyebrow: 'Go deeper', title: 'Explore'),
                _ExploreRow(
                  icon: 'sleep',
                  accent: t.vit('sleep'),
                  label: 'Sleep detail',
                  blurb: 'Stages, timing, and night-by-night scores.',
                  onTap: () => openSleep(context, controller),
                ),
                _ExploreRow(
                  icon: 'chart',
                  accent: t.green,
                  label: 'Weekly patterns',
                  blurb: 'Training load, HRV trend, and calm minutes.',
                  onTap: () => openWeeklyInsights(context),
                ),
                _ExploreRow(
                  icon: 'db',
                  accent: t.gold,
                  label: 'Data log',
                  blurb: 'Every record your ring has synced.',
                  onTap: () => openHistory(context, controller),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Readiness score with its drivers — the numeric twin of Home's worded state.
class _ReadinessPanel extends StatelessWidget {
  const _ReadinessPanel({required this.dashboard});
  final HomeDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final score = dashboard.readinessScore;
    final delta = dashboard.readinessDelta;
    final color = score == null
        ? t.textMuted
        : score >= 65
        ? t.green
        : score >= 50
        ? t.gold
        : const Color(0xFFD9975F);

    return Panel(
      grad: true,
      pad: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('READINESS', style: VyanaType.eyebrow.copyWith(color: t.gold)),
          const SizedBox(height: 14),
          Row(
            children: [
              ProgressRing(
                value: (score ?? 0).toDouble(),
                max: 100,
                size: 96,
                stroke: 8,
                color: color,
                track: t.elevated,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      score == null ? '—' : '$score',
                      style: VyanaType.displaySerif.copyWith(color: t.text),
                    ),
                    Text(
                      'OF 100',
                      style: VyanaType.mono10.copyWith(
                        color: t.textSec,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dashboard.readinessLabel,
                      style: VyanaType.titleSerif.copyWith(
                        color: t.text,
                        fontSize: 22,
                      ),
                    ),
                    if (delta != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        delta == 0
                            ? 'Level with last night'
                            : '${delta > 0 ? '+' : ''}$delta vs last night',
                        style: VyanaType.caption.copyWith(
                          color: delta >= 0 ? t.green : t.textSec,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      'Blended from last night\'s sleep and your HRV.',
                      style: VyanaType.caption.copyWith(
                        color: t.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in dashboard.drivers) _DriverChip(driver: d),
            ],
          ),
        ],
      ),
    );
  }
}

class _DriverChip extends StatelessWidget {
  const _DriverChip({required this.driver});
  final ReadinessDriver driver;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final c = driver.good ? t.green : t.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: c.withValues(alpha: t.isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            driver.label,
            style: VyanaType.caption.copyWith(color: t.textSec),
          ),
          const SizedBox(width: 5),
          Text(
            driver.value,
            style: VyanaType.caption.copyWith(
              color: t.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Today's movement in numbers: steps, distance, calories, and the streak.
class _MovementPanel extends StatelessWidget {
  const _MovementPanel({required this.dashboard});
  final HomeDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Panel(
      pad: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TODAY\'S MOVEMENT',
            style: VyanaType.eyebrow.copyWith(color: t.gold),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _MovementStat(
                label: 'Steps',
                value: '${dashboard.todaySteps}',
                accent: t.vit('steps'),
              ),
              _MovementStat(
                label: 'Distance',
                value: formatDistanceMeters(dashboard.todayDistanceMeters),
                accent: t.vit('spo2'),
              ),
              _MovementStat(
                label: 'Calories',
                value: '${dashboard.todayCalories}',
                accent: t.vit('cal'),
              ),
            ],
          ),
          if (dashboard.stepStreak > 0) ...[
            const SizedBox(height: 12),
            Text(
              '${dashboard.stepStreak}-day streak at ${kStepStreakGoal ~/ 1000}k+ steps.',
              style: VyanaType.caption.copyWith(color: t.textSec),
            ),
          ],
        ],
      ),
    );
  }
}

class _MovementStat extends StatelessWidget {
  const _MovementStat({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 22),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(label, style: VyanaType.caption.copyWith(color: t.textSec)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact numeric vital tile; taps through to the metric's detail screen.
class _MiniVital extends StatelessWidget {
  const _MiniVital({required this.tile, required this.onTap});
  final HomeVitalTile tile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final ac = t.vit(tile.accent);
    return Panel(
      pad: 15,
      radius: 18,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ac.withValues(alpha: t.isDark ? 0.2 : 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(tile.icon, size: 22, color: ac),
              ),
              const Spacer(),
              VyanaIcon('chevR', size: 15, color: t.textMuted),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  tile.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VyanaType.titleSerif.copyWith(color: t.text),
                ),
              ),
              if (tile.unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  tile.unit,
                  style: VyanaType.caption.copyWith(color: t.textMuted),
                ),
              ],
            ],
          ),
          Text(
            tile.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: VyanaType.caption.copyWith(color: t.textSec),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends ConsumerWidget {
  const _InsightCard({required this.insight});
  final HomeInsight insight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final ac = t.vit(insight.accent);
    final guide = guideById(insight.guide);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        pad: 16,
        accent: ac,
        onTap: () {
          // Jump to the Guides tab, unwinding back to the root shell first.
          ref.read(tabIndexProvider.notifier).state = 3;
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: ac.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: VyanaIcon('sparkles', size: 13, color: ac),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  guide?.name ?? 'Guide',
                  style: VyanaType.caption.copyWith(
                    color: t.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: ac.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    insight.tag.toUpperCase(),
                    style: VyanaType.mono10.copyWith(color: ac),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              insight.text,
              style: VyanaType.body.copyWith(color: t.textSec, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// A quiet doorway row into one of the deeper data screens.
class _ExploreRow extends StatelessWidget {
  const _ExploreRow({
    required this.icon,
    required this.accent,
    required this.label,
    required this.blurb,
    required this.onTap,
  });

  final String icon;
  final Color accent;
  final String label;
  final String blurb;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        pad: 14,
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: t.isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: VyanaIcon(icon, size: 19, color: accent)),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: VyanaType.label.copyWith(
                      color: t.text,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    blurb,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VyanaType.caption.copyWith(color: t.textSec),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            VyanaIcon('chevR', size: 17, color: t.textMuted),
          ],
        ),
      ),
    );
  }
}

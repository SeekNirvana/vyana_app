part of '../../main.dart';

/// The data-first daily dashboard (Home tab). Live ring status and vitals come
/// from [RingController]; readiness, streaks and insights are computed from
/// synced ring history via [HomeDashboard].
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

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

    final hasRing = controller.hasRingContext;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
      children: [
        _HomeAppBar(
          controller: controller,
          dashboard: dashboard,
          hasRingContext: hasRing,
        ),
        const SizedBox(height: 4),
        if (hasRing)
          _RingStrip(controller: controller)
        else
          _DiscoverRingPanel(controller: controller),
        const SizedBox(height: 16),
        if (hasRing)
          _ReadinessHero(dashboard: dashboard)
        else
          _WelcomeHero(dashboard: dashboard),
        const SizedBox(height: 16),
        _PracticeHero(dashboard: dashboard),
        if (hasRing) ...[
          const SizedBox(height: 22),
          SectionHead(
            eyebrow: 'Live now',
            title: 'Your vitals',
            action: 'See all',
            onAction: () => openMeasurements(context, controller),
          ),
          if (tiles.isEmpty)
            AccessDeniedPanel(
              title: 'No vitals yet',
              message:
                  'Connect your PRANA ring and sync to populate daily vitals.',
              icon: 'ring',
              secondaryLabel: controller.isConnected && !controller.isSyncing
                  ? 'Sync now'
                  : 'Pair ring',
              onSecondary: controller.isConnected && !controller.isSyncing
                  ? () => syncRingWithFeedback(context, controller)
                  : () => openScanner(context, controller),
            )
          else
            _VitalsMiniGrid(controller: controller, tiles: tiles),
          if (dashboard.insights.isNotEmpty) ...[
            const SizedBox(height: 22),
            const SectionHead(
                eyebrow: 'On-device AI', title: 'Insights for you'),
            for (final ins in dashboard.insights) _InsightCard(insight: ins),
          ],
          const SizedBox(height: 14),
          Text(
            controller.status,
            style: VyanaType.caption.copyWith(color: t.textMuted),
          ),
        ] else ...[
          const SizedBox(height: 22),
          AccessDeniedPanel(
            title: 'Vitals with PRANA',
            message:
                'Heart rate, sleep, and readiness unlock when you wear the ring.',
            icon: 'ring',
            primaryLabel: 'Buy ring',
            onPrimary: () => openRingOrder(context),
            secondaryLabel: 'Pair ring',
            onSecondary: () => openScanner(context, controller),
          ),
        ],
      ],
    );
  }
}

class _HomeAppBar extends ConsumerWidget {
  const _HomeAppBar({
    required this.controller,
    required this.dashboard,
    required this.hasRingContext,
  });
  final RingController controller;
  final HomeDashboard dashboard;
  final bool hasRingContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final greeting = ref.watch(userProfileProvider).maybeWhen(
          data: (profile) => profile.homeGreeting,
          orElse: () => 'Welcome',
        );
    final streakSub = !hasRingContext
        ? 'Start your practice'
        : dashboard.stepStreak > 0
            ? '${dashboard.stepStreak}-day step streak'
            : dashboard.hasRingHistory
                ? 'Ring synced'
                : 'Connect your ring';

    return VAppBar(
      sub: streakSub,
      title: greeting,
      leading: const Seal(size: 42, glow: true),
      actions: [
        const IconBtn(icon: 'bell', badge: true),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: t.border),
          ),
          child: Row(
            children: [
              VyanaIcon('award', size: 16, color: t.gold),
              const SizedBox(width: 6),
              Text('${HomeSeed.chakraBalance}',
                  style: VyanaType.label.copyWith(color: t.text)),
            ],
          ),
        ),
      ],
    );
  }
}

class _DiscoverRingPanel extends StatelessWidget {
  const _DiscoverRingPanel({required this.controller});
  final RingController controller;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Panel(
      grad: true,
      pad: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PRANA RING',
              style: VyanaType.eyebrow.copyWith(color: t.gold)),
          const SizedBox(height: 6),
          Text('Wear your vitals.',
              style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            'Black · sizes 7–13 · ships in 30 days.',
            style: VyanaType.bodySm.copyWith(color: t.textSec, height: 1.45),
          ),
          const SizedBox(height: 14),
          Cta(
            label: 'Buy PRANA ring',
            icon: 'ring',
            onTap: () => openRingOrder(context),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: controller.isReady
                  ? () => openScanner(context, controller)
                  : null,
              child: Text(
                'Already have a ring? Pair now',
                style: VyanaType.label.copyWith(color: t.gold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({required this.dashboard});
  final HomeDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Panel(
      grad: true,
      pad: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WELCOME',
              style: VyanaType.eyebrow.copyWith(color: t.gold)),
          const SizedBox(height: 6),
          Text('Your wellness, on your terms.',
              style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 26)),
          const SizedBox(height: 10),
          Text(
            'Explore breath, movement, and rest. Add a ring when you are ready '
            'for sleep, HRV, and daily readiness.',
            style: VyanaType.bodySm.copyWith(color: t.textSec, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _RingStrip extends StatelessWidget {
  const _RingStrip({required this.controller});
  final RingController controller;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final connected = controller.isConnected;
    final dot = connected ? t.green : t.textMuted;
    final name = controller.pairedRing?.displayName ??
        (controller.selectedDevice == null
            ? 'PRANA Ring'
            : deviceLabel(controller.selectedDevice));
    final battery = controller.vitals.battery ??
        controller.basicInfo?.batteryPower;
    final subtitle = connected
        ? [
            if (battery != null) '$battery% battery',
            controller.isSyncing ? 'Syncing…' : 'Connected',
          ].join(' · ')
        : controller.status;

    return Panel(
      pad: 13,
      onTap: () => openScanner(context, controller),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: dot, width: 1.5),
                ),
                child: Center(child: VyanaIcon('ring', size: 18, color: dot)),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: dot,
                    shape: BoxShape.circle,
                    border: Border.all(color: t.card, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VyanaType.label.copyWith(
                        color: t.text, fontWeight: FontWeight.w700)),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VyanaType.caption.copyWith(color: t.textSec)),
              ],
            ),
          ),
          VyanaIcon('chevR', size: 18, color: t.textMuted),
        ],
      ),
    );
  }
}

class _ReadinessHero extends StatelessWidget {
  const _ReadinessHero({required this.dashboard});
  final HomeDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final score = dashboard.readinessScore;
    final hasScore = score != null;

    return Panel(
      grad: true,
      pad: 20,
      child: Column(
        children: [
          Row(
            children: [
              ProgressRing(
                value: (score ?? 0).toDouble(),
                max: 100,
                size: 108,
                stroke: 9,
                color: t.green,
                track: t.isDark ? const Color(0xFF1F2630) : const Color(0xFFECE3D3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(hasScore ? '$score' : '—',
                        style: VyanaType.displaySerif.copyWith(color: t.text)),
                    Text('READY',
                        style: VyanaType.mono10.copyWith(
                            color: t.textSec, letterSpacing: 1.4)),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('READINESS',
                        style: VyanaType.eyebrow.copyWith(color: t.gold)),
                    const SizedBox(height: 5),
                    Text(dashboard.readinessLabel,
                        style: VyanaType.titleSerif.copyWith(
                            color: t.text, fontSize: 26)),
                    if (dashboard.readinessDelta != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: (dashboard.readinessDelta! >= 0 ? t.green : t.gold)
                              .withValues(alpha: t.isDark ? 0.16 : 0.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            VyanaIcon(
                              dashboard.readinessDelta! >= 0 ? 'chevU' : 'chevD',
                              size: 13,
                              color: dashboard.readinessDelta! >= 0 ? t.green : t.gold,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${dashboard.readinessDelta! >= 0 ? '+' : ''}${dashboard.readinessDelta} vs prior night',
                              style: VyanaType.caption.copyWith(
                                color: dashboard.readinessDelta! >= 0
                                    ? t.green
                                    : t.gold,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (!hasScore) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Sync sleep and HRV from your ring.',
                        style: VyanaType.caption.copyWith(color: t.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // Without this, the grid inherits the shell's bottom inset
            // (extendBody MediaQuery padding) and adds phantom space below.
            padding: EdgeInsets.zero,
            childAspectRatio: 3.4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: [
              for (final d in dashboard.drivers)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: t.isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(d.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: VyanaType.caption.copyWith(color: t.textSec)),
                      ),
                      Text(d.value,
                          style: VyanaType.caption.copyWith(
                              color: d.good ? t.green : t.gold,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PracticeHero extends ConsumerWidget {
  const _PracticeHero({required this.dashboard});
  final HomeDashboard dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final quick = HomeSeed.quickPractices
        .map(activityById)
        .whereType<Activity>()
        .toList();
    return Panel(
      grad: true,
      pad: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SADHANA · YOUR PRACTICE',
              style: VyanaType.eyebrow.copyWith(color: t.gold)),
          const SizedBox(height: 7),
          Text('Begin today, gently.',
              style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 24)),
          const SizedBox(height: 6),
          Text(
            dashboard.practiceHint,
            style: VyanaType.bodySm.copyWith(color: t.textSec),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in quick)
                GestureDetector(
                  onTap: () => openActivityDetail(context, a),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 8, 13, 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: t.border),
                      color: t.isDark
                          ? Colors.white.withValues(alpha: 0.03)
                          : Colors.black.withValues(alpha: 0.02),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        VyanaIcon(a.icon, size: 15, color: t.vit(a.accent)),
                        const SizedBox(width: 7),
                        Text(a.name,
                            style: VyanaType.caption.copyWith(
                                color: t.text, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Cta(
            label: 'Choose a practice',
            icon: 'lotus',
            onTap: () => ref.read(tabIndexProvider.notifier).state = 2,
          ),
        ],
      ),
    );
  }
}

class _VitalsMiniGrid extends StatelessWidget {
  const _VitalsMiniGrid({required this.controller, required this.tiles});
  final RingController controller;
  final List<HomeVitalTile> tiles;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // Drop the inherited extendBody bottom inset (phantom space below grid).
      padding: EdgeInsets.zero,
      childAspectRatio: 1.45,
      crossAxisSpacing: 11,
      mainAxisSpacing: 11,
      children: [
        for (final tile in tiles)
          _MiniVital(
            tile: tile,
            onTap: () => openVitalDetail(context, controller, tile.kind),
          ),
      ],
    );
  }
}

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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: ac.withValues(alpha: t.isDark ? 0.2 : 0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: VyanaIcon(tile.icon, size: 17, color: ac)),
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
                child: Text(tile.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VyanaType.titleSerif.copyWith(color: t.text)),
              ),
              if (tile.unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(tile.unit,
                    style: VyanaType.caption.copyWith(color: t.textMuted)),
              ],
            ],
          ),
          Text(tile.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VyanaType.caption.copyWith(color: t.textSec)),
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
        onTap: () => ref.read(tabIndexProvider.notifier).state = 3,
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
                  child: Center(child: VyanaIcon('sparkles', size: 13, color: ac)),
                ),
                const SizedBox(width: 8),
                Text(guide?.name ?? 'Guide',
                    style: VyanaType.caption.copyWith(
                        color: t.text, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: ac.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(insight.tag.toUpperCase(),
                      style: VyanaType.mono10.copyWith(color: ac)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(insight.text,
                style: VyanaType.body.copyWith(color: t.textSec, height: 1.5)),
          ],
        ),
      ),
    );
  }
}
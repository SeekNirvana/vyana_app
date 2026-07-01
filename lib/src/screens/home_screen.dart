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
          _CheckInHero(
            controller: controller,
            dashboard: dashboard,
            tiles: tiles,
          )
        else
          _WelcomeHero(dashboard: dashboard),
        const SizedBox(height: 16),
        _PracticeHero(dashboard: dashboard),
        if (hasRing) ...[
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

/// Maps a felt wellness tone to a brand-consistent hue.
Color _toneColor(VyanaColors t, WellnessTone tone) {
  switch (tone) {
    case WellnessTone.good:
      return t.green;
    case WellnessTone.steady:
      return t.gold;
    case WellnessTone.watch:
      return const Color(0xFFE08A4B); // warm amber — caring, not alarming
    case WellnessTone.unknown:
      return t.textMuted;
  }
}

/// The Home centrepiece: your current state of being in plain language, felt
/// signal chips instead of raw numbers, and the one-tap "Monitor all vitals"
/// run with live progress. Rebuilds with the [RingController] it is handed.
/// The one Home signal: readiness + worded state in a single card, felt signal
/// chips, a scrollable biomarker strip, and the Check-vitals / Sync actions.
/// Replaces the old duplicate State-of-being + Readiness pair.
class _CheckInHero extends StatelessWidget {
  const _CheckInHero({
    required this.controller,
    required this.dashboard,
    required this.tiles,
  });

  final RingController controller;
  final HomeDashboard dashboard;
  final List<HomeVitalTile> tiles;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final running = controller.allVitalsRunning;
    final justFailed = controller.allVitalsPhase == AllVitalsPhase.failed;
    final state = controller.currentWellnessState();
    final toneColor =
        _toneColor(t, justFailed ? WellnessTone.watch : state.tone);
    final score = dashboard.readinessScore;
    final canSync = controller.isConnected && !controller.isSyncing && !running;

    final body = running
        ? (controller.allVitalsMessage ?? 'Reading your vitals…')
        : justFailed
            ? (controller.allVitalsMessage ?? state.summary)
            : state.summary;

    return Panel(
      grad: true,
      pad: 20,
      accent: state.hasData || justFailed ? toneColor : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('HOW YOU’RE BEING',
                  style: VyanaType.eyebrow.copyWith(color: t.gold)),
              const Spacer(),
              Text(
                controller.isSyncing ? 'Syncing…' : 'Now',
                style: VyanaType.caption.copyWith(color: t.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Single clear signal: readiness ring + worded state.
          Row(
            children: [
              ProgressRing(
                value: (score ?? 0).toDouble(),
                max: 100,
                size: 96,
                stroke: 8,
                color: toneColor,
                track: t.isDark
                    ? const Color(0xFF1F2630)
                    : const Color(0xFFECE3D3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(score == null ? '—' : '$score',
                        style: VyanaType.displaySerif.copyWith(color: t.text)),
                    Text('READY',
                        style: VyanaType.mono10
                            .copyWith(color: t.textSec, letterSpacing: 1.4)),
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
                      running ? 'Checking in…' : state.title,
                      style: VyanaType.titleSerif
                          .copyWith(color: t.text, fontSize: 24),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body,
                      style: VyanaType.bodySm
                          .copyWith(color: t.textSec, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!running && state.signals.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final s in state.signals) _SignalChip(signal: s)],
            ),
          ],
          if (running) ...[
            const SizedBox(height: 16),
            _AllVitalsProgress(controller: controller),
          ],
          if (tiles.isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Text('YOUR VITALS',
                    style: VyanaType.eyebrow.copyWith(color: t.gold)),
                const Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => openMeasurements(context, controller),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('See all & test',
                          style: VyanaType.caption.copyWith(
                              color: t.gold, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 3),
                      VyanaIcon('chevR', size: 14, color: t.gold),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 116,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                itemCount: tiles.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) => SizedBox(
                  width: 132,
                  child: _MiniVital(
                    tile: tiles[i],
                    onTap: () =>
                        openVitalDetail(context, controller, tiles[i].kind),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Cta(
                  label: running
                      ? 'Monitoring…'
                      : state.hasData
                          ? 'Check vitals again'
                          : 'Monitor all vitals',
                  icon: 'activity',
                  disabled: running,
                  onTap:
                      running ? null : () => unawaited(controller.runAllVitals()),
                ),
              ),
              const SizedBox(width: 10),
              IconBtn(
                icon: 'refresh',
                size: 52,
                onTap: canSync
                    ? () => syncRingWithFeedback(context, controller)
                    : null,
              ),
            ],
          ),
          if (!running) ...[
            const SizedBox(height: 9),
            Text(
              'Reads every vital in turn — set the phone aside and Vyana pings '
              'you when your check-in is ready.',
              style: VyanaType.caption.copyWith(color: t.textMuted, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

/// A felt signal as a pill: concept + descriptor, coloured by tone (no numbers).
class _SignalChip extends StatelessWidget {
  const _SignalChip({required this.signal});
  final WellnessSignal signal;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final c = _toneColor(t, signal.tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: c.withValues(alpha: t.isDark ? 0.14 : 0.10),
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
          Text(signal.label,
              style: VyanaType.caption.copyWith(color: t.textSec)),
          const SizedBox(width: 5),
          Text(signal.reading,
              style: VyanaType.caption
                  .copyWith(color: c, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Live progress bar for a Monitor-all-vitals run.
class _AllVitalsProgress extends StatelessWidget {
  const _AllVitalsProgress({required this.controller});
  final RingController controller;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final total = controller.allVitalsTotal;
    final done = controller.allVitalsDone;
    final value = total == 0 ? null : (done / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 7,
            backgroundColor:
                t.isDark ? const Color(0xFF1F2630) : const Color(0xFFECE3D3),
            valueColor: AlwaysStoppedAnimation<Color>(t.green),
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: Text(
                controller.allVitalsMessage ?? 'Working…',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: VyanaType.caption.copyWith(color: t.textSec),
              ),
            ),
            if (total > 0)
              Text('$done/$total',
                  style: VyanaType.mono10.copyWith(color: t.textMuted)),
          ],
        ),
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
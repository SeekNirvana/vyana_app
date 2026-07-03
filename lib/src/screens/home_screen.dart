part of '../../main.dart';

/// The calm daily sanctuary (Home tab). No raw numbers live here — the ring's
/// readings are translated into felt, worded signals ([WellnessState]), and
/// everything numeric (scores, tiles, charts, insights) lives one tap away on
/// [TrendsScreen]. Live ring status and vitals come from [RingController].
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final controller = ref.watch(ringControllerProvider);
    final dashboard = HomeDashboard.from(controller);

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
          _CheckInHero(controller: controller, dashboard: dashboard)
        else
          _WelcomeHero(dashboard: dashboard),
        const SizedBox(height: 16),
        _PracticeHero(dashboard: dashboard),
        if (hasRing) ...[
          const SizedBox(height: 16),
          const _NumbersCard(),
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
      return const Color(0xFFD9975F); // warm amber — caring, not alarming
    case WellnessTone.unknown:
      return t.textMuted;
  }
}

/// A slow "breathing" orb — expands and settles on a ~4s rhythm, inviting the
/// user to match their breath. Replaces the numeric readiness ring on Home.
class _BreathingOrb extends StatefulWidget {
  const _BreathingOrb({required this.color});

  final Color color;

  static const double size = 104;

  @override
  State<_BreathingOrb> createState() => _BreathingOrbState();
}

class _BreathingOrbState extends State<_BreathingOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  late final Animation<double> _breath = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutSine,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final c = widget.color;
    return RepaintBoundary(
      child: SizedBox(
        width: _BreathingOrb.size,
        height: _BreathingOrb.size,
        child: AnimatedBuilder(
          animation: _breath,
          builder: (context, child) {
            final v = _breath.value;
            return Stack(
              alignment: Alignment.center,
              children: [
                // Outer halo that swells with the in-breath.
                Container(
                  width: _BreathingOrb.size * (0.82 + 0.18 * v),
                  height: _BreathingOrb.size * (0.82 + 0.18 * v),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        c.withValues(alpha: t.isDark ? 0.26 : 0.18),
                        c.withValues(alpha: 0.03),
                      ],
                    ),
                  ),
                ),
                // Steady inner circle holding the lotus.
                Container(
                  width: _BreathingOrb.size * 0.62,
                  height: _BreathingOrb.size * 0.62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.withValues(alpha: t.isDark ? 0.16 : 0.10),
                    border: Border.all(
                      color: c.withValues(alpha: 0.35 + 0.2 * v),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: VyanaIcon('lotus',
                        size: _BreathingOrb.size * 0.28, color: c, stroke: 1.6),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The Home centrepiece: your current state of being in plain language, felt
/// signal chips instead of raw numbers, a breathing orb to settle with, and
/// the one-tap "Monitor all vitals" run with live progress. Everything
/// numeric now lives on [TrendsScreen].
class _CheckInHero extends StatelessWidget {
  const _CheckInHero({
    required this.controller,
    required this.dashboard,
  });

  final RingController controller;
  final HomeDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final running = controller.allVitalsRunning;
    final justFailed = controller.allVitalsPhase == AllVitalsPhase.failed;
    final state = controller.currentWellnessState();
    final toneColor =
        _toneColor(t, justFailed ? WellnessTone.watch : state.tone);
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
          // A single felt signal: breathing orb + worded state. Numbers wait
          // on the Trends screen for when you choose to look.
          Row(
            children: [
              _BreathingOrb(color: toneColor),
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Cta(
                  label: running
                      ? 'Monitoring…'
                      : state.hasData
                          ? 'Check in again'
                          : 'Check in with your body',
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
              'Set the phone aside — Vyana reads each vital in turn and lets '
              'you know, gently, when your check-in is ready.',
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

/// Live progress bar for a Monitor-all-vitals run — a quiet bar and a plain
/// sentence, no counters.
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
            backgroundColor: t.elevated,
            valueColor: AlwaysStoppedAnimation<Color>(t.green),
          ),
        ),
        const SizedBox(height: 9),
        Text(
          controller.allVitalsMessage ?? 'Working…',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: VyanaType.caption.copyWith(color: t.textSec),
        ),
      ],
    );
  }
}

/// The one doorway from Home into everything numeric: readiness score, vital
/// tiles, movement stats, weekly charts, and measurements.
class _NumbersCard extends StatelessWidget {
  const _NumbersCard();

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    const icons = ['heart', 'moon', 'walk', 'chart'];
    return Panel(
      pad: 18,
      onTap: () => openTrends(context),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 40,
            child: Stack(
              children: [
                for (var i = 0; i < icons.length; i++)
                  Positioned(
                    left: i * 8.0,
                    top: i.isEven ? 0 : 8,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: t.elevated,
                        shape: BoxShape.circle,
                        border: Border.all(color: t.borderSoft),
                      ),
                      child: Center(
                        child: VyanaIcon(icons[i], size: 14, color: t.textSec),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Your numbers',
                    style: VyanaType.titleSerif
                        .copyWith(color: t.text, fontSize: 19)),
                const SizedBox(height: 3),
                Text(
                  'Readiness, vitals, trends and insights — kept here, for when you want them.',
                  style: VyanaType.caption
                      .copyWith(color: t.textSec, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          VyanaIcon('chevR', size: 18, color: t.textMuted),
        ],
      ),
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
    final greeting = ref.watch(userProfileProvider).maybeWhen(
          data: (profile) => profile.homeGreeting,
          orElse: () => 'Welcome',
        );
    // Worded, unhurried — streak counts live on the Trends screen.
    final streakSub = !hasRingContext
        ? 'Start your practice'
        : dashboard.stepStreak > 0
            ? 'Moving in a steady rhythm'
            : dashboard.hasRingHistory
                ? 'Ring synced'
                : 'Connect your ring';

    return VAppBar(
      sub: streakSub,
      title: greeting,
      leading: const Seal(size: 42, glow: true),
      actions: [
        const IconBtn(icon: 'bell', badge: true),
        IconBtn(
          icon: 'award',
          onTap: () => ref.read(tabIndexProvider.notifier).state = 4,
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

/// Words for the ring battery so Home stays free of raw numbers; the exact
/// percentage remains in the scanner / device screens.
String? _batteryWords(int? battery) {
  if (battery == null) return null;
  if (battery >= 80) return 'Battery full';
  if (battery >= 40) return 'Battery good';
  if (battery >= 15) return 'Battery getting low';
  return 'Charge soon';
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
    final batteryLabel = _batteryWords(battery);
    final subtitle = connected
        ? [
            ?batteryLabel,
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

part of '../../main.dart';

/// The daily glance screen. A short morning or night window surfaces the few
/// numbers that matter in that moment; the full history stays in Trends.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(ringControllerProvider);
    final dashboard = HomeDashboard.from(controller);
    final state = controller.currentWellnessState();
    final hasRing = controller.hasRingContext;
    final moment = homeMomentAt(DateTime.now());

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 104),
      children: [
        _HomeAppBar(controller: controller, hasRingContext: hasRing),
        if (!hasRing) ...[
          const SizedBox(height: 8),
          _DiscoverRingPanel(controller: controller),
        ],
        const SizedBox(height: 4),
        if (hasRing)
          _CheckInHero(
            controller: controller,
            dashboard: dashboard,
            state: state,
            moment: moment,
          )
        else
          _WelcomeHero(dashboard: dashboard),
        const SizedBox(height: 10),
        _PracticeHero(moment: moment, dashboard: dashboard, state: state),
        if (!hasRing) ...[
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

enum HomeMoment { morning, day, night }

HomeMoment homeMomentAt(DateTime time) {
  if (time.hour >= 5 && time.hour < 12) return HomeMoment.morning;
  if (time.hour >= 18 || time.hour < 5) return HomeMoment.night;
  return HomeMoment.day;
}

/// Readiness first, with contextual numbers only when they help the current
/// morning or night decision.
class _CheckInHero extends StatelessWidget {
  const _CheckInHero({
    required this.controller,
    required this.dashboard,
    required this.state,
    required this.moment,
  });

  final RingController controller;
  final HomeDashboard dashboard;
  final WellnessState state;
  final HomeMoment moment;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final running = controller.allVitalsRunning;
    final body = running
        ? (controller.allVitalsMessage ?? 'Reading your vitals…')
        : state.summary;
    final score = dashboard.readinessScore;
    final metrics = _momentMetrics(t, controller, dashboard, moment);
    final signals = _homeSignals(state, dashboard);
    final foreground = t.isDark ? t.text : const Color(0xFF172128);
    final secondary = t.isDark ? t.textSec : const Color(0xFF65717A);

    return SizedBox(
      height: running ? 464 : (metrics.isEmpty ? 384 : 484),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'How you’re being',
                    style: VyanaType.label.copyWith(
                      color: t.green,
                      fontSize: 15,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: running
                      ? null
                      : () => unawaited(controller.runAllVitals()),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: t.green,
                  ),
                  child: Text(running ? 'Checking…' : 'Check vitals'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              score == null ? '—' : '$score',
              style: VyanaType.displaySerif.copyWith(
                color: foreground,
                fontSize: 84,
                fontWeight: FontWeight.w400,
                height: 0.9,
                letterSpacing: -3.2,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              running ? 'Checking in…' : _recoveryTitle(score, state.title),
              style: VyanaType.titleSerif.copyWith(
                color: foreground,
                fontSize: 29,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: VyanaType.bodySm.copyWith(color: secondary),
            ),
            if (!running && signals.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final signal in signals) _SignalChip(signal: signal),
                ],
              ),
            ],
            if (running) ...[
              const SizedBox(height: 14),
              _AllVitalsProgress(controller: controller),
            ],
            if (metrics.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  VyanaIcon(
                    moment == HomeMoment.morning ? 'sun' : 'moon',
                    size: 17,
                    color: t.vit('sleep'),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    moment == HomeMoment.morning ? 'This morning' : 'Tonight',
                    style: VyanaType.label.copyWith(color: t.vit('sleep')),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < metrics.length; i++) ...[
                    if (i > 0)
                      Container(
                        width: 1,
                        height: 58,
                        margin: const EdgeInsets.symmetric(horizontal: 9),
                        color: t.border,
                      ),
                    Expanded(child: _MomentStat(metric: metrics[i])),
                  ],
                ],
              ),
            ],
            const Spacer(),
            InkWell(
              onTap: () => openTrends(context),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    VyanaIcon('chart', size: 18, color: t.green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'View health metrics',
                        style: VyanaType.label.copyWith(color: t.green),
                      ),
                    ),
                    VyanaIcon('chevR', size: 17, color: t.textMuted),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _toneColor(VyanaColors t, WellnessTone tone) => switch (tone) {
  WellnessTone.good => t.green,
  WellnessTone.steady => t.gold,
  WellnessTone.watch => const Color(0xFFD97745),
  WellnessTone.unknown => t.textMuted,
};

List<WellnessSignal> _homeSignals(
  WellnessState state,
  HomeDashboard dashboard,
) {
  final signals = <WellnessSignal>[];
  for (final label in const ['Calm', 'Recovery']) {
    for (final signal in state.signals) {
      if (signal.label == label) signals.add(signal);
    }
  }

  final sleep = dashboard.drivers.where((driver) => driver.label == 'Sleep');
  if (sleep.isNotEmpty && sleep.first.value != '—') {
    final value = sleep.first.value;
    signals.add(
      WellnessSignal(
        label: 'Sleep',
        reading: switch (value) {
          'Good' => 'Well recovered',
          'Fair' => 'Fair',
          _ => 'Needs recovery',
        },
        tone: value == 'Good'
            ? WellnessTone.good
            : value == 'Fair'
            ? WellnessTone.steady
            : WellnessTone.watch,
      ),
    );
  }

  for (final signal in state.signals) {
    if (signals.length == 3) break;
    if (!signals.any((item) => item.label == signal.label)) {
      signals.add(signal);
    }
  }
  return signals.take(3).toList(growable: false);
}

class _SignalChip extends StatelessWidget {
  const _SignalChip({required this.signal});

  final WellnessSignal signal;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final color = _toneColor(t, signal.tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: t.isDark ? 0.14 : 0.09),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text.rich(
        TextSpan(
          text: '${signal.label}  ',
          style: VyanaType.caption.copyWith(color: t.textSec),
          children: [
            TextSpan(
              text: signal.reading,
              style: VyanaType.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _recoveryTitle(int? score, String fallback) {
  if (score == null) return fallback;
  if (score >= 80) return 'Well recovered';
  if (score >= 65) return 'Ready for today';
  if (score >= 50) return 'Take it steady';
  return 'Recovery first';
}

String _countLabel(int value) {
  final text = '$value';
  if (text.length <= 3) return text;
  return '${text.substring(0, text.length - 3)},${text.substring(text.length - 3)}';
}

List<({String label, String value, String unit, String icon, Color color})>
_momentMetrics(
  VyanaColors t,
  RingController controller,
  HomeDashboard dashboard,
  HomeMoment moment,
) {
  if (moment == HomeMoment.day) return const [];
  if (moment == HomeMoment.morning) {
    return [
      (
        label: 'Sleep',
        value: dashboard.lastSleepDuration ?? '—',
        unit: '',
        icon: 'sleep',
        color: t.vit('sleep'),
      ),
      (
        label: 'Readiness',
        value: dashboard.readinessScore?.toString() ?? '—',
        unit: '',
        icon: 'gauge',
        color: t.vit('readiness'),
      ),
      (
        label: 'Resting HR',
        value: controller.vitals.heartRate?.toString() ?? '—',
        unit: 'bpm',
        icon: 'heart',
        color: t.vit('hr'),
      ),
    ];
  }
  return [
    (
      label: 'Sleep goal',
      value: '8',
      unit: 'h',
      icon: 'sleep',
      color: t.vit('sleep'),
    ),
    (
      label: 'Steps',
      value: _countLabel(dashboard.todaySteps),
      unit: '',
      icon: 'walk',
      color: t.vit('steps'),
    ),
    (
      label: 'Active time',
      value: '${dashboard.todayActiveMinutes}',
      unit: 'min',
      icon: 'timer',
      color: t.cyan,
    ),
  ];
}

class _MomentStat extends StatelessWidget {
  const _MomentStat({required this.metric});

  final ({String label, String value, String unit, String icon, Color color})
  metric;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VyanaIcon(metric.icon, size: 17, color: metric.color),
        const SizedBox(height: 5),
        Text(
          metric.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: VyanaType.caption.copyWith(color: t.textSec, fontSize: 11.5),
        ),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            text: metric.value,
            children: [
              if (metric.unit.isNotEmpty)
                TextSpan(
                  text: ' ${metric.unit}',
                  style: VyanaType.caption.copyWith(color: t.textSec),
                ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 20),
        ),
      ],
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

class _HomeAppBar extends ConsumerWidget {
  const _HomeAppBar({required this.controller, required this.hasRingContext});
  final RingController controller;
  final bool hasRingContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final greeting = ref
        .watch(userProfileProvider)
        .maybeWhen(
          data: (profile) => profile.homeGreeting,
          orElse: () => 'Welcome',
        );
    final t = context.vyana;
    final status = hasRingContext ? 'Ring synced' : 'Start your practice';

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => openScanner(context, controller),
            child: const Seal(size: 44, glow: true),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  greeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VyanaType.appBarSerif.copyWith(
                    color: t.text,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '• $status',
                  style: VyanaType.caption.copyWith(color: t.green),
                ),
              ],
            ),
          ),
          const IconBtn(icon: 'bell', badge: true, size: 42),
          const SizedBox(width: 8),
          IconBtn(
            icon: 'award',
            size: 42,
            onTap: () => ref.read(tabIndexProvider.notifier).state = 4,
          ),
        ],
      ),
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
          Text('PRANA RING', style: VyanaType.eyebrow.copyWith(color: t.gold)),
          const SizedBox(height: 6),
          Text(
            'Wear your vitals.',
            style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 24),
          ),
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
          Text('WELCOME', style: VyanaType.eyebrow.copyWith(color: t.gold)),
          const SizedBox(height: 6),
          Text(
            'Your wellness, on your terms.',
            style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 26),
          ),
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

class _PracticeHero extends ConsumerWidget {
  const _PracticeHero({
    required this.moment,
    required this.dashboard,
    required this.state,
  });

  final HomeMoment moment;
  final HomeDashboard dashboard;
  final WellnessState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final id = suggestedPracticeId(state, dashboard.readinessScore, moment);
    final activity = activityById(id)!;
    final title = activity.name;
    final kind = switch (activity.kind) {
      'breath' => 'Breath',
      'sequence' => 'Guided flow',
      'recovery' => 'Recovery',
      _ => 'Movement',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Suggested practice',
                style: VyanaType.titleSerif.copyWith(
                  color: t.text,
                  fontSize: 19,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _practiceReason(state, dashboard.readinessScore),
                style: VyanaType.caption.copyWith(color: t.textSec),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Panel(
          pad: 14,
          radius: 20,
          onTap: () => openActivityDetail(context, activity),
          child: Row(
            children: [
              VyanaIconBadge(
                name: activity.icon,
                color: t.vit(activity.accent),
                size: 48,
                iconSize: 22,
                borderRadius: 16,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: VyanaType.titleSerif.copyWith(
                        color: t.text,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${activity.dur} min · $kind',
                      style: VyanaType.caption.copyWith(color: t.textSec),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: t.green,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: t.green.withValues(alpha: 0.24),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: const Center(
                  child: VyanaIcon(
                    'play',
                    size: 18,
                    color: Colors.white,
                    fill: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String suggestedPracticeId(
  WellnessState state,
  int? readinessScore,
  HomeMoment moment,
) {
  final tense = state.signals.any(
    (signal) => signal.label == 'Calm' && signal.tone == WellnessTone.watch,
  );
  if (tense) return 'breathwork';
  if (readinessScore != null && readinessScore < 50) return 'recovery';
  if (state.tone == WellnessTone.watch) return 'recovery';
  if (readinessScore != null && readinessScore >= 75) {
    return switch (moment) {
      HomeMoment.morning => 'sunSalutation',
      HomeMoment.day => 'walk',
      HomeMoment.night => 'pranayama',
    };
  }
  return 'breathwork';
}

String _practiceReason(WellnessState state, int? readinessScore) {
  final tense = state.signals.any(
    (signal) => signal.label == 'Calm' && signal.tone == WellnessTone.watch,
  );
  if (tense) return 'Suggested to help settle your current stress signals.';
  if (readinessScore != null && readinessScore < 50) {
    return 'Suggested to support recovery today.';
  }
  if (readinessScore != null && readinessScore >= 75) {
    return 'Your recovery supports gentle, steady movement.';
  }
  return 'Matched to your current health signals.';
}

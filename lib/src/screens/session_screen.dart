part of '../../main.dart';

/// Live session screen. This is the functional M3 shell — elapsed clock, live
/// HR stream, sample count and start/pause/stop — proving capture + persistence
/// end-to-end. The seven kind-specific bodies (breath orb, GPS map, strength
/// FSM, …) arrive in M4.
class LiveSessionScreen extends ConsumerWidget {
  const LiveSessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final s = ref.watch(sessionControllerProvider);
    final a = s.activity;
    final ac = a == null ? t.green : t.vit(a.accent);

    // The session keeps recording in the background when minimised; the
    // resume bar (in the shell) brings it back. No PopScope block.
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: t.bgGradient),
        child: SafeArea(
          child: s.active
              ? _ActiveBody(controller: s, accent: ac)
              : _SummaryBody(controller: s, accent: ac),
        ),
      ),
    );
  }
}

class _ActiveBody extends StatelessWidget {
  const _ActiveBody({required this.controller, required this.accent});
  final SessionController controller;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final a = controller.activity;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              IconBtn(
                icon: 'chevD',
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 11),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: t.isDark ? 0.2 : 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                    child: VyanaIcon(a?.icon ?? 'activity', size: 19, color: accent)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(controller.paused ? 'PAUSED' : 'RECORDING',
                        style: VyanaType.eyebrow.copyWith(
                            color: controller.paused ? t.gold : accent)),
                    Text(a?.name ?? 'Session',
                        style: VyanaType.appBarSerif.copyWith(color: t.text)),
                  ],
                ),
              ),
            ],
          ),
        ),
        _VoiceCueBanner(cue: controller.activeCue, accent: accent),
        Expanded(child: liveSessionBody(controller, accent)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Row(
            children: [
              _RoundControl(
                icon: controller.paused ? 'play' : 'pause',
                onTap: () =>
                    controller.paused ? controller.resume() : controller.pause(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Cta(
                  label: 'End & save',
                  icon: 'stop',
                  onTap: () => controller.end(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Slides in from the top when a voice cue fires (equalizer glyph + spoken
/// line); auto-clears via the controller.
class _VoiceCueBanner extends StatelessWidget {
  const _VoiceCueBanner({required this.cue, required this.accent});
  final String? cue;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return AnimatedSize(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: cue == null
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: t.isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  VyanaIcon('waveform', size: 18, color: accent),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(cue!,
                        style: VyanaType.bodySm.copyWith(color: t.text, height: 1.4)),
                  ),
                ],
              ),
            ),
    );
  }
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({required this.icon, required this.onTap});
  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: t.card,
          border: Border.all(color: t.border),
        ),
        child: Center(child: VyanaIcon(icon, size: 22, color: t.text)),
      ),
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({required this.controller, required this.accent});
  final SessionController controller;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final s = controller.lastSummary ?? const {};
    final duration = Duration(seconds: (s['durationSec'] as int?) ?? 0);
    final a = controller.activity;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: t.isDark ? 0.2 : 0.13),
              shape: BoxShape.circle,
            ),
            child: Center(child: VyanaIcon('checkCircle', size: 30, color: accent)),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(a == null ? 'Session saved' : '${a.name} · saved',
              style: VyanaType.titleSerif.copyWith(color: t.text)),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text('Stored locally on your device',
              style: VyanaType.caption.copyWith(color: t.textSec)),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            _SummaryStat(label: 'Duration', value: _fmtDuration(duration)),
            _SummaryStat(label: 'Avg HR', value: _hr(s['avgHr'])),
            _SummaryStat(label: 'Max HR', value: _hr(s['maxHr'])),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _SummaryStat(label: 'Min HR', value: _hr(s['minHr'])),
            _SummaryStat(
                label: 'Recovery',
                value: s['recovery'] == null ? '—' : '↓${s['recovery']} bpm'),
            _SummaryStat(label: 'Samples', value: '${s['samples'] ?? 0}'),
          ],
        ),
        if (((s['distanceMeters'] as int?) ?? 0) > 0) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              _SummaryStat(
                  label: 'Distance',
                  value:
                      '${((s['distanceMeters'] as int) / 1000).toStringAsFixed(2)} km'),
              _SummaryStat(
                  label: 'Elevation', value: '${s['elevationGain'] ?? 0} m'),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ],
        if (_zones(s).any((z) => z > 0)) ...[
          const SizedBox(height: 20),
          const SectionHead(eyebrow: 'Effort', title: 'Time in HR zones'),
          _ZoneBars(zones: _zones(s)),
        ],
        const SizedBox(height: 20),
        Panel(
          pad: 16,
          accent: t.green,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  VyanaIcon('chevU', size: 16, color: t.green),
                  const SizedBox(width: 8),
                  Text('Readiness impact',
                      style: VyanaType.label.copyWith(color: t.text)),
                  const Spacer(),
                  Text('+${_readinessImpact(s)} expected',
                      style: VyanaType.label.copyWith(color: t.green)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'What works for you: calm practices after 7h+ sleep lift your '
                'HRV most. This one counts.',
                style: VyanaType.bodySm.copyWith(color: t.textSec, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: t.gold.withValues(alpha: t.isDark ? 0.16 : 0.1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  VyanaIcon('award', size: 15, color: t.gold),
                  const SizedBox(width: 6),
                  Text('+30 Chakra earned',
                      style: VyanaType.caption.copyWith(
                          color: t.gold, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Cta(
          label: 'See weekly trends',
          icon: 'chart',
          solid: false,
          onTap: () {
            controller.clear();
            Navigator.of(context).pop();
            openWeeklyInsights(context);
          },
        ),
        const SizedBox(height: 10),
        Cta(
          label: 'Done',
          icon: 'check',
          onTap: () {
            controller.clear();
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  static String _hr(Object? v) => v == null ? '—' : '$v bpm';

  static List<int> _zones(Map s) {
    final z = s['zones'];
    if (z is List) return z.map((e) => (e as num).toInt()).toList();
    return const [0, 0, 0, 0, 0];
  }

  /// A gentle, deterministic readiness nudge from duration + category.
  static int _readinessImpact(Map s) {
    final mins = ((s['durationSec'] as int?) ?? 0) ~/ 60;
    final cat = s['category'] as String?;
    final base = cat == 'mind' || cat == 'wellness' ? 3 : 2;
    return (base + (mins ~/ 10)).clamp(1, 9);
  }
}

class _ZoneBars extends StatelessWidget {
  const _ZoneBars({required this.zones});
  final List<int> zones;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final total = zones.fold<int>(0, (a, b) => a + b);
    return Column(
      children: [
        for (var i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text('Z${i + 1}',
                      style: VyanaType.mono10.copyWith(color: t.textSec)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : zones[i] / total,
                      minHeight: 10,
                      backgroundColor: t.border,
                      valueColor: AlwaysStoppedAnimation(t.hrZones[i]),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 44,
                  child: Text(
                    total == 0 ? '0%' : '${(zones[i] / total * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: VyanaType.caption.copyWith(color: t.textSec),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: VyanaType.titleSerif.copyWith(color: t.text, fontSize: 19)),
            const SizedBox(height: 2),
            Text(label, style: VyanaType.caption.copyWith(color: t.textSec)),
          ],
        ),
      ),
    );
  }
}

String _fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

Future<void> openSessionHistory(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => const SessionHistoryScreen()),
  );
}

/// Recent saved sessions, read straight from the local vault — confirms
/// captured sessions persist across app launches.
class SessionHistoryScreen extends ConsumerWidget {
  const SessionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final db = ref.watch(databaseProvider);
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: t.bgGradient),
        child: SafeArea(
          child: StreamBuilder<List<SessionRow>>(
            stream: db.watchSessions(),
            builder: (context, snap) {
              final rows = snap.data ?? const <SessionRow>[];
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                children: [
                  Row(
                    children: [
                      IconBtn(icon: 'chevL', onTap: () => Navigator.of(context).pop()),
                      const SizedBox(width: 11),
                      Text('History',
                          style: VyanaType.appBarSerif.copyWith(color: t.text)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (rows.isEmpty)
                    EmptyState(
                      icon: Icons.self_improvement,
                      text: 'No saved sessions yet. Begin a practice to record one.',
                    )
                  else
                    for (final r in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 11),
                        child: _SessionRowCard(row: r),
                      ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SessionRowCard extends StatelessWidget {
  const _SessionRowCard({required this.row});
  final SessionRow row;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final activity = activityById(row.vyanaActivityType);
    final ac = activity == null ? t.green : t.vit(activity.accent);
    final ended = row.endedAt;
    final duration = ended?.difference(row.startedAt);
    return Panel(
      pad: 14,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: ac.withValues(alpha: t.isDark ? 0.2 : 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
                child: VyanaIcon(activity?.icon ?? 'activity', size: 20, color: ac)),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(activity?.name ?? row.vyanaActivityType,
                    style: VyanaType.label.copyWith(color: t.text, fontSize: 15)),
                Text(
                  '${_dateLabel(row.startedAt)}'
                  '${duration == null ? ' · in progress' : ' · ${_fmtDuration(duration)}'}',
                  style: VyanaType.caption.copyWith(color: t.textSec),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _dateLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    final time =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (diff == 0) return 'Today $time';
    if (diff == 1) return 'Yesterday $time';
    return '${d.day}/${d.month} $time';
  }
}

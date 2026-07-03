part of '../../main.dart';

/// Sadhana library — choose a practice for the state you're in.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  String _cat = 'mind';

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final category =
        kActivityCategories.firstWhere((c) => c.id == _cat);
    final activities = activitiesByCat(_cat);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
      children: [
        VAppBar(
          title: 'Practice',
          sub: 'Sadhana',
          actions: [
            IconBtn(
              icon: 'chart',
              onTap: () => openWeeklyInsights(context),
            ),
          ],
        ),
        Text(
          'Choose a practice for the state you are in — not the one you think '
          'you should do.',
          style: VyanaType.bodySm.copyWith(color: t.textSec),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            for (final c in kActivityCategories)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: c == kActivityCategories.last ? 0 : 8),
                  child: _CategoryCard(
                    category: c,
                    active: c.id == _cat,
                    onTap: () => setState(() => _cat = c.id),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Text(category.eyebrow.toUpperCase(),
            style: VyanaType.eyebrow.copyWith(color: t.gold)),
        const SizedBox(height: 12),
        for (final a in activities)
          Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: _ActivityCard(activity: a),
          ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.active,
    required this.onTap,
  });

  final ActivityCategory category;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: active ? t.green.withValues(alpha: t.isDark ? 0.16 : 0.1) : t.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? t.green : t.border),
        ),
        child: Column(
          children: [
            VyanaIcon(category.icon,
                size: 22, color: active ? t.green : t.textSec),
            const SizedBox(height: 8),
            Text(category.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: VyanaType.caption.copyWith(
                    color: active ? t.green : t.textSec,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity});
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final ac = t.vit(activity.accent);
    return Panel(
      pad: 14,
      onTap: () => openActivityDetail(context, activity),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: ac.withValues(alpha: t.isDark ? 0.2 : 0.13),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Center(child: VyanaIcon(activity.icon, size: 22, color: ac)),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(activity.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: VyanaType.label.copyWith(
                              color: t.text, fontSize: 15)),
                    ),
                    if (activity.gps) ...[
                      const SizedBox(width: 6),
                      VyanaIcon('mapPin', size: 13, color: t.textMuted),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(activity.blurb,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: VyanaType.caption.copyWith(color: t.textSec, height: 1.4)),
                const SizedBox(height: 9),
                Row(
                  children: [
                    _MetaChip(label: '${activity.dur} min', icon: 'timer'),
                    const SizedBox(width: 6),
                    _MetaChip(label: guidanceLabel(activity.guidance)),
                  ],
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, this.icon});
  final String label;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: t.elevated,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: t.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            VyanaIcon(icon!, size: 12, color: t.textSec),
            const SizedBox(width: 4),
          ],
          Text(label, style: VyanaType.mono10.copyWith(color: t.textSec)),
        ],
      ),
    );
  }
}

/// Explains how to practice, then starts a session.
class ActivityDetailScreen extends ConsumerStatefulWidget {
  const ActivityDetailScreen({required this.activity, super.key});
  final Activity activity;

  @override
  ConsumerState<ActivityDetailScreen> createState() =>
      _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends ConsumerState<ActivityDetailScreen> {
  late int _duration = widget.activity.dur;

  bool get _hasLengthChooser =>
      widget.activity.cat == 'mind' || widget.activity.cat == 'wellness';

  List<int> get _lengthOptions {
    final base = widget.activity.dur;
    return {
      (base / 2).round().clamp(2, base),
      base,
      base * 2,
    }.toList()
      ..sort();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final a = widget.activity;
    final ac = t.vit(a.accent);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: t.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                  children: [
                    Row(
                      children: [
                        IconBtn(icon: 'chevL', onTap: () => Navigator.of(context).pop()),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Panel(
                      grad: true,
                      pad: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: ac.withValues(alpha: t.isDark ? 0.2 : 0.13),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Center(child: VyanaIcon(a.icon, size: 28, color: ac)),
                          ),
                          const SizedBox(height: 14),
                          Text(a.name,
                              style: VyanaType.titleSerif.copyWith(
                                  color: t.text, fontSize: 27)),
                          const SizedBox(height: 6),
                          Text(a.blurb,
                              style: VyanaType.bodySm.copyWith(
                                  color: t.textSec, height: 1.5)),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _MetaChip(
                                  label: a.gps ? 'GPS' : 'No GPS',
                                  icon: a.gps ? 'mapPin' : 'ring'),
                              _MetaChip(label: guidanceLabel(a.guidance)),
                              _MetaChip(label: 'Ring: ${a.ring}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const SectionHead(eyebrow: 'Method', title: 'How to practice'),
                    for (var i = 0; i < a.how.length; i++)
                      _HowStep(index: i + 1, text: a.how[i], accent: ac),
                    const SizedBox(height: 18),
                    const SectionHead(eyebrow: 'Measured', title: 'What Vyana tracks'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [for (final tr in a.track) _MetaChip(label: tr)],
                    ),
                    const SizedBox(height: 16),
                    Panel(
                      pad: 14,
                      accent: ac,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          VyanaIcon('speaker', size: 18, color: ac),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(a.coaching,
                                style: VyanaType.bodySm.copyWith(
                                    color: t.textSec, height: 1.45)),
                          ),
                        ],
                      ),
                    ),
                    if (_hasLengthChooser) ...[
                      const SizedBox(height: 18),
                      const SectionHead(eyebrow: 'Length', title: 'How long?'),
                      Row(
                        children: [
                          for (final m in _lengthOptions)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Pill(
                                label: '$m min',
                                active: _duration == m,
                                accent: ac,
                                onTap: () => setState(() => _duration = m),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                child: Cta(
                  label: a.cat == 'sport' ? 'Start session' : 'Begin',
                  icon: 'play',
                  onTap: () => _begin(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _begin(BuildContext context) async {
    final controller = ref.read(sessionControllerProvider);
    // If a session is already running, just jump back into it rather than
    // erroring (only one runs at a time).
    if (!controller.active) {
      final error = await controller.start(widget.activity);
      if (!context.mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
        return;
      }
    }
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const LiveSessionScreen()),
    );
  }
}

class _HowStep extends StatelessWidget {
  const _HowStep({required this.index, required this.text, required this.accent});
  final int index;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: t.isDark ? 0.2 : 0.13),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('$index',
                  style: VyanaType.mono12.copyWith(
                      color: accent, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(text,
                  style: VyanaType.bodySm.copyWith(color: t.textSec, height: 1.45)),
            ),
          ),
        ],
      ),
    );
  }
}

part of '../../main.dart';

/// Practice answers "what do I do" — today's suggestion, the user's own pinned
/// set, then the full catalogue. Colour marks ownership: pinned practices take
/// a hue per pin slot; catalogue rows stay grey.
class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key});

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  String _cat = 'sport';
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final ring = ref.watch(ringControllerProvider);
    final dashboard = HomeDashboard.from(ring);
    final state = ring.currentWellnessState();
    final intentState = ref.watch(dayIntentProvider);
    final intent = intentState.intent ?? DayIntent.recover;
    final pins = ref.watch(pinnedPracticesProvider);
    final sessions = ref.watch(recentSessionsProvider).valueOrNull ?? const [];
    final category = kActivityCategories.firstWhere((c) => c.id == _cat);
    final activities = activitiesByCat(_cat);
    final moment = homeMomentAt(DateTime.now());
    final suggestedId = suggestedPracticeFor(
      intent,
      state,
      dashboard.readinessScore,
      moment,
    );
    final suggested = activityById(suggestedId) ?? activityById('breathwork')!;
    final look = scoreLook(dashboard.readinessScore, t);
    final noPins = pins.isEmpty;
    if (noPins && _editing) _editing = false;

    // The catalogue must be a real scroller: category lists differ in length
    // and will grow, so nothing here is clipped under the nav.
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 176),
      children: [
        VAppBar(
          title: 'Practice',
          actions: [
            IconBtn(icon: 'insights', onTap: () => openWeeklyInsights(context)),
          ],
        ),
        // Per the design: SUGGESTED TODAY ── line ── intent chip · score.
        // The chip is editable here (same stored value as Home); the score
        // deep-links to Metrics. No sentence — the reason lives in the card.
        // When the eyebrow and the chip cannot share a line (large text,
        // narrow screen) the status wraps below instead of truncating.
        LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(1);
            final status = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _IntentStatusChip(intent: intent),
                if (dashboard.readinessScore != null) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => openMetricsTab(context, ref),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      child: Text(
                        '${dashboard.readinessScore}',
                        style: VyanaType.caption.copyWith(
                          color: look.hue,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
            if (constraints.maxWidth < 340 * scale) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MonoEyebrow('SUGGESTED TODAY', size: 11, spacing: 0.9),
                  const SizedBox(height: 8),
                  status,
                ],
              );
            }
            return Row(
              children: [
                MonoEyebrow('SUGGESTED TODAY', size: 11, spacing: 0.9),
                const SizedBox(width: 8),
                Expanded(child: Container(height: 1, color: t.hairline)),
                const SizedBox(width: 8),
                status,
              ],
            );
          },
        ),
        const SizedBox(height: 9),
        SuggestedPracticeBlock(
          intent: intent,
          activity: suggested,
          reason: suggestedReasonFor(intent, dashboard.readinessScore),
          compact: true,
        ),
        const SizedBox(height: 24),
        // ── Your practices ────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Text(
                noPins
                    ? 'Pin your practices'
                    : _editing
                    ? 'Hold a card to move it'
                    : 'Your practices',
                style: VyanaType.label.copyWith(
                  color: t.heading,
                  fontSize: 16.5,
                ),
              ),
            ),
            if (!noPins)
              InkWell(
                onTap: () => setState(() => _editing = !_editing),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Text(
                    _editing ? 'Done' : 'Edit',
                    style: VyanaType.caption.copyWith(
                      color: _editing ? intent.soft(t) : t.mutedInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (noPins)
          _PinTile(
            label: 'Add a practice',
            fullWidth: true,
            onTap: () => _openPinPicker(context),
          )
        else
          _PinRail(
            pins: pins,
            sessions: sessions,
            editing: _editing,
            onRemove: (id) =>
                ref.read(pinnedPracticesProvider.notifier).unpin(id),
            onReorder: (from, to) =>
                ref.read(pinnedPracticesProvider.notifier).reorder(from, to),
            onAdd: () => _openPinPicker(context),
          ),
        const SizedBox(height: 24),
        // ── Catalogue ─────────────────────────────────────────────────────
        _CategoryControl(
          active: _cat,
          onPick: (id) => setState(() => _cat = id),
        ),
        const SizedBox(height: 12),
        MonoEyebrow(category.eyebrow, size: 11, spacing: 0.9),
        const SizedBox(height: 8),
        for (final a in activities)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: _CatalogueRow(
              activity: a,
              pinned: pins.contains(a.id),
              onPin: () =>
                  ref.read(pinnedPracticesProvider.notifier).toggle(a.id),
            ),
          ),
      ],
    );
  }

  Future<void> _openPinPicker(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PinPickerSheet(),
    );
  }
}

/// Intent chip in its own colour with a caret; tapping opens the three
/// options and writes to the same stored value Home reads.
class _IntentStatusChip extends ConsumerWidget {
  const _IntentStatusChip({required this.intent});
  final DayIntent intent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final hue = intent.hue(t);
    final soft = t.isDark ? intent.soft(t) : hue;
    // Pre-set (not yet confirmed today): dashed outline, same as Home.
    final confirmed = ref.watch(dayIntentProvider).confirmed;
    return PopupMenuButton<DayIntent>(
      onSelected: (i) => ref.read(dayIntentProvider.notifier).set(i),
      color: t.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: t.border),
      ),
      itemBuilder: (_) => [
        for (final i in DayIntent.values)
          PopupMenuItem<DayIntent>(
            value: i,
            child: Text(
              i.label,
              style: VyanaType.caption.copyWith(
                color: i == intent
                    ? (t.isDark ? i.soft(t) : i.hue(t))
                    : t.textSec,
                fontWeight: i == intent ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
      ],
      child: CustomPaint(
        painter: confirmed ? null : DashedPillPainter(color: hue),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 5, 7, 6),
          decoration: BoxDecoration(
            color: hue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(100),
            border: confirmed
                ? Border.all(color: hue.withValues(alpha: 0.35))
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MonoEyebrow(intent.eyebrow, size: 11, spacing: 0.9, color: soft),
              const SizedBox(width: 2),
              VyanaIcon('chevD', size: 13, color: soft),
            ],
          ),
        ),
      ),
    );
  }
}

/// A horizontal rail of 132px tiles with an edge fade — constant height at
/// any number of pins. The dashed Pin tile sits permanently at the end. In
/// edit mode the rail becomes a reorderable list: drag a card to move it.
class _PinRail extends StatelessWidget {
  const _PinRail({
    required this.pins,
    required this.sessions,
    required this.editing,
    required this.onRemove,
    required this.onReorder,
    required this.onAdd,
  });

  final List<String> pins;
  final List<SessionRow> sessions;
  final bool editing;
  final ValueChanged<String> onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback onAdd;

  static const _tileWidth = 132.0;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final mask = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: const [Colors.white, Colors.white, Colors.transparent],
      stops: const [0, 0.92, 1],
    );
    // Fixed rail height so the reorderable list has bounds; scales with the
    // user's text size so nothing clips.
    final railHeight = MediaQuery.textScalerOf(context).scale(126);

    Widget card(int i) => _PinCard(
      activity: activityById(pins[i])!,
      hue: t.pinPalette[i % t.pinPalette.length],
      meta: pinMetaFor(sessions, pins[i]),
      editing: editing,
      onRemove: () => onRemove(pins[i]),
    );

    if (!editing) {
      return ShaderMask(
        shaderCallback: mask.createShader,
        blendMode: BlendMode.dstIn,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          padding: const EdgeInsets.only(top: 6, right: 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < pins.length; i++) ...[
                card(i),
                const SizedBox(width: 8),
              ],
              _PinTile(label: 'Pin', fullWidth: false, onTap: onAdd),
            ],
          ),
        ),
      );
    }

    // Edit mode: drag to reorder. The Pin tile is the last, undraggable item.
    return SizedBox(
      height: railHeight,
      child: ShaderMask(
        shaderCallback: mask.createShader,
        blendMode: BlendMode.dstIn,
        child: ReorderableListView.builder(
          scrollDirection: Axis.horizontal,
          buildDefaultDragHandles: false,
          padding: const EdgeInsets.only(top: 6, right: 24),
          clipBehavior: Clip.none,
          itemCount: pins.length + 1,
          proxyDecorator: (child, index, animation) => Material(
            color: Colors.transparent,
            child: Transform.scale(scale: 1.04, child: child),
          ),
          // onReorderItem already accounts for the removed item, so `to` is
          // the final slot. Nothing moves past the Pin tile, and the tile
          // itself stays put.
          onReorderItem: (from, to) {
            if (from >= pins.length) return;
            onReorder(from, to.clamp(0, pins.length - 1));
          },
          itemBuilder: (context, i) {
            if (i == pins.length) {
              return Padding(
                key: const ValueKey('pin-tile'),
                padding: const EdgeInsets.only(left: 0),
                child: _PinTile(label: 'Pin', fullWidth: false, onTap: onAdd),
              );
            }
            return Padding(
              key: ValueKey('pin-${pins[i]}'),
              padding: const EdgeInsets.only(right: 8),
              // Hold to lift, then drag; a plain swipe still scrolls the rail
              // so the Pin tile at the end stays reachable in edit mode.
              child: ReorderableDelayedDragStartListener(
                index: i,
                child: card(i),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PinCard extends StatelessWidget {
  const _PinCard({
    required this.activity,
    required this.hue,
    required this.meta,
    required this.editing,
    required this.onRemove,
  });

  final Activity activity;
  final Color hue;
  final String? meta;
  final bool editing;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: _PinRail._tileWidth,
          child: HairlineCard(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
            color: hue.withValues(alpha: 0.08),
            borderColor: hue.withValues(alpha: editing ? 0.5 : 0.25),
            onTap: editing ? null : () => openActivityDetail(context, activity),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: hue.withValues(alpha: 0.19),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(
                    child: VyanaIcon(activity.icon, size: 16, color: hue),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  activity.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VyanaType.caption.copyWith(
                    color: t.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 4),
                MonoEyebrow(meta ?? 'NOT YET DONE', size: 10.5, spacing: 0.5),
              ],
            ),
          ),
        ),
        if (editing)
          Positioned(
            top: -5,
            right: -5,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: t.qPoor,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: VyanaIcon('x', size: 14, color: Color(0xFF071211)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Dashed pin tile — permanent, so the rail's height never changes between
/// modes; full-width in the empty state.
class _PinTile extends StatelessWidget {
  const _PinTile({
    required this.label,
    required this.fullWidth,
    required this.onTap,
  });

  final String label;
  final bool fullWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final tile = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: t.mutedInk.withValues(alpha: 0.45),
            radius: 14,
          ),
          child: Container(
            width: fullWidth ? double.infinity : 132,
            padding: const EdgeInsets.fromLTRB(10, 16, 10, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VyanaIcon('plus', size: 18, color: t.mutedInk),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: VyanaType.caption.copyWith(
                    color: t.mutedInk,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return fullWidth
        ? tile
        : Padding(padding: const EdgeInsets.only(top: 0), child: tile);
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect.deflate(0.5));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final next = math.min(d + 5, metric.length);
        canvas.drawPath(metric.extractPath(d, next), paint);
        d = next + 4;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

/// Compact segmented control — three tall icon cards would push the catalogue
/// off the fold now that the pinned rail sits above it.
class _CategoryControl extends StatelessWidget {
  const _CategoryControl({required this.active, required this.onPick});
  final String active;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.mutedInk.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final c in kActivityCategories)
            Expanded(
              child: InkWell(
                onTap: () => onPick(c.id),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.id == active
                        ? t.heading.withValues(alpha: 0.14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      c.label,
                      maxLines: 1,
                      style: VyanaType.caption.copyWith(
                        color: c.id == active ? t.text : t.mutedInk,
                        fontWeight: c.id == active
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Catalogue row: neutral grey icon (colour is reserved for what is yours),
/// blurb, duration + guidance chips, and a pin glyph.
class _CatalogueRow extends StatelessWidget {
  const _CatalogueRow({
    required this.activity,
    required this.pinned,
    required this.onPin,
  });

  final Activity activity;
  final bool pinned;
  final VoidCallback onPin;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final guide = activity.id == kLucidDreamingId
        ? 'Arms wake capture'
        : guidanceLabel(activity.guidance);
    return HairlineCard(
      padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
      onTap: () => openActivityDetail(context, activity),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: t.mutedInk.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: VyanaIcon(activity.icon, size: 19, color: t.mutedInk),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        activity.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: VyanaType.caption.copyWith(
                          color: t.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (activity.gps) ...[
                      const SizedBox(width: 6),
                      VyanaIcon('mapPin', size: 12, color: t.textMuted),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  activity.blurb,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: VyanaType.caption.copyWith(
                    color: t.textSec,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _MetaChip(label: '${activity.dur} min'),
                    _MetaChip(label: guide),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onPin,
            tooltip: pinned ? 'Unpin' : 'Pin',
            icon: VyanaIcon(
              pinned ? 'pin' : 'pinOff',
              size: 19,
              color: pinned ? t.heading : t.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pick a practice to pin, grouped by category.
class _PinPickerSheet extends ConsumerWidget {
  const _PinPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final pins = ref.watch(pinnedPracticesProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Panel(
          pad: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pin a practice',
                style: VyanaType.titleSerif.copyWith(
                  color: t.text,
                  fontSize: 21,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pinned practices take the next free colour. Tap again to unpin.',
                style: VyanaType.bodySm.copyWith(color: t.textSec),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final c in kActivityCategories) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 6),
                        child: MonoEyebrow(c.eyebrow, size: 10.5),
                      ),
                      for (final a in activitiesByCat(c.id))
                        InkWell(
                          onTap: () => ref
                              .read(pinnedPracticesProvider.notifier)
                              .toggle(a.id),
                          borderRadius: BorderRadius.circular(10),
                          child: ConstrainedBox(
                            // 48dp rows: a list you pick from needs full
                            // touch targets, not 36px lines.
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  VyanaIcon(
                                    a.icon,
                                    size: 20,
                                    color: t.mutedInk,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      a.name,
                                      style: VyanaType.bodySm.copyWith(
                                        color: t.text,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  VyanaIcon(
                                    pins.contains(a.id) ? 'pin' : 'pinOff',
                                    size: 20,
                                    color: pins.contains(a.id)
                                        ? t.heading
                                        : t.textMuted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.fromLTRB(9, 4, 9, 5),
      decoration: BoxDecoration(
        color: t.mutedInk.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: t.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            VyanaIcon(icon!, size: 12, color: t.textSec),
            const SizedBox(width: 4),
          ],
          MonoEyebrow(label, size: 10.5, spacing: 0.5),
        ],
      ),
    );
  }
}

/// Explains how to practice, then starts a session.
class ActivityDetailScreen extends ConsumerStatefulWidget {
  const ActivityDetailScreen({required this.activity, this.minutes, super.key});
  final Activity activity;

  /// Pre-selected length (the short suggested dose); null = catalogue default.
  final int? minutes;

  @override
  ConsumerState<ActivityDetailScreen> createState() =>
      _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends ConsumerState<ActivityDetailScreen> {
  late int _duration = widget.minutes ?? widget.activity.dur;

  bool get _hasLengthChooser =>
      widget.activity.cat == 'mind' || widget.activity.cat == 'wellness';

  List<int> get _lengthOptions {
    final base = widget.activity.dur;
    return {
      ?widget.minutes,
      (base / 2).round().clamp(2, base),
      base,
      base * 2,
    }.toList()..sort();
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
                        IconBtn(
                          icon: 'chevL',
                          onTap: () => Navigator.of(context).pop(),
                        ),
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
                              color: ac.withValues(
                                alpha: t.isDark ? 0.2 : 0.13,
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Center(
                              child: VyanaIcon(a.icon, size: 28, color: ac),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            a.name,
                            style: VyanaType.titleSerif.copyWith(
                              color: t.text,
                              fontSize: 27,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            a.blurb,
                            style: VyanaType.bodySm.copyWith(
                              color: t.textSec,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _MetaChip(
                                label: a.gps ? 'GPS' : 'No GPS',
                                icon: a.gps ? 'mapPin' : 'ring',
                              ),
                              _MetaChip(label: guidanceLabel(a.guidance)),
                              _MetaChip(label: 'Ring: ${a.ring}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const SectionHead(
                      eyebrow: 'Method',
                      title: 'How to practice',
                    ),
                    for (var i = 0; i < a.how.length; i++)
                      _HowStep(index: i + 1, text: a.how[i], accent: ac),
                    const SizedBox(height: 18),
                    const SectionHead(
                      eyebrow: 'Measured',
                      title: 'What Vyana tracks',
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tr in a.track) _MetaChip(label: tr),
                      ],
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
                            child: Text(
                              a.coaching,
                              style: VyanaType.bodySm.copyWith(
                                color: t.textSec,
                                height: 1.45,
                              ),
                            ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
        return;
      }
    }
    if (!context.mounted) return;
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const LiveSessionScreen()));
  }
}

class _HowStep extends StatelessWidget {
  const _HowStep({
    required this.index,
    required this.text,
    required this.accent,
  });
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
              child: Text(
                '$index',
                style: VyanaType.mono12.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                text,
                style: VyanaType.bodySm.copyWith(
                  color: t.textSec,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

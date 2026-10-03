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
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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
    // Watched so the user's own sports appear without a restart.
    ref.watch(userActivitiesProvider);
    final searching = _query.trim().isNotEmpty;
    final activities =
        searching ? searchActivities(_query) : allActivitiesByCat(_cat);
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
            // Bug 10: history's only entry point was a calendar icon buried
            // on Weekly Insights. It belongs where practices are.
            IconBtn(
              icon: 'calendar',
              onTap: () => openSessionHistory(context),
            ),
            const SizedBox(width: 8),
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
        const SizedBox(height: 20),
        // §5 / mock 12c: the last session, openable. One line, because the
        // point is to be able to get back to it, not to re-report it.
        _RecentLine(sessions: sessions),
        const SizedBox(height: 20),
        // ── Catalogue ─────────────────────────────────────────────────────
        // §5: Movement is past thirty rows, so there has to be a way in
        // other than scrolling. Search matches across all three categories.
        _CatalogueSearch(
          controller: _search,
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 10),
        if (!searching) ...[
          _CategoryControl(
            active: _cat,
            onPick: (id) => setState(() => _cat = id),
          ),
          const SizedBox(height: 12),
          MonoEyebrow(category.eyebrow, size: 11, spacing: 0.9),
        ] else
          MonoEyebrow(
            activities.isEmpty
                ? 'NO MATCHES'
                : '${activities.length} '
                    '${activities.length == 1 ? 'MATCH' : 'MATCHES'}',
            size: 11,
            spacing: 0.9,
          ),
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
        // Last row of Movement, and the fallback when search finds nothing.
        if (searching || _cat == 'sport')
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: _AddYourOwnRow(
              query: _query.trim(),
              onTap: () => showAddYourOwnSportSheet(
                context,
                ref,
                prefill: _query.trim(),
              ),
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
                    // §5 Length: a duration is only shown where the practice
                    // actually has one. Start/end sessions were advertising a
                    // "35 min" they never enforced.
                    if (activity.isTimed)
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
  const _MetaChip({required this.label});
  final String label;

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
      child: MonoEyebrow(label, size: 10.5, spacing: 0.5),
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

/// Gym's remembered mode (§5, mock 12d).
const _gymModeKey = 'vyana.practice.gymTracksSets';

class _ActivityDetailScreenState extends ConsumerState<ActivityDetailScreen> {
  /// Null for open-ended sessions: no preset length except timed practices.
  late int _duration = widget.minutes ?? widget.activity.dur;

  /// Gym only. Defaults to "Start and end", as the handover specifies.
  bool _tracksSets = false;

  @override
  void initState() {
    super.initState();
    if (widget.activity.kind == 'strength') {
      unawaited(_loadGymMode());
    }
  }

  /// A user-added sport can be removed from its own practice screen. Its
  /// past sessions stay, since they are stored by id and still carry the
  /// name in their summary.
  Future<void> _deleteUserSport(BuildContext context) async {
    final confirmed = await showVyanaConfirmDialog<bool>(
      context: context,
      title: 'Remove ${widget.activity.name}?',
      message: 'It leaves your catalogue. Sessions you already recorded are '
          'kept.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (confirmed != true) return;
    await ref.read(databaseProvider).deleteUserActivity(widget.activity.id);
    await ref.read(pinnedPracticesProvider.notifier).unpin(widget.activity.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _loadGymMode() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(_gymModeKey) ?? false;
    if (mounted) setState(() => _tracksSets = stored);
  }

  /// §5 Length: only a timed practice has a length to choose, because only a
  /// timed practice keeps it. Movement is open-ended and counts up, so
  /// offering it a preset would promise an end it never delivers.
  bool get _hasLengthChooser => widget.activity.isTimed;

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
    final pins = ref.watch(pinnedPracticesProvider);
    final pinIndex = pins.indexOf(a.id);
    final pinned = pinIndex >= 0;
    // §5/§11: the icon takes its pin-slot hue when pinned and grey otherwise.
    // The old per-activity `t.vit(a.accent)` broke the colour rule — identity
    // colour belongs to the four key metrics, not to every practice.
    final ac = pinned
        ? t.pinPalette[pinIndex % t.pinPalette.length]
        : t.mutedInk;
    final sessions = <SessionRow>[
      for (final row in ref.watch(recentSessionsProvider).valueOrNull ??
          const <SessionRow>[])
        if (row.vyanaActivityType == a.id && row.endedAt != null) row,
    ];
    final everDone = sessions.isNotEmpty;
    final category =
        kActivityCategories.firstWhere((c) => c.id == a.cat).eyebrow;

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
                        // 12c: an unpinned practice gets the same pin toggle
                        // as its catalogue row, at the header's right.
                        IconBtn(
                          icon: pinned ? 'pin' : 'pinOff',
                          active: pinned,
                          onTap: () => ref
                              .read(pinnedPracticesProvider.notifier)
                              .toggle(a.id),
                        ),
                        if (a.id.startsWith('user_')) ...[
                          const SizedBox(width: 8),
                          IconBtn(
                            icon: 'trash',
                            onTap: () => _deleteUserSport(context),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Header row: icon + name, then CATEGORY · PINNED.
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: ac.withValues(alpha: t.isDark ? 0.2 : 0.13),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: VyanaIcon(a.icon, size: 25, color: ac),
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              MonoEyebrow(
                                pinned
                                    ? '${category.toUpperCase()} · PINNED'
                                    : category.toUpperCase(),
                                size: 11.5,
                                spacing: 0.9,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                a.name,
                                style: VyanaType.titleSerif.copyWith(
                                  color: t.text,
                                  fontSize: 24,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      a.blurb,
                      style: VyanaType.bodySm.copyWith(
                        color: t.textSec,
                        height: 1.5,
                      ),
                    ),
                    // The meta chips (GPS / guidance / Ring: …), the "What
                    // Vyana tracks" chips and the coaching panel are gone:
                    // they described the app, not the practice.
                    if (everDone) ...[
                      const SizedBox(height: 20),
                      _ActivityHistory(activity: a, sessions: sessions),
                    ],
                    const SizedBox(height: 18),
                    // Open by default until the practice has been done once.
                    _HowItWorks(
                      activity: a,
                      accent: ac,
                      initiallyOpen: !everDone,
                    ),
                    if (_hasLengthChooser) ...[
                      const SizedBox(height: 18),
                      const SectionHead(eyebrow: 'Length', title: 'How long?'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final m in _lengthOptions)
                            Pill(
                              label: '$m min',
                              active: _duration == m,
                              accent: ac,
                              onTap: () => setState(() => _duration = m),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // §5 (12d): Gym's mode switch sits directly above Start, with
              // a one-line hint, and the choice is remembered.
              if (a.kind == 'strength')
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: _GymModeSwitch(
                    tracksSets: _tracksSets,
                    onPick: (value) async {
                      setState(() => _tracksSets = value);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool(_gymModeKey, value);
                    },
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
      // Bug 12: the chosen length now reaches the session, so a suggested
      // three minutes counts down and ends instead of running forever.
      final error = await controller.start(
        widget.activity,
        minutes: _hasLengthChooser ? _duration : null,
        tracksSets: _tracksSets,
      );
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

/// §5 "Recent": the RECENT eyebrow with See all on the right, then the last
/// three finished sessions of any practice — each as name + mono day. Wraps
/// to a second line rather than scrolling or truncating a name.
class _RecentLine extends StatelessWidget {
  const _RecentLine({required this.sessions});

  final List<SessionRow> sessions;

  @override
  Widget build(BuildContext context) {
    final finished = [
      for (final s in sessions)
        if (s.endedAt != null) s,
    ].take(3).toList();
    if (finished.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: MonoEyebrow('RECENT', size: 11.5, spacing: 0.9)),
            BorderedPill(
              label: 'See all',
              onTap: () => openSessionHistory(context),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final row in finished)
              _RecentChip(
                row: row,
                // A name opens that practice with its history (12a).
                onTap: () {
                  final activity = activityById(row.vyanaActivityType);
                  if (activity == null) {
                    openPastSession(context, row);
                    return;
                  }
                  openActivityDetail(context, activity);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _RecentChip extends StatelessWidget {
  const _RecentChip({required this.row, required this.onTap});

  final SessionRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final activity = activityById(row.vyanaActivityType);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: t.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Never truncated: the whole name stays, the row wraps instead.
            Text(
              activity?.name ?? 'Session',
              style: VyanaType.caption.copyWith(color: t.text, fontSize: 13),
            ),
            const SizedBox(width: 7),
            MonoEyebrow(_recentDay(row.startedAt), size: 11.5, spacing: 0.9),
          ],
        ),
      ),
    );
  }
}

/// TODAY for today, the weekday within the last week, a date beyond that.
String _recentDay(DateTime at) {
  const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  const months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final ago = today.difference(day).inDays;
  if (ago == 0) return 'TODAY';
  if (ago < 7) return days[at.weekday - 1];
  return '${at.day} ${months[at.month - 1]}';
}

/// §5 "Catalogue search": a single field above the category control.
class _CatalogueSearch extends StatelessWidget {
  const _CatalogueSearch({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.hairline),
      ),
      child: Row(
        children: [
          VyanaIcon('search', size: 17, color: t.mutedInk),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: VyanaType.bodySm.copyWith(color: t.text, fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Search practices',
                hintStyle:
                    VyanaType.bodySm.copyWith(color: t.mutedInk, fontSize: 14),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            InkWell(
              onTap: () {
                controller.clear();
                onChanged('');
              },
              borderRadius: BorderRadius.circular(100),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: VyanaIcon('x', size: 15, color: t.mutedInk),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Add your own sport", or "Add 'Curling' as your own sport" when a search
/// found nothing (§5).
class _AddYourOwnRow extends StatelessWidget {
  const _AddYourOwnRow({required this.query, required this.onTap});

  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return HairlineCard(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      onTap: onTap,
      child: Row(
        children: [
          VyanaIcon('sports', size: 18, color: t.mutedInk),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              query.isEmpty
                  ? 'Add your own sport'
                  : "Add '$query' as your own sport",
              style: VyanaType.label.copyWith(color: t.text, fontSize: 14),
            ),
          ),
          VyanaIcon('chevR', size: 16, color: t.mutedInk),
        ],
      ),
    );
  }
}

/// One name and one question — "Where do you do it?" — because that is all
/// the app actually needs to know to track it (§5, mock 12e).
Future<void> showAddYourOwnSportSheet(
  BuildContext context,
  WidgetRef ref, {
  String prefill = '',
}) {
  final t = context.vyana;
  final name = TextEditingController(text: prefill);
  var icon = 'sports';

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        16, 0, 16, 16 + MediaQuery.viewInsetsOf(sheetContext).bottom +
            MediaQuery.paddingOf(sheetContext).bottom,
      ),
      child: StatefulBuilder(
        builder: (context, setState) {
          Future<void> add(String kind) async {
            final label = name.text.trim();
            if (label.isEmpty) return;
            final navigator = Navigator.of(sheetContext);
            await ref.read(databaseProvider).upsertUserActivity(
                  id: 'user_${DateTime.now().microsecondsSinceEpoch}',
                  name: label,
                  kind: kind,
                  icon: icon,
                );
            if (navigator.canPop()) navigator.pop();
          }

          return Panel(
            pad: 18,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MonoEyebrow('YOUR OWN SPORT', size: 9),
                const SizedBox(height: 6),
                Text(
                  'What do you call it?',
                  style:
                      VyanaType.titleSerif.copyWith(color: t.text, fontSize: 21),
                ),
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.hairline),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: name,
                          autofocus: prefill.isEmpty,
                          onChanged: (_) => setState(() {}),
                          style: VyanaType.bodySm
                              .copyWith(color: t.text, fontSize: 14),
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: 'Curling',
                            hintStyle: VyanaType.bodySm
                                .copyWith(color: t.mutedInk, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                MonoEyebrow('GLYPH', size: 9),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final glyph in const [
                      'sports', 'run', 'bike', 'swim', 'racket', 'volleyball',
                      'hockey', 'boxing', 'ski', 'skate', 'surf', 'kayak',
                    ])
                      InkWell(
                        onTap: () => setState(() => icon = glyph),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: icon == glyph ? t.green : t.hairline,
                              width: icon == glyph ? 1.6 : 1,
                            ),
                          ),
                          child: Center(
                            child: VyanaIcon(
                              glyph,
                              size: 20,
                              color: icon == glyph ? t.green : t.mutedInk,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Where do you do it?',
                  style: VyanaType.label.copyWith(color: t.text, fontSize: 15),
                ),
                const SizedBox(height: 10),
                Panel(
                  pad: 13,
                  onTap: name.text.trim().isEmpty ? null : () => add('gps'),
                  child: Row(
                    children: [
                      VyanaIcon('mapPin', size: 17, color: t.mutedInk),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          'Outdoors, moving around',
                          style: VyanaType.label.copyWith(color: t.text),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Panel(
                  pad: 13,
                  onTap: name.text.trim().isEmpty ? null : () => add('indoor'),
                  child: Row(
                    children: [
                      VyanaIcon('dumbbell', size: 17, color: t.mutedInk),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          'Indoors or in one place',
                          style: VyanaType.label.copyWith(color: t.text),
                        ),
                      ),
                    ],
                  ),
                ),
                if (name.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    "Adds ${name.text.trim()} to Movement, where it can be "
                    'pinned and keeps its own history.',
                    style: VyanaType.caption
                        .copyWith(color: t.mutedInk, fontSize: 12.5),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    ),
  );
}

/// Gym's two modes, with the hint that says what each one asks of you.
class _GymModeSwitch extends StatelessWidget {
  const _GymModeSwitch({required this.tracksSets, required this.onPick});

  final bool tracksSets;
  final ValueChanged<bool> onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    Widget option(String label, bool value) {
      final active = tracksSets == value;
      return Expanded(
        child: InkWell(
          onTap: () => onPick(value),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            decoration: BoxDecoration(
              color: active ? t.elevated : null,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: active ? t.green : t.hairline),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: VyanaType.caption.copyWith(
                  color: active ? t.text : t.textSec,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            option('Start and end', false),
            const SizedBox(width: 8),
            option('Track sets & rest', true),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          tracksSets
              ? 'Log a set, then rest; Vyana watches your HR drop.'
              : 'Nothing to tap until you finish.',
          style: VyanaType.caption.copyWith(color: t.mutedInk, fontSize: 12.5),
        ),
      ],
    );
  }
}

/// §5 (12a): "Your history" — three tiles for the last 30 days, then this
/// activity's sessions newest first. Hidden when the practice has never been
/// done, which the caller checks.
class _ActivityHistory extends StatelessWidget {
  const _ActivityHistory({required this.activity, required this.sessions});

  final Activity activity;
  final List<SessionRow> sessions;

  @override
  Widget build(BuildContext context) {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final recent = [
      for (final s in sessions)
        if (s.startedAt.isAfter(cutoff)) s,
    ];
    var totalMinutes = 0;
    final hrs = <int>[];
    for (final s in recent) {
      totalMinutes += s.endedAt!.difference(s.startedAt).inMinutes;
      final hr = _avgHrOf(s);
      if (hr != null) hrs.add(hr);
    }
    final avgHr = hrs.isEmpty
        ? null
        : (hrs.reduce((a, b) => a + b) / hrs.length).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHead(eyebrow: 'Last 30 days', title: 'Your history'),
        Row(
          children: [
            _HistoryTile(label: 'SESSIONS', value: '${recent.length}'),
            const SizedBox(width: 8),
            _HistoryTile(label: 'TOTAL', value: '${totalMinutes}m'),
            const SizedBox(width: 8),
            _HistoryTile(
              label: 'AVG HR',
              value: avgHr == null ? '—' : '$avgHr',
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final s in sessions.take(10))
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: _ActivitySessionRow(row: s),
          ),
      ],
    );
  }
}

int? _avgHrOf(SessionRow row) {
  final raw = row.summaryJson;
  if (raw == null) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      final v = decoded['avgHr'];
      if (v is num && v > 0) return v.round();
    }
  } catch (_) {}
  return null;
}

int? _maxHrOf(SessionRow row) {
  final raw = row.summaryJson;
  if (raw == null) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      final v = decoded['maxHr'];
      if (v is num && v > 0) return v.round();
    }
  } catch (_) {}
  return null;
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
        decoration: BoxDecoration(
          color: t.elevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            MonoEyebrow(label, size: 11.5, spacing: 0.9),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: VyanaType.label.copyWith(color: t.text, fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivitySessionRow extends StatelessWidget {
  const _ActivitySessionRow({required this.row});

  final SessionRow row;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final minutes = row.endedAt!.difference(row.startedAt).inMinutes;
    final avg = _avgHrOf(row);
    final max = _maxHrOf(row);
    return HairlineCard(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      onTap: () => openPastSession(context, row),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 4,
        children: [
          Text(
            '${_recentDay(row.startedAt)} · '
            '${row.startedAt.hour.toString().padLeft(2, '0')}:'
            '${row.startedAt.minute.toString().padLeft(2, '0')}',
            style: VyanaType.caption.copyWith(color: t.text, fontSize: 13.5),
          ),
          Text(
            '${minutes}m'
            '${avg == null ? '' : ' · $avg'}'
            '${max == null ? '' : ' · $max bpm'}',
            style: VyanaType.mono10.copyWith(color: t.mutedInk),
          ),
        ],
      ),
    );
  }
}

/// One collapsed row, open by default until the practice has been done once.
class _HowItWorks extends StatefulWidget {
  const _HowItWorks({
    required this.activity,
    required this.accent,
    required this.initiallyOpen,
  });

  final Activity activity;
  final Color accent;
  final bool initiallyOpen;

  @override
  State<_HowItWorks> createState() => _HowItWorksState();
}

class _HowItWorksState extends State<_HowItWorks> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final a = widget.activity;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'How it works',
                    style: VyanaType.label
                        .copyWith(color: t.heading, fontSize: 16.5),
                  ),
                ),
                VyanaIcon(
                  _open ? 'chevU' : 'chevD',
                  size: 18,
                  color: t.mutedInk,
                ),
              ],
            ),
          ),
        ),
        if (_open) ...[
          for (var i = 0; i < a.how.length; i++)
            _HowStep(index: i + 1, text: a.how[i], accent: widget.accent),
          // dur appears only as a broad first-time suggestion, never a timer.
          if (!a.isTimed && a.dur > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Most people start with around ${a.dur} minutes, but this one '
              'runs until you end it.',
              style: VyanaType.caption.copyWith(
                color: t.mutedInk,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

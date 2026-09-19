part of '../../main.dart';

// ── Shared 2.0 chrome ────────────────────────────────────────────────────────
// The pieces that recur across Home · Metrics · Practice · Journal · You so
// one assistant, one warning and one kind of claim look identical everywhere.

/// Smallest sizes the app renders: 12sp for captions, 11.5 for uppercase
/// tracked mono eyebrows (which read a size larger), 14 for anything read or
/// tapped. Material's accessibility floor is 12sp.
const double kMinCaptionSize = 12;
const double kMinEyebrowSize = 11.5;
const double kMinBodySize = 14;

/// Mono eyebrow: Space Mono, caps, tracked, never below [kMinEyebrowSize].
class MonoEyebrow extends StatelessWidget {
  const MonoEyebrow(
    this.text, {
    super.key,
    this.color,
    this.size = 11.5,
    this.weight = FontWeight.w600,
    this.spacing = 1.1,
    this.maxLines = 1,
  });

  final String text;
  final Color? color;
  final double size;
  final FontWeight weight;
  final double spacing;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: VyanaType.mono,
        // Floor: uppercase tracked mono below this is unreadable on a phone.
        fontSize: math.max(size, kMinEyebrowSize),
        fontWeight: weight,
        letterSpacing: spacing,
        height: 1.2,
        color: color ?? context.vyana.mutedInk,
      ),
    );
  }
}

/// Neutral 15px/600 section heading with an optional trailing action. Never
/// coloured — a coloured heading would read as a verdict.
class QuietHeading extends StatelessWidget {
  const QuietHeading(
    this.title, {
    super.key,
    this.action,
    this.onAction,
    this.trailing,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: VyanaType.label.copyWith(
              color: t.heading,
              fontSize: 16.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ?trailing,
        if (action != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                action!,
                style: VyanaType.caption.copyWith(
                  color: t.mutedInk,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The hairline-bordered card of the 2.0 screens: bg card, 1px hairline,
/// 14px radius, no shadow. Flex-friendly — no fixed height anywhere.
class HairlineCard extends StatelessWidget {
  const HairlineCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = 14,
    this.opacity = 1,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final card = Opacity(
      opacity: opacity,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? t.card,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor ?? t.hairline),
        ),
        child: child,
      ),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: card,
      ),
    );
  }
}

/// Bordered pill action ("See all & test", "Record") — a grey label beside a
/// grey heading does not read as tappable, so actions get a border.
class BorderedPill extends StatelessWidget {
  const BorderedPill({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.color,
  });

  final String label;
  final VoidCallback? onTap;
  final String? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final c = color ?? t.heading;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 6, 11, 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: t.mutedInk.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                VyanaIcon(icon!, size: 13, color: c),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: VyanaType.caption.copyWith(
                  color: c,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Nova ────────────────────────────────────────────────────────────────────

/// Nova on every screen: a right-aligned pill above the nav — deliberately not
/// full-width, so it never reads as a sixth tab — and neutral grey in every
/// state, because gold would compete with the intent accent.
class NovaPill extends ConsumerWidget {
  const NovaPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.vyana;
    final manager = ref.watch(guideModelManagerProvider);
    final ready = manager.modelReady;
    final downloading = manager.downloadingState;
    final tint = t.mutedInk;
    final bright = t.heading;

    final String line;
    final String glyph;
    final String trailing;
    if (ready) {
      line = 'Ask Nova';
      glyph = 'brain';
      trailing = 'chevR';
    } else if (downloading != null) {
      final pct = (downloading.progress * 100).clamp(0, 100).round();
      line = downloading.status == GuideModelStatus.verifying
          ? 'Verifying your private guide'
          : 'Installing your private guide · $pct%';
      glyph = 'download';
      trailing = 'refresh';
    } else {
      line = 'Install private AI guide · $kGuideModelSizeLabel';
      glyph = 'download';
      trailing = 'download';
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => ready ? openGuideChat(context) : openGuideStore(context),
          borderRadius: BorderRadius.circular(100),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 9, 12, 10),
            // Solid, not tinted: it floats over scrolling content, so a
            // translucent pill just smears whatever is under it.
            decoration: BoxDecoration(
              color: t.elevated,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: tint.withValues(alpha: ready ? 0.35 : 0.45),
              ),
              boxShadow: t.shadowSoft,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                VyanaIcon(glyph, size: 15, color: bright),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VyanaType.caption.copyWith(
                      color: bright,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                VyanaIcon(trailing, size: 16, color: bright),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens Nova's chat as a pushed screen (Guides is no longer a tab).
Future<void> openGuideChat(BuildContext context) {
  return Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => const GuideChatScreen()));
}

// ── Ring status ─────────────────────────────────────────────────────────────

enum RingUiState { synced, syncing, stale, disconnected, charging }

RingUiState ringUiStateOf(RingController c) {
  if (c.isSyncing) return RingUiState.syncing;
  if (ringIsOffline(c)) return RingUiState.disconnected;
  if (ringIsStale(c)) return RingUiState.stale;
  return RingUiState.synced;
}

String _clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String _agoLabel(DateTime at) {
  final d = DateTime.now().difference(at);
  if (d.inMinutes < 60) return '${math.max(1, d.inMinutes)} MIN AGO';
  if (d.inHours < 48) return '${d.inHours} HOURS AGO';
  return '${d.inDays} DAYS AGO';
}

/// The eyebrow line under the lotus: "RING SYNCED · 06:41", "SYNCING…",
/// "LAST SYNC 14 HOURS AGO", "RING NOT CONNECTED".
({String text, Color color, bool pulse}) ringEyebrowFor(
  RingController c,
  VyanaColors t,
) {
  if (!c.hasRingContext) {
    return (text: 'NO RING YET', color: t.mutedInk, pulse: false);
  }
  final last = c.lastSyncedAt;
  switch (ringUiStateOf(c)) {
    case RingUiState.syncing:
      return (text: 'SYNCING YOUR RING', color: t.gold, pulse: true);
    case RingUiState.disconnected:
      return (text: 'RING NOT CONNECTED', color: t.qPoor, pulse: false);
    case RingUiState.stale:
      return (
        text: last == null ? 'NOT SYNCED YET' : 'LAST SYNC ${_agoLabel(last)}',
        color: t.gold,
        pulse: false,
      );
    case RingUiState.charging:
    case RingUiState.synced:
      if (!c.isConnected) {
        // A short drop while the SDK reconnects — say so, quietly.
        return (
          text: c.isConnecting ? 'RECONNECTING' : 'RING OUT OF REACH',
          color: t.mutedInk,
          pulse: c.isConnecting,
        );
      }
      return (
        text: last == null ? 'RING CONNECTED' : 'RING SYNCED · ${_clock(last)}',
        color: t.qGood,
        pulse: true,
      );
  }
}

/// One plain line for the ring on You: name · state, never the SDK's raw
/// status string (which can read "Charging 36%" while the ring is out of
/// reach and unsynced).
String ringLineFor(RingController c) {
  if (!c.hasRingContext) return 'No ring yet';
  final name = c.pairedRing?.displayName ?? 'PRANA ring';
  if (c.isSyncing) return '$name · syncing';
  if (c.isConnected) return '$name · connected';
  if (c.isConnecting) return '$name · reconnecting';
  final last = c.lastSyncedAt;
  final since = last == null ? 'never synced' : 'last synced ${_clock(last)}';
  return '$name · out of reach · $since';
}

/// 6px status dot that pulses while the ring is live.
class RingStatusDot extends StatefulWidget {
  const RingStatusDot({super.key, required this.color, required this.pulse});
  final Color color;
  final bool pulse;

  @override
  State<RingStatusDot> createState() => _RingStatusDotState();
}

class _RingStatusDotState extends State<RingStatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.pulse) {
      return Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      );
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Opacity(
        opacity: 0.5 + 0.5 * _c.value,
        child: Transform.scale(
          scale: 1 + 0.35 * _c.value,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

/// Stale / disconnected banner with the fix inline — Sync now / Reconnect —
/// so the user can act where they noticed the problem. Shown on Home (above
/// the nav) and on Metrics (under the header).
class RingStaleBanner extends StatelessWidget {
  const RingStaleBanner({
    super.key,
    required this.controller,
    this.body,
    this.margin = EdgeInsets.zero,
  });

  final RingController controller;
  final String? body;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final c = controller;
    final state = ringUiStateOf(c);
    if (state != RingUiState.stale && state != RingUiState.disconnected) {
      return const SizedBox.shrink();
    }
    final error = state == RingUiState.disconnected;
    final tone = error ? t.qPoor : t.gold;
    final last = c.lastSyncedAt;
    final title = error
        ? 'Nothing is reading you right now'
        : last == null
        ? 'Today is missing'
        : 'Today is missing ${DateTime.now().difference(last).inHours} hours';
    final line =
        body ??
        (error
            ? (last == null
                  ? 'Your ring is out of reach.'
                  : 'Numbers are from ${_clock(last)}.')
            : 'The ring has data it hasn\'t handed over.');
    final action = error ? 'Reconnect' : 'Sync now';
    final busy = c.isConnecting || c.isSyncing;

    return Padding(
      padding: margin,
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tone.withValues(alpha: 0.38)),
        ),
        child: Row(
          children: [
            VyanaIcon(error ? 'bluetooth' : 'refresh', size: 19, color: tone),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: VyanaType.caption.copyWith(
                      color: t.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    line,
                    style: VyanaType.caption.copyWith(
                      color: t.textSec,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: busy
                  ? null
                  : () => error
                        ? unawaited(c.reconnectSavedRing(force: true))
                        : unawaited(syncRingWithFeedback(context, c)),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Text(
                  busy ? 'Working…' : action,
                  style: VyanaType.caption.copyWith(
                    color: tone,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Intent chips ────────────────────────────────────────────────────────────

/// "TODAY" + Recover / Perform / Settle. The selected chip carries the intent
/// colour on first paint whether it was pre-set or tapped.
class IntentRow extends ConsumerWidget {
  const IntentRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intentState = ref.watch(dayIntentProvider);
    final intent = intentState.intent;
    Widget chip(DayIntent i) => _IntentChip(
          intent: i,
          selected: intent == i,
          // Pre-set but not yet confirmed: same colour, dashed border.
          dashed: intent == i && !intentState.confirmed,
          onTap: () => ref.read(dayIntentProvider.notifier).set(i),
        );
    // Three equal chips when they fit; at large text or on a narrow screen
    // they wrap onto new lines instead of truncating their labels.
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final fits = constraints.maxWidth >= 300 * scale;
        if (fits) {
          return Row(
            children: [
              MonoEyebrow('TODAY', size: 11, spacing: 0.9),
              const SizedBox(width: 10),
              for (final i in DayIntent.values) ...[
                Expanded(child: chip(i)),
                if (i != DayIntent.values.last) const SizedBox(width: 6),
              ],
            ],
          );
        }
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            MonoEyebrow('TODAY', size: 11, spacing: 0.9),
            for (final i in DayIntent.values)
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 96),
                child: chip(i),
              ),
          ],
        );
      },
    );
  }
}

class _IntentChip extends StatelessWidget {
  const _IntentChip({
    required this.intent,
    required this.selected,
    required this.onTap,
    this.dashed = false,
  });

  final DayIntent intent;
  final bool selected;
  final bool dashed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final hue = intent.hue(t);
    final soft = intent.soft(t);
    final chip = AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 7),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? hue.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
            border: dashed
                ? null
                : Border.all(color: selected ? hue : t.border),
          ),
          child: Text(
            intent.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: VyanaType.caption.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: selected ? (t.isDark ? soft : hue) : t.textSec,
            ),
          ),
        );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: dashed
            ? CustomPaint(
                painter: DashedPillPainter(color: hue),
                child: chip,
              )
            : chip,
      ),
    );
  }
}

/// 1px dashed pill outline — the "pre-set, tap to confirm" border.
class DashedPillPainter extends CustomPainter {
  DashedPillPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(0.5),
      Radius.circular(size.height),
    );
    final path = Path()..addRRect(rrect);
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
  bool shouldRepaint(DashedPillPainter old) => old.color != color;
}

// ── Nova pattern card ───────────────────────────────────────────────────────

/// The same "Nova found a pattern" component on Metrics and Journal: subject
/// glyph, eyebrow, one sentence, chevron — two lines and nothing else. The
/// tint follows the subject, not Nova. Renders nothing when there is no
/// pattern: a screen that fabricates one is lying on day one.
class PatternCard extends StatelessWidget {
  const PatternCard({
    super.key,
    required this.pattern,
    required this.tint,
    required this.glyph,
    this.margin = EdgeInsets.zero,
  });

  final PatternRow? pattern;
  final Color tint;
  final String glyph;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final p = pattern;
    if (p == null) return const SizedBox.shrink();
    final t = context.vyana;
    final status = patternStatusOf(p);
    final ended = status == PatternStatus.broken;
    final ink = ended
        ? t.mutedInk
        : (t.isDark ? Color.lerp(tint, Colors.white, 0.35)! : tint);
    final rgb = ended ? t.mutedInk : tint;
    return Padding(
      padding: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => openPatternDetail(context, p),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
            decoration: BoxDecoration(
              color: rgb.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: rgb.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: rgb.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Center(
                    child: VyanaIcon(
                      ended ? 'check' : glyph,
                      size: 18,
                      color: ink,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MonoEyebrow(
                        status.eyebrow,
                        size: 11,
                        spacing: 0.8,
                        color: ink,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.claim,
                        style: VyanaType.caption.copyWith(
                          color: t.text,
                          fontSize: 14.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                VyanaIcon('chevR', size: 17, color: ink),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Subject → tint and glyph for a pattern card.
({Color tint, String glyph}) patternLook(PatternRow p, VyanaColors t) {
  if (p.source == 'journal') return (tint: t.jDream, glyph: 'drop');
  final a = activityById(p.subject);
  return (tint: t.jReflection, glyph: a?.icon ?? 'activity');
}

// ── Score words ─────────────────────────────────────────────────────────────

/// Quality colour + state word for a readiness score: Ready · Balanced ·
/// Depleted. Words deliberately diverge from the intent chips (no "Steady"
/// beside "Settle").
({Color hue, Color soft, String word, String state}) scoreLook(
  int? score,
  VyanaColors t,
) {
  if (score == null) {
    // No score is not a verdict: neutral grey, not the amber band.
    return (hue: t.mutedInk, soft: t.mutedInk, word: '—', state: 'No read yet');
  }
  if (score >= 70) {
    return (hue: t.qGood, soft: t.qGoodSoft, word: 'READY', state: 'Ready');
  }
  if (score >= 50) {
    return (hue: t.qLevel, soft: t.qLevelSoft, word: 'FAIR', state: 'Balanced');
  }
  return (hue: t.qPoor, soft: t.qPoorSoft, word: 'LOW', state: 'Depleted');
}

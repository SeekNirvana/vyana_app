import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../brand/wallet_branding.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'vyana_icon.dart';

/// Shared UI primitives ported from the handoff's `components.jsx`. These are
/// the building blocks reused across every screen.

/// The "premium card" used everywhere. Optional left [accent] bar and tap.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.pad = 18,
    this.grad = false,
    this.onTap,
    this.accent,
    this.radius = 22,
  });

  final Widget child;
  final double pad;
  final bool grad;
  final VoidCallback? onTap;
  final Color? accent;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final decoration = BoxDecoration(
      color: grad ? null : t.card,
      gradient: grad ? t.cardGradient : null,
      border: Border.all(color: t.border),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: t.shadowSoft,
    );

    Widget content = Padding(padding: EdgeInsets.all(pad), child: child);
    if (accent != null) {
      content = Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 3, color: accent),
          ),
          content,
        ],
      );
    }

    final card = DecoratedBox(
      decoration: decoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: content,
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

/// Gold eyebrow + serif title, with optional trailing action button.
class SectionHead extends StatelessWidget {
  const SectionHead({
    super.key,
    this.eyebrow,
    required this.title,
    this.action,
    this.onAction,
  });

  final String? eyebrow;
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow != null) ...[
                  Text(eyebrow!.toUpperCase(),
                      style: VyanaType.eyebrow.copyWith(color: t.gold)),
                  const SizedBox(height: 7),
                ],
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VyanaType.titleSerif.copyWith(color: t.text)),
              ],
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(action!,
                  style: VyanaType.label.copyWith(color: t.green)),
            ),
        ],
      ),
    );
  }
}

/// Pill-shaped toggle/filter button.
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    this.active = false,
    this.onTap,
    this.accent,
    this.icon,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;
  final Color? accent;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final c = accent ?? t.green;
    return Material(
      color: active ? c.withValues(alpha: t.isDark ? 0.18 : 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: active ? c : t.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                VyanaIcon(icon!, size: 15, color: active ? c : t.textSec),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: VyanaType.label.copyWith(color: active ? c : t.textSec)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Primary call-to-action — solid gradient or outlined.
class Cta extends StatelessWidget {
  const Cta({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.solid = true,
    this.disabled = false,
  });

  final String label;
  final VoidCallback? onTap;
  final String? icon;
  final bool solid;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final fg = solid ? Colors.white : t.text;
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              gradient: solid ? t.ctaGradient : null,
              borderRadius: BorderRadius.circular(16),
              border: solid ? null : Border.all(color: t.border, width: 1.5),
              boxShadow: solid && !disabled
                  ? [
                      BoxShadow(
                        color: t.green.withValues(alpha: 0.32),
                        blurRadius: 26,
                        offset: const Offset(0, 12),
                      )
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  VyanaIcon(icon!, size: 19, color: fg),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: VyanaType.cta.copyWith(color: fg),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated SVG-style progress ring with centered content.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.max = 100,
    this.size = 64,
    this.stroke = 6,
    required this.color,
    this.track,
    this.child,
  });

  final double value;
  final double max;
  final double size;
  final double stroke;
  final Color color;
  final Color? track;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final pct = (value / max).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOutCubic,
            builder: (_, v, _) => CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(
                pct: v,
                stroke: stroke,
                color: color,
                track: track ?? t.border,
              ),
            ),
          ),
          ?child,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.pct,
    required this.stroke,
    required this.color,
    required this.track,
  });

  final double pct;
  final double stroke;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - stroke) / 2;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * pct,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.pct != pct || old.color != color || old.track != track;
}

/// Sparkline with a soft gradient area fill.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.data,
    required this.color,
    this.width = 100,
    this.height = 34,
  });

  final List<double> data;
  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (data.length < 2) return SizedBox(width: width, height: height);
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _SparkPainter(data, color)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.data, this.color);

  final List<double> data;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = data.reduce(math.max);
    final minV = data.reduce(math.min);
    final rng = (maxV - minV) == 0 ? 1.0 : (maxV - minV);
    Offset pt(int i) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - minV) / rng) * (size.height - 4) - 2;
      return Offset(x, y);
    }

    final line = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < data.length; i++) {
      line.lineTo(pt(i).dx, pt(i).dy);
    }
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(area, areaPaint);

    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.data != data || old.color != color;
}

/// Pill toggle switch.
class VSwitch extends StatelessWidget {
  const VSwitch({super.key, required this.on, this.onTap, this.color});

  final bool on;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final c = color ?? t.green;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 46,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          color: on ? c : (t.isDark ? const Color(0xFF2A3441) : const Color(0xFFD8D0C0)),
        ),
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Color(0x4D000000), blurRadius: 3, offset: Offset(0, 1))],
          ),
        ),
      ),
    );
  }
}

/// In-body app bar: optional leading widget, gold sub-eyebrow + serif title,
/// trailing actions. (Distinct from a Material AppBar — sits in screen bodies.)
class VAppBar extends StatelessWidget {
  const VAppBar({
    super.key,
    required this.title,
    this.sub,
    this.leading,
    this.actions = const [],
  });

  final String title;
  final String? sub;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 14),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 11)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sub != null)
                  Text(sub!.toUpperCase(),
                      style: VyanaType.eyebrow.copyWith(color: t.gold, letterSpacing: 1.5)),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VyanaType.appBarSerif.copyWith(color: t.text)),
              ],
            ),
          ),
          for (final a in actions) ...[const SizedBox(width: 8), a],
        ],
      ),
    );
  }
}

/// Round icon button with optional gold badge dot.
class IconBtn extends StatelessWidget {
  const IconBtn({
    super.key,
    required this.icon,
    this.onTap,
    this.active = false,
    this.badge = false,
    this.size = 40,
  });

  final String icon;
  final VoidCallback? onTap;
  final bool active;
  final bool badge;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.card,
              border: Border.all(color: t.border),
            ),
            child: Center(
              child: VyanaIcon(icon, size: 19, color: active ? t.green : t.textSec),
            ),
          ),
          if (badge)
            Positioned(
              top: 7,
              right: 7,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: t.gold,
                  shape: BoxShape.circle,
                  border: Border.all(color: t.card, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Brand seal — Vyana logo mark used in headers and empty states.
class Seal extends StatelessWidget {
  const Seal({super.key, this.size = 40, this.glow = false});

  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: t.green.withValues(alpha: 0.35),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ]
            : t.shadowSoft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        kVyanaLogoAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

/// Themed gate when a permission or system setting blocks a feature.
class AccessDeniedPanel extends StatelessWidget {
  const AccessDeniedPanel({
    super.key,
    required this.title,
    required this.message,
    this.icon = 'shield',
    this.hint,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.accent,
  });

  final String title;
  final String message;
  final String icon;
  final String? hint;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final c = accent ?? t.vit('hr');
    return Panel(
      pad: 16,
      accent: c,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: t.isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(child: VyanaIcon(icon, size: 21, color: c)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: VyanaType.label.copyWith(color: t.text, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(message,
                        style: VyanaType.bodySm.copyWith(color: t.textSec, height: 1.5)),
                  ],
                ),
              ),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 12),
            Text(hint!,
                style: VyanaType.caption.copyWith(color: t.textMuted, height: 1.45)),
          ],
          if (primaryLabel != null || secondaryLabel != null) ...[
            const SizedBox(height: 14),
            if (primaryLabel != null)
              Cta(label: primaryLabel!, icon: 'settings', onTap: onPrimary),
            if (secondaryLabel != null) ...[
              const SizedBox(height: 10),
              Cta(
                label: secondaryLabel!,
                icon: 'refresh',
                solid: false,
                onTap: onSecondary,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Compact warning chip for devices below the on-device LLM RAM threshold.
class LowRamBadge extends StatelessWidget {
  const LowRamBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.vyana;
    final c = t.vit('hr');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: t.isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: c.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          VyanaIcon('alert', size: 14, color: c),
          const SizedBox(width: 5),
          Text('Low RAM', style: VyanaType.mono10.copyWith(color: c, letterSpacing: 0.4)),
        ],
      ),
    );
  }
}

void showVyanaSnackBar(
  BuildContext context, {
  required String message,
  String? icon,
  bool success = true,
  Duration duration = const Duration(seconds: 4),
  SnackBarAction? action,
}) {
  final t = context.vyana;
  final accent = success ? t.green : t.vit('hr');
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: duration,
        backgroundColor: t.elevated,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accent.withValues(alpha: 0.35)),
        ),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VyanaIcon(icon ?? (success ? 'checkCircle' : 'alert'), size: 18, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: VyanaType.bodySm.copyWith(color: t.text, height: 1.45),
              ),
            ),
          ],
        ),
        action: action,
      ),
    );
}

Future<T?> showVyanaConfirmDialog<T>({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) {
  final t = context.vyana;
  return showDialog<T>(
    context: context,
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Panel(
          pad: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: VyanaType.titleSerif.copyWith(color: t.text)),
              const SizedBox(height: 10),
              Text(message,
                  style: VyanaType.bodySm.copyWith(color: t.textSec, height: 1.5)),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Cta(
                      label: cancelLabel,
                      solid: false,
                      onTap: () => Navigator.of(ctx).pop(false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Cta(
                      label: confirmLabel,
                      icon: destructive ? 'x' : 'check',
                      onTap: () => Navigator.of(ctx).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Confirms before leaving Vyana from a root tab (Android hardware back, etc.).
Future<void> confirmExitVyanaApp(
  BuildContext context, {
  bool sessionRecording = false,
}) async {
  final recordingNote = sessionRecording
      ? 'A practice session is still recording in the background.\n\n'
      : '';
  final confirmed = await showVyanaConfirmDialog<bool>(
    context: context,
    title: 'Exit Vyana?',
    message:
        '${recordingNote}Your ring pairing, journal, and on-device data stay '
        'on this phone.',
    confirmLabel: 'Exit',
    cancelLabel: 'Stay',
    destructive: true,
  );
  if (confirmed == true) {
    SystemNavigator.pop();
  }
}

/// Strips lightweight markdown markers before TTS reads guide replies aloud.
String stripGuideMarkdown(String text) {
  var result = text;
  result = result.replaceAllMapped(
    RegExp(r'\*\*(.+?)\*\*'),
    (match) => match.group(1) ?? '',
  );
  result = result.replaceAllMapped(
    RegExp(r'(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)'),
    (match) => match.group(1) ?? '',
  );
  result = result.replaceAllMapped(
    RegExp(r'^\s*[-*•]\s+', multiLine: true),
    (_) => '',
  );
  result = result.replaceAll('**', '');
  return result.replaceAll(RegExp(r'(?<!\*)\*(?!\*)'), '');
}

/// Renders guide chat text with basic markdown (**bold**, *italic*, bullets).
class GuideFormattedText extends StatelessWidget {
  const GuideFormattedText({
    super.key,
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return Text('', style: style);
    }

    return Text.rich(
      TextSpan(style: style, children: _buildGuideMarkdownSpans(text, style)),
    );
  }
}

List<InlineSpan> _buildGuideMarkdownSpans(String text, TextStyle baseStyle) {
  final boldStyle = baseStyle.copyWith(fontWeight: FontWeight.w700);
  final italicStyle = baseStyle.copyWith(fontStyle: FontStyle.italic);
  final lines = text.split('\n');
  final spans = <InlineSpan>[];

  for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
    if (lineIndex > 0) {
      spans.add(const TextSpan(text: '\n'));
    }

    final line = lines[lineIndex];
    final bullet = RegExp(r'^(\s*)([-*•]|\d+\.)\s+(.*)$').firstMatch(line);
    if (bullet != null) {
      final marker = bullet.group(2)!;
      final body = bullet.group(3)!;
      final prefix = RegExp(r'^\d+\.$').hasMatch(marker) ? '$marker ' : '• ';
      spans.add(TextSpan(text: prefix, style: baseStyle));
      spans.addAll(_parseGuideInlineMarkdown(body, baseStyle, boldStyle, italicStyle));
      continue;
    }

    spans.addAll(_parseGuideInlineMarkdown(line, baseStyle, boldStyle, italicStyle));
  }

  return spans;
}

List<InlineSpan> _parseGuideInlineMarkdown(
  String line,
  TextStyle baseStyle,
  TextStyle boldStyle,
  TextStyle italicStyle,
) {
  final spans = <InlineSpan>[];
  final plain = StringBuffer();
  var index = 0;

  void flushPlain() {
    if (plain.isEmpty) {
      return;
    }
    spans.add(TextSpan(text: plain.toString(), style: baseStyle));
    plain.clear();
  }

  while (index < line.length) {
    if (line.startsWith('**', index)) {
      final close = line.indexOf('**', index + 2);
      if (close != -1) {
        flushPlain();
        spans.add(
          TextSpan(
            text: line.substring(index + 2, close),
            style: boldStyle,
          ),
        );
        index = close + 2;
        continue;
      }
    }

    if (line[index] == '*' && !_isAdjacentMarkdownStar(line, index)) {
      final close = _findClosingItalicStar(line, index + 1);
      if (close != -1) {
        flushPlain();
        spans.add(
          TextSpan(
            text: line.substring(index + 1, close),
            style: italicStyle,
          ),
        );
        index = close + 1;
        continue;
      }
    }

    plain.write(line[index]);
    index++;
  }

  flushPlain();
  if (spans.isEmpty) {
    spans.add(TextSpan(text: '', style: baseStyle));
  }
  return spans;
}

bool _isAdjacentMarkdownStar(String line, int index) {
  final hasLeading = index > 0 && line[index - 1] == '*';
  final hasTrailing = index + 1 < line.length && line[index + 1] == '*';
  return hasLeading || hasTrailing;
}

int _findClosingItalicStar(String line, int start) {
  for (var i = start; i < line.length; i++) {
    if (line[i] == '*' && !_isAdjacentMarkdownStar(line, i)) {
      return i;
    }
  }
  return -1;
}

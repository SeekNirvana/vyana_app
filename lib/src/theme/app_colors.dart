import 'package:flutter/material.dart';

/// Vyana × SeekNirvana design tokens, ported verbatim from the design handoff's
/// `theme.js`. Theme-variant surface/text/border tokens live on the
/// [VyanaColors] `ThemeExtension`; brand, per-vital and HR-zone hues are
/// theme-invariant and exposed as getters / statics.
///
/// Access in widgets via `context.vyana` (see [VyanaColorsX]).
@immutable
class VyanaColors extends ThemeExtension<VyanaColors> {
  const VyanaColors({
    required this.isDark,
    required this.bg,
    required this.bgGradTop,
    required this.bgGradMid,
    required this.bgGradBottom,
    required this.surface,
    required this.card,
    required this.cardGradTop,
    required this.cardGradBottom,
    required this.elevated,
    required this.border,
    required this.borderSoft,
    required this.text,
    required this.textSec,
    required this.textMuted,
    required this.shadowColor,
    required this.shadowSoftColor,
  });

  final bool isDark;
  final Color bg;
  final Color bgGradTop;
  final Color bgGradMid;
  final Color bgGradBottom;
  final Color surface;
  final Color card;
  final Color cardGradTop;
  final Color cardGradBottom;
  final Color elevated;
  final Color border;
  final Color borderSoft;
  final Color text;
  final Color textSec;
  final Color textMuted;
  final Color shadowColor;
  final Color shadowSoftColor;

  // ── Brand (theme-invariant) ───────────────────────────────────────────────
  Color get green => const Color(0xFF00A86B);
  Color get greenLight => const Color(0xFF2DCC90);
  Color get greenDark => const Color(0xFF007E50);
  Color get gold => const Color(0xFFC9A227);
  Color get goldLight => const Color(0xFFE0BF56);
  Color get goldDark => const Color(0xFF9C7A16);
  Color get cyan => const Color(0xFF00D4FF);

  // ── Derived gradients & shadows ───────────────────────────────────────────
  LinearGradient get bgGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [bgGradTop, bgGradMid, bgGradBottom],
        stops: const [0.0, 0.55, 1.0],
      );

  LinearGradient get cardGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [cardGradTop, cardGradBottom],
      );

  LinearGradient get ctaGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [green, greenDark],
      );

  List<BoxShadow> get shadowSoft => [
        BoxShadow(
          color: shadowSoftColor,
          blurRadius: isDark ? 28 : 26,
          offset: const Offset(0, 10),
        ),
      ];

  List<BoxShadow> get shadow => [
        BoxShadow(
          color: shadowColor,
          blurRadius: 40,
          offset: const Offset(0, 18),
        ),
      ];

  /// Per-vital accent hue keyed by the string ids used in the content catalog
  /// (e.g. `hr`, `spo2`, `readiness`, `luna`). Falls back to brand green.
  Color vit(String key) => _vit[key] ?? green;

  /// HR training zones Z1–Z5.
  List<Color> get hrZones => const [
        Color(0xFF5AA37A), // Z1
        Color(0xFF32C5D2), // Z2
        Color(0xFFC9A227), // Z3
        Color(0xFFE08A4B), // Z4
        Color(0xFFE85D75), // Z5
      ];

  static const Map<String, Color> _vit = {
    'hr': Color(0xFFE85D75),
    'spo2': Color(0xFF32C5D2),
    'hrv': Color(0xFF5AA37A),
    'stress': Color(0xFFC66B37),
    'temp': Color(0xFFF39C5A),
    'steps': Color(0xFF00A86B),
    'sleep': Color(0xFF4E5CA8),
    'bp': Color(0xFFC9A227),
    'glucose': Color(0xFFEE7D52),
    'ecg': Color(0xFF00D4FF),
    'readiness': Color(0xFF2DCC90),
    'cal': Color(0xFFD87C43),
    'sleepDeep': Color(0xFF245C7A),
    'sleepLight': Color(0xFF4B7AA3),
    'sleepREM': Color(0xFF8361B5),
    'sleepAwake': Color(0xFFC88A4B),
    'luna': Color(0xFF4E5CA8),
    'nova': Color(0xFF5AA37A),
  };

  static const VyanaColors dark = VyanaColors(
    isDark: true,
    bg: Color(0xFF0A0A0F),
    bgGradTop: Color(0xFF0A0A0F),
    bgGradMid: Color(0xFF0D1117),
    bgGradBottom: Color(0xFF101723),
    surface: Color(0xFF11141A),
    card: Color(0xFF151A22),
    cardGradTop: Color(0xFF151A22),
    cardGradBottom: Color(0xFF1C222C),
    elevated: Color(0xFF1C222C),
    border: Color(0xFF233041),
    borderSoft: Color(0x99233041), // rgba(35,48,65,0.6)
    text: Color(0xFFF6F3EE),
    textSec: Color(0xFF98A2B3),
    textMuted: Color(0xFF667085),
    shadowColor: Color(0x73000000), // rgba(0,0,0,0.45)
    shadowSoftColor: Color(0x52000000), // rgba(0,0,0,0.32)
  );

  static const VyanaColors light = VyanaColors(
    isDark: false,
    bg: Color(0xFFF6F2E8),
    bgGradTop: Color(0xFFF8F4EC),
    bgGradMid: Color(0xFFF5EFE4),
    bgGradBottom: Color(0xFFF2ECE0),
    surface: Color(0xFFFFFCF7),
    card: Color(0xFFFFFCF7),
    cardGradTop: Color(0xFFFFFCF7),
    cardGradBottom: Color(0xFFF2EBDD),
    elevated: Color(0xFFF2EBDD),
    border: Color(0xFFE7DDCB),
    borderSoft: Color(0xFFECE3D3),
    text: Color(0xFF171B20),
    textSec: Color(0xFF5F6B7A),
    textMuted: Color(0xFF7A8593),
    shadowColor: Color(0x1A281E0A), // rgba(40,30,10,0.10)
    shadowSoftColor: Color(0x12281E0A), // rgba(40,30,10,0.07)
  );

  @override
  VyanaColors copyWith({
    bool? isDark,
    Color? bg,
    Color? bgGradTop,
    Color? bgGradMid,
    Color? bgGradBottom,
    Color? surface,
    Color? card,
    Color? cardGradTop,
    Color? cardGradBottom,
    Color? elevated,
    Color? border,
    Color? borderSoft,
    Color? text,
    Color? textSec,
    Color? textMuted,
    Color? shadowColor,
    Color? shadowSoftColor,
  }) {
    return VyanaColors(
      isDark: isDark ?? this.isDark,
      bg: bg ?? this.bg,
      bgGradTop: bgGradTop ?? this.bgGradTop,
      bgGradMid: bgGradMid ?? this.bgGradMid,
      bgGradBottom: bgGradBottom ?? this.bgGradBottom,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      cardGradTop: cardGradTop ?? this.cardGradTop,
      cardGradBottom: cardGradBottom ?? this.cardGradBottom,
      elevated: elevated ?? this.elevated,
      border: border ?? this.border,
      borderSoft: borderSoft ?? this.borderSoft,
      text: text ?? this.text,
      textSec: textSec ?? this.textSec,
      textMuted: textMuted ?? this.textMuted,
      shadowColor: shadowColor ?? this.shadowColor,
      shadowSoftColor: shadowSoftColor ?? this.shadowSoftColor,
    );
  }

  @override
  VyanaColors lerp(ThemeExtension<VyanaColors>? other, double t) {
    if (other is! VyanaColors) return this;
    return VyanaColors(
      isDark: t < 0.5 ? isDark : other.isDark,
      bg: Color.lerp(bg, other.bg, t)!,
      bgGradTop: Color.lerp(bgGradTop, other.bgGradTop, t)!,
      bgGradMid: Color.lerp(bgGradMid, other.bgGradMid, t)!,
      bgGradBottom: Color.lerp(bgGradBottom, other.bgGradBottom, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardGradTop: Color.lerp(cardGradTop, other.cardGradTop, t)!,
      cardGradBottom: Color.lerp(cardGradBottom, other.cardGradBottom, t)!,
      elevated: Color.lerp(elevated, other.elevated, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderSoft: Color.lerp(borderSoft, other.borderSoft, t)!,
      text: Color.lerp(text, other.text, t)!,
      textSec: Color.lerp(textSec, other.textSec, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      shadowSoftColor: Color.lerp(shadowSoftColor, other.shadowSoftColor, t)!,
    );
  }
}

/// Convenience accessor: `context.vyana.card`, `context.vyana.green`, …
extension VyanaColorsX on BuildContext {
  VyanaColors get vyana =>
      Theme.of(this).extension<VyanaColors>() ?? VyanaColors.dark;
}

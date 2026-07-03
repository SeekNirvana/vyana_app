import 'package:flutter/material.dart';

/// Vyana × SeekNirvana design tokens — the handoff palette retuned for calm:
/// sage-tinted neutrals and de-saturated vital hues so no reading ever shouts.
/// Theme-variant surface/text/border tokens live on the
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
        Color(0xFF54B8C2), // Z2
        Color(0xFFC9A227), // Z3
        Color(0xFFDC9A6A), // Z4
        Color(0xFFD97A8C), // Z5
      ];

  static const Map<String, Color> _vit = {
    'hr': Color(0xFFD97A8C),
    'spo2': Color(0xFF5BB8C4),
    'hrv': Color(0xFF5AA37A),
    'stress': Color(0xFFC98B62),
    'temp': Color(0xFFE0A878),
    'steps': Color(0xFF00A86B),
    'sleep': Color(0xFF6E7BBF),
    'bp': Color(0xFFC9A227),
    'glucose': Color(0xFFDD9270),
    'ecg': Color(0xFF63C3D8),
    'readiness': Color(0xFF4CBD92),
    'cal': Color(0xFFD69A6E),
    'sleepDeep': Color(0xFF33657B),
    'sleepLight': Color(0xFF5C84A8),
    'sleepREM': Color(0xFF8F73BD),
    'sleepAwake': Color(0xFFC79A66),
    'luna': Color(0xFF6E7BBF),
    'nova': Color(0xFF5AA37A),
  };

  // Dark: deep forest twilight — green-tinted charcoal instead of cold
  // blue-black, with softer text contrast and gentler shadows.
  static const VyanaColors dark = VyanaColors(
    isDark: true,
    bg: Color(0xFF0B100F),
    bgGradTop: Color(0xFF0B100F),
    bgGradMid: Color(0xFF0E1414),
    bgGradBottom: Color(0xFF111B18),
    surface: Color(0xFF121817),
    card: Color(0xFF161D1C),
    cardGradTop: Color(0xFF161D1C),
    cardGradBottom: Color(0xFF1C2523),
    elevated: Color(0xFF1C2523),
    border: Color(0xFF263430),
    borderSoft: Color(0x99263430), // rgba(38,52,48,0.6)
    text: Color(0xFFF1F0E9),
    textSec: Color(0xFF9CA9A1),
    textMuted: Color(0xFF6B7871),
    shadowColor: Color(0x66000000), // rgba(0,0,0,0.40)
    shadowSoftColor: Color(0x47000000), // rgba(0,0,0,0.28)
  );

  // Light: misty sage-sand — a touch of green in the warm paper tones.
  static const VyanaColors light = VyanaColors(
    isDark: false,
    bg: Color(0xFFF4F3EA),
    bgGradTop: Color(0xFFF7F5ED),
    bgGradMid: Color(0xFFF2F1E6),
    bgGradBottom: Color(0xFFECEFE0),
    surface: Color(0xFFFDFCF5),
    card: Color(0xFFFDFCF5),
    cardGradTop: Color(0xFFFDFCF5),
    cardGradBottom: Color(0xFFEFF0E2),
    elevated: Color(0xFFEFF0E2),
    border: Color(0xFFE0E3CF),
    borderSoft: Color(0xFFE8EADB),
    text: Color(0xFF1B201D),
    textSec: Color(0xFF5E6E66),
    textMuted: Color(0xFF7D8A82),
    shadowColor: Color(0x141E2814), // rgba(30,40,20,0.08)
    shadowSoftColor: Color(0x0F1E2814), // rgba(30,40,20,0.06)
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

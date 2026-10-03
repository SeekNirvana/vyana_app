import 'package:flutter/material.dart';

/// Vyana × SeekNirvana design tokens — a clean wearable palette with fresh
/// emerald, luminous data accents, and warm premium neutrals.
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
  Color get green => const Color(0xFF20AD78);
  Color get greenLight => const Color(0xFF55C99A);
  Color get greenDark => const Color(0xFF087A55);
  Color get gold => const Color(0xFFE3A448);
  Color get goldLight => const Color(0xFFF2C676);
  Color get goldDark => const Color(0xFFAA6A1E);
  Color get cyan => const Color(0xFF5D9FE8);

  // ── 2.0 colour channels (theme-invariant) ─────────────────────────────────
  // Three channels, never mixed; anything not in one of them is grey.
  //
  // A · Quality — "how is it?" Applied only to the readiness score and arc,
  // Home's card verdicts, and Metrics' deltas. Nothing else may use these.
  Color get qGood => const Color(0xFF20AD78);
  Color get qGoodSoft => const Color(0xFF55C99A);
  /// Middle band ("fair"): a yellow amber, deliberately yellower than the
  /// orange-gold Perform intent so the two never read as one colour. Grey was
  /// the design's choice here but on a phone it reads as "not connected".
  Color get qLevel => const Color(0xFFD4B647);
  Color get qLevelSoft => const Color(0xFFE6CC6B);
  Color get qPoor => const Color(0xFFE16E80);
  Color get qPoorSoft => const Color(0xFFEC8090);

  // B · Identity — "which thing is it?" Icons only, and only the four KEY
  // METRICS; every OTHER VITALS icon is bright grey on a lighter tile.
  Color get idHrv => const Color(0xFF4FB8C9);
  Color get idSleep => const Color(0xFF8E8FD8);
  Color get idRestHr => const Color(0xFFE08FA8);
  Color get idStress => const Color(0xFFC48FD8);
  Color get idOther => isDark ? const Color(0xFFC3D0CA) : const Color(0xFF65717A);

  /// §14b cycle mauve — cycle marks and the Period started glyph only. Kept
  /// clear of quality rose and Resting HR's pink so it never reads as a
  /// verdict about the body.
  Color get idCycle => const Color(0xFFC58BB0);

  /// Journal kinds — type eyebrow only. Dream shares sleep's violet on purpose.
  Color get jDream => const Color(0xFF8E8FD8);
  Color get jReflection => const Color(0xFF6789A8);
  Color get jIdea => const Color(0xFFB4914C);
  Color get jMeal => const Color(0xFF7E9B5E);

  /// Pinned practices take a hue per pin slot, never per activity type.
  List<Color> get pinPalette => const [
        Color(0xFF6789A8),
        Color(0xFF7BA05B),
        Color(0xFFB4914C),
        Color(0xFFB76AA5),
        Color(0xFFD2735A),
      ];

  // C · Intent — "what did I choose?" Selected chip + suggested practice tile
  // and play button. Must never recolour the score, the arc, or a metric card.
  Color get intentRecover => const Color(0xFF6E7BBF);
  Color get intentRecoverSoft => const Color(0xFF9DA8DB);
  Color get intentPerform => const Color(0xFFE3A448);
  Color get intentPerformSoft => const Color(0xFFF2C676);
  Color get intentSettle => const Color(0xFF00D4FF);
  Color get intentSettleSoft => const Color(0xFF66E4FF);

  /// Neutral section heading — a coloured heading would read as a verdict.
  Color get heading => isDark ? const Color(0xFFC3D0CA) : const Color(0xFF3C4C47);

  /// Quiet mono eyebrow / caption grey.
  Color get mutedInk => isDark ? const Color(0xFF8FA39B) : const Color(0xFF7A8A84);

  /// Hairline card border used by the 2.0 metric/entry cards.
  Color get hairline =>
      isDark ? const Color(0xCC24433A) : const Color(0xFFE8E0D8);

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
    'hr': Color(0xFFE16E80),
    'spo2': Color(0xFF45AFC2),
    'hrv': Color(0xFF20AD78),
    'stress': Color(0xFFE18B58),
    'temp': Color(0xFFF09B66),
    'steps': Color(0xFF20AD78),
    'sleep': Color(0xFF668BE3),
    'bp': Color(0xFFE3A448),
    'glucose': Color(0xFFE98562),
    'ecg': Color(0xFF42B5CF),
    'readiness': Color(0xFF31B883),
    'cal': Color(0xFFE99162),
    'sleepDeep': Color(0xFF33657B),
    'sleepLight': Color(0xFF5C84A8),
    'sleepREM': Color(0xFF8F73BD),
    'sleepAwake': Color(0xFFC79A66),
    'luna': Color(0xFF6E7BBF),
    'nova': Color(0xFF5AA37A),
  };

  // Dark: crisp blue-black with fresh emerald depth.
  static const VyanaColors dark = VyanaColors(
    isDark: true,
    bg: Color(0xFF071211),
    bgGradTop: Color(0xFF071211),
    bgGradMid: Color(0xFF091817),
    bgGradBottom: Color(0xFF0C211D),
    surface: Color(0xFF0D1A18),
    card: Color(0xFF10201D),
    cardGradTop: Color(0xFF10201D),
    cardGradBottom: Color(0xFF142A25),
    elevated: Color(0xFF17302A),
    border: Color(0xFF24433A),
    borderSoft: Color(0x9924433A),
    text: Color(0xFFF6F7F3),
    textSec: Color(0xFFA8B8B2),
    textMuted: Color(0xFF71847D),
    shadowColor: Color(0x66000000), // rgba(0,0,0,0.40)
    shadowSoftColor: Color(0x47000000), // rgba(0,0,0,0.28)
  );

  // Light: luminous warm ivory with porcelain surfaces and crisp type.
  static const VyanaColors light = VyanaColors(
    isDark: false,
    bg: Color(0xFFF8F5F0),
    bgGradTop: Color(0xFFFFFCF8),
    bgGradMid: Color(0xFFF8F4EF),
    bgGradBottom: Color(0xFFF1F7F3),
    surface: Color(0xFFFFFCF8),
    card: Color(0xFFFFFFFF),
    cardGradTop: Color(0xFFFFFFFF),
    cardGradBottom: Color(0xFFFFF8F2),
    elevated: Color(0xFFF2EDE7),
    border: Color(0xFFE8E0D8),
    borderSoft: Color(0xFFF0E9E2),
    text: Color(0xFF172128),
    textSec: Color(0xFF65717A),
    textMuted: Color(0xFF8C969C),
    shadowColor: Color(0x1FD29A74),
    shadowSoftColor: Color(0x14C68B65),
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

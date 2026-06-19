import 'package:flutter/material.dart';

/// Type system from the handoff: Cormorant Garamond (serif headings/numerals),
/// Manrope (sans UI), Space Mono (mono labels).
///
/// Styles are colorless — callers apply color from [VyanaColors] via `copyWith`,
/// or inherit the default text color from the active theme.
class VyanaType {
  VyanaType._();

  static const String serif = 'Cormorant Garamond';
  static const String sans = 'Manrope';
  static const String mono = 'Space Mono';

  /// Gold uppercase eyebrow above section titles. Apply `.toUpperCase()` to text.
  static const TextStyle eyebrow = TextStyle(
    fontFamily: sans,
    fontWeight: FontWeight.w600,
    fontSize: 11,
    letterSpacing: 1.9, // ~0.18em of 11px
    height: 1.0,
  );

  /// Large serif numerals/hero figures (readiness score, big clocks).
  static const TextStyle displaySerif = TextStyle(
    fontFamily: serif,
    fontWeight: FontWeight.w600,
    fontSize: 34,
    height: 1.02,
  );

  /// Serif section title.
  static const TextStyle titleSerif = TextStyle(
    fontFamily: serif,
    fontWeight: FontWeight.w600,
    fontSize: 23,
    height: 1.05,
    letterSpacing: 0.2,
  );

  /// Serif app-bar title.
  static const TextStyle appBarSerif = TextStyle(
    fontFamily: serif,
    fontWeight: FontWeight.w600,
    fontSize: 22,
    height: 1.15,
  );

  static const TextStyle bodyLg = TextStyle(
    fontFamily: sans,
    fontWeight: FontWeight.w500,
    fontSize: 15.5,
    height: 1.35,
  );

  static const TextStyle body = TextStyle(
    fontFamily: sans,
    fontWeight: FontWeight.w500,
    fontSize: 14,
    height: 1.4,
  );

  static const TextStyle bodySm = TextStyle(
    fontFamily: sans,
    fontWeight: FontWeight.w500,
    fontSize: 13,
    height: 1.4,
  );

  /// Emphasised sans label (pills, buttons, tab labels).
  static const TextStyle label = TextStyle(
    fontFamily: sans,
    fontWeight: FontWeight.w600,
    fontSize: 13,
    height: 1.2,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: sans,
    fontWeight: FontWeight.w500,
    fontSize: 12,
    height: 1.3,
  );

  /// Primary CTA label.
  static const TextStyle cta = TextStyle(
    fontFamily: sans,
    fontWeight: FontWeight.w600,
    fontSize: 15.5,
    height: 1.1,
  );

  /// Mono micro-label (metrics, units, codes).
  static const TextStyle mono10 = TextStyle(
    fontFamily: mono,
    fontWeight: FontWeight.w400,
    fontSize: 10,
    letterSpacing: 0.4,
    height: 1.2,
  );

  static const TextStyle mono12 = TextStyle(
    fontFamily: mono,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    letterSpacing: 0.4,
    height: 1.2,
  );

  /// Builds a Material [TextTheme] so framework widgets pick up Manrope by
  /// default; bespoke serif/mono usage is applied per-widget.
  static TextTheme textTheme(Color text) {
    final base = ThemeData(brightness: Brightness.dark).textTheme;
    return base
        .apply(fontFamily: sans, bodyColor: text, displayColor: text)
        .copyWith(
          displayLarge: displaySerif.copyWith(color: text),
          headlineSmall: titleSerif.copyWith(color: text),
          titleLarge: appBarSerif.copyWith(color: text),
          bodyLarge: bodyLg.copyWith(color: text),
          bodyMedium: body.copyWith(color: text),
          bodySmall: bodySm.copyWith(color: text),
          labelLarge: label.copyWith(color: text),
        );
  }
}

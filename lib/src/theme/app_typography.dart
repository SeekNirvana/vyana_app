import 'package:flutter/material.dart';

/// Calm, readable product typography. Manrope is the default for navigation,
/// headings, body copy, and health data. Cormorant Garamond is reserved for
/// intentionally reflective/editorial moments; Space Mono is for technical IDs.
///
/// Styles are colorless — callers apply color from [VyanaColors] via `copyWith`,
/// or inherit the default text color from the active theme.
class VyanaType {
  VyanaType._();

  static const String serif = 'Cormorant Garamond';
  static const String sans = 'Manrope';
  static const String mono = 'Space Mono';

  /// Quiet section label. Sentence case is preferred.
  static const TextStyle eyebrow = TextStyle(
    fontFamily: sans,
    fontWeight: FontWeight.w600,
    fontSize: 11,
    letterSpacing: 0.8,
    height: 1.2,
  );

  /// Large health metrics and hero figures.
  static const TextStyle displaySerif = TextStyle(
    fontFamily: sans,
    fontWeight: FontWeight.w600,
    fontSize: 34,
    height: 1.08,
    letterSpacing: -0.6,
  );

  /// Product section title. Kept under the existing name to avoid churn.
  static const TextStyle titleSerif = TextStyle(
    fontFamily: sans,
    fontWeight: FontWeight.w600,
    fontSize: 23,
    height: 1.18,
    letterSpacing: -0.2,
  );

  /// Product app-bar title. Kept under the existing name to avoid churn.
  static const TextStyle appBarSerif = TextStyle(
    fontFamily: sans,
    fontWeight: FontWeight.w600,
    fontSize: 22,
    height: 1.2,
    letterSpacing: -0.2,
  );

  /// Explicit opt-in for quotes, reflections, and other editorial copy.
  static const TextStyle editorialSerif = TextStyle(
    fontFamily: serif,
    fontWeight: FontWeight.w600,
    fontSize: 23,
    height: 1.15,
  );

  static const TextStyle bodyLg = TextStyle(
    fontFamily: sans,
    fontWeight: FontWeight.w500,
    fontSize: 16,
    height: 1.45,
  );

  static const TextStyle body = TextStyle(
    fontFamily: sans,
    fontWeight: FontWeight.w500,
    fontSize: 15,
    height: 1.45,
  );

  static const TextStyle bodySm = TextStyle(
    fontFamily: sans,
    fontWeight: FontWeight.w500,
    fontSize: 14,
    height: 1.45,
  );

  /// Emphasised sans label (pills, buttons, tab labels).
  static const TextStyle label = TextStyle(
    fontFamily: sans,
    fontWeight: FontWeight.w600,
    fontSize: 13.5,
    height: 1.2,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: sans,
    fontWeight: FontWeight.w500,
    fontSize: 12.5,
    height: 1.4,
  );

  /// Primary CTA label.
  static const TextStyle cta = TextStyle(
    fontFamily: sans,
    fontWeight: FontWeight.w600,
    fontSize: 15.5,
    height: 1.1,
  );

  /// Mono micro-label for technical identifiers and codes only.
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

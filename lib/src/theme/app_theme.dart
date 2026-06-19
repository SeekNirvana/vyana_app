import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Assembles [ThemeData] for the dark (default) and light variants, wiring the
/// [VyanaColors] extension, the Vyana type system, and component defaults that
/// match the handoff (rounded cards, pill buttons, ≥44px hit targets).
class VyanaTheme {
  VyanaTheme._();

  static ThemeData dark() => _build(VyanaColors.dark);
  static ThemeData light() => _build(VyanaColors.light);

  static ThemeData _build(VyanaColors c) {
    final brightness = c.isDark ? Brightness.dark : Brightness.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: c.green,
      brightness: brightness,
    ).copyWith(
      surface: c.card,
      onSurface: c.text,
      primary: c.green,
      secondary: c.gold,
      outline: c.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      colorScheme: scheme,
      textTheme: VyanaType.textTheme(c.text),
      fontFamily: VyanaType.sans,
      extensions: <ThemeExtension<dynamic>>[c],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: c.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: VyanaType.appBarSerif.copyWith(color: c.text),
      ),
      cardTheme: CardThemeData(
        color: c.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: c.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.green,
          foregroundColor: Colors.white,
          minimumSize: const Size(44, 48),
          textStyle: VyanaType.cta,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text,
          minimumSize: const Size(44, 48),
          side: BorderSide(color: c.border, width: 1.5),
          textStyle: VyanaType.cta,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.green,
          textStyle: VyanaType.label,
          minimumSize: const Size(44, 44),
        ),
      ),
      iconTheme: IconThemeData(color: c.textSec),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.elevated,
        contentTextStyle: VyanaType.bodySm.copyWith(color: c.text),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

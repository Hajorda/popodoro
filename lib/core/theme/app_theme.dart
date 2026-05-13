import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_tokens.dart';
import 'app_typography.dart';

class AppTheme {
  static ThemeData light() => _build(AppTokens.light, Brightness.light);
  static ThemeData dark() => _build(AppTokens.dark, Brightness.dark);

  static ThemeData _build(AppTokens t, Brightness brightness) {
    final base = ThemeData(brightness: brightness);

    // Set Manrope as the default font for all Material text styles
    final textTheme = base.textTheme.apply(
      fontFamily: AppFonts.ui,
      bodyColor: t.ink,
      displayColor: t.ink,
    );

    return base.copyWith(
      brightness: brightness,
      scaffoldBackgroundColor: t.bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: t.pop,
        onPrimary: t.ink,
        secondary: t.ember,
        onSecondary: t.ink,
        error: t.ember,
        onError: Colors.white,
        surface: t.surface,
        onSurface: t.ink,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: t.bg,
        foregroundColor: t.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
    );
  }
}

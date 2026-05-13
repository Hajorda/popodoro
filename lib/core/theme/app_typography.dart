import 'package:flutter/material.dart';

// Font families are bundled in assets/fonts/ and declared in pubspec.yaml.
// Using them directly avoids any network fetch at startup.
class AppFonts {
  static const display = 'InstrumentSerif';  // timer, editorial headings
  static const ui = 'Manrope';               // body, buttons, labels
  static const mono = 'JetBrainsMono';       // session counters, data labels
}

class AppTypography {
  // ── Display / Serif ────────────────────────────────────────────────────────

  static TextStyle display(Color color, {
    double fontSize = 22,
    FontStyle fontStyle = FontStyle.normal,
    double? letterSpacing,
    double? height,
  }) => TextStyle(
    fontFamily: AppFonts.display,
    fontSize: fontSize,
    color: color,
    fontStyle: fontStyle,
    letterSpacing: letterSpacing ?? -0.01 * fontSize,
    height: height ?? 1.1,
  );

  // ── UI / Manrope ───────────────────────────────────────────────────────────

  static TextStyle ui(Color color, {
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w400,
    double? letterSpacing,
    double height = 1.5,
  }) => TextStyle(
    fontFamily: AppFonts.ui,
    fontSize: fontSize,
    color: color,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    height: height,
  );

  // ── Mono / JetBrains ───────────────────────────────────────────────────────

  static TextStyle mono(Color color, {
    double fontSize = 11,
    double letterSpacing = 0.14,
    FontWeight fontWeight = FontWeight.w400,
  }) => TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: fontSize,
    color: color,
    letterSpacing: letterSpacing,
    fontWeight: fontWeight,
    height: 1.4,
  );

  // ── Named scale ────────────────────────────────────────────────────────────

  static TextStyle timerHero(Color color) =>
      display(color, fontSize: 88, letterSpacing: -2, height: 1.0);

  static TextStyle timerMobile(Color color) =>
      display(color, fontSize: 72, letterSpacing: -1.5, height: 1.0);

  static TextStyle tagline(Color color) =>
      display(color, fontSize: 18, fontStyle: FontStyle.italic);

  static TextStyle heading1(Color color) =>
      ui(color, fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5);

  static TextStyle heading2(Color color) => display(color, fontSize: 22);

  static TextStyle body(Color color) => ui(color, fontSize: 15);
  static TextStyle bodySmall(Color color) => ui(color, fontSize: 13);

  static TextStyle label(Color color) => mono(color, fontSize: 10);
  static TextStyle labelMd(Color color) => mono(color, fontSize: 12, letterSpacing: 0.08);
  static TextStyle labelLg(Color color) => mono(color, fontSize: 14, letterSpacing: 0);
}

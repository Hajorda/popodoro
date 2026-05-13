import 'package:flutter/material.dart';

// Design tokens from the Popodoro design system.
// All values sourced from the Claude Design handoff.
class AppTokens {
  const AppTokens._({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.border,
    required this.dim,
    required this.pop,
    required this.popDeep,
    required this.ember,
    required this.sage,
    required this.lavender,
    required this.bump,
    required this.bumpEdge,
  });

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color border;
  final Color dim;

  // Brand & semantic
  final Color pop;      // butter-yellow, primary / focus
  final Color popDeep;  // pressed state
  final Color ember;    // energy / activity
  final Color sage;     // rest / success
  final Color lavender; // long break
  final Color bump;     // mascot tuft fill
  final Color bumpEdge; // mascot tuft edge

  static AppTokens of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  static const light = AppTokens._(
    bg: Color(0xFFFBF8F2),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF3EEE5),
    ink: Color(0xFF1C1A17),
    ink2: Color(0xFF5C544B),
    ink3: Color(0xFF8E867C),
    border: Color(0xFFE8E1D4),
    dim: Color(0xFFF7F1E5),
    pop: Color(0xFFFFC857),
    popDeep: Color(0xFFE8A93A),
    ember: Color(0xFFF26B4F),
    sage: Color(0xFF7BB893),
    lavender: Color(0xFF9A8FE8),
    bump: Color(0xFFFFF6E1),
    bumpEdge: Color(0xFFF2E6C6),
  );

  static const dark = AppTokens._(
    bg: Color(0xFF14120F),
    surface: Color(0xFF1E1B16),
    surface2: Color(0xFF29251E),
    ink: Color(0xFFF5F0E6),
    ink2: Color(0xFFB3A99A),
    ink3: Color(0xFF7C7368),
    border: Color(0xFF2E2A23),
    dim: Color(0xFF22201B),
    pop: Color(0xFFFFC857),
    popDeep: Color(0xFFFFD371),
    ember: Color(0xFFF58A72),
    sage: Color(0xFF94CCAB),
    lavender: Color(0xFFB5ABF0),
    bump: Color(0xFF3A3528),
    bumpEdge: Color(0xFF4A4233),
  );
}

// Spacing scale (multiples of 4)
class AppSpacing {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s12 = 48;
  static const double s16 = 64;
  static const double s24 = 96;
}

// Radius scale
class AppRadius {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 24;
  static const double full = 999;
}

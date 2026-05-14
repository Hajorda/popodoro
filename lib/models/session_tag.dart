import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

enum SessionTag {
  work,
  study,
  creative,
  learning,
  meeting;

  String get label => switch (this) {
    SessionTag.work => 'work',
    SessionTag.study => 'study',
    SessionTag.creative => 'creative',
    SessionTag.learning => 'learning',
    SessionTag.meeting => 'meeting',
  };

  String get emoji => switch (this) {
    SessionTag.work => '💼',
    SessionTag.study => '📚',
    SessionTag.creative => '✨',
    SessionTag.learning => '🌱',
    SessionTag.meeting => '💬',
  };

  Color colorFor(AppTokens t) => switch (this) {
    SessionTag.work => t.ember,
    SessionTag.study => t.lavender,
    SessionTag.creative => t.pop,
    SessionTag.learning => t.sage,
    SessionTag.meeting => t.ink2,
  };

  static SessionTag? fromString(String? s) {
    if (s == null || s.isEmpty) return null;
    for (final tag in SessionTag.values) {
      if (tag.label == s) return tag;
    }
    return null;
  }
}

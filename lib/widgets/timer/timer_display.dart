import 'package:flutter/material.dart';

import '../../models/pomodoro_state.dart';
import 'timer_dots.dart';
import 'timer_kernel.dart';
import 'timer_numerals.dart';
import 'timer_ring.dart';

// Routes to the correct timer widget based on the user's chosen appearance.
class TimerDisplay extends StatelessWidget {
  const TimerDisplay({
    super.key,
    required this.appearance,
    required this.progress,
    required this.timeDisplay,
    required this.sessionLabel,
    this.taskName,
    required this.ringColor,
    required this.trackColor,
    required this.inkColor,
    required this.ink2Color,
    required this.ink3Color,
    required this.surfaceColor,
    required this.borderColor,
    required this.bumpColor,
    required this.bumpEdgeColor,
    // Ring-specific sizing
    required this.size,
    required this.strokeWidth,
  });

  final TimerAppearance appearance;
  final double progress;
  final String timeDisplay;
  final String sessionLabel;
  final String? taskName;
  final Color ringColor;
  final Color trackColor;
  final Color inkColor;
  final Color ink2Color;
  final Color ink3Color;
  final Color surfaceColor;
  final Color borderColor;
  final Color bumpColor;
  final Color bumpEdgeColor;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    switch (appearance) {
      case TimerAppearance.ring:
        return TimerRing(
          progress: progress,
          timeDisplay: timeDisplay,
          sessionLabel: sessionLabel,
          taskName: taskName,
          ringColor: ringColor,
          trackColor: trackColor,
          inkColor: inkColor,
          ink2Color: ink2Color,
          ink3Color: ink3Color,
          size: size,
          strokeWidth: strokeWidth,
        );

      case TimerAppearance.dots:
        return TimerDots(
          progress: progress,
          timeDisplay: timeDisplay,
          sessionLabel: sessionLabel,
          taskName: taskName,
          activeColor: ringColor,
          trackColor: trackColor,
          inkColor: inkColor,
          ink2Color: ink2Color,
          ink3Color: ink3Color,
        );

      case TimerAppearance.kernel:
        return TimerKernel(
          progress: progress,
          timeDisplay: timeDisplay,
          sessionLabel: sessionLabel,
          activeColor: ringColor,
          baseColor: trackColor,
          bumpColor: bumpColor,
          bumpEdgeColor: bumpEdgeColor,
          inkColor: inkColor,
          ink2Color: ink2Color,
          ink3Color: ink3Color,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
        );

      case TimerAppearance.numerals:
        return TimerNumerals(
          progress: progress,
          timeDisplay: timeDisplay,
          sessionLabel: sessionLabel,
          taskName: taskName,
          activeColor: ringColor,
          trackColor: trackColor,
          inkColor: inkColor,
          ink2Color: ink2Color,
          ink3Color: ink3Color,
        );
    }
  }
}

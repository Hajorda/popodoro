import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';

// Timer variant: oversized serif time only, with a thin progress bar below.
class TimerNumerals extends StatelessWidget {
  const TimerNumerals({
    super.key,
    required this.progress,
    required this.timeDisplay,
    required this.sessionLabel,
    this.taskName,
    required this.activeColor,
    required this.trackColor,
    required this.inkColor,
    required this.ink2Color,
    required this.ink3Color,
  });

  final double progress;
  final String timeDisplay;
  final String sessionLabel;
  final String? taskName;
  final Color activeColor;
  final Color trackColor;
  final Color inkColor;
  final Color ink2Color;
  final Color ink3Color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          sessionLabel,
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 10,
            color: ink3Color,
            letterSpacing: 0.14,
          ),
        ),
        const SizedBox(height: 8),
        // Scale the giant time to fill available width
        LayoutBuilder(builder: (context, constraints) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              timeDisplay,
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 180,
                color: inkColor,
                letterSpacing: -6,
                height: 0.9,
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        // Thin progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: SizedBox(
            width: 220,
            height: 4,
            child: Stack(
              children: [
                Container(color: trackColor),
                FractionallySizedBox(
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: activeColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (taskName != null && taskName!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            taskName!,
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 20,
              color: ink2Color,
              fontStyle: FontStyle.italic,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

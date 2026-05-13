import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';

// Timer variant: a row of 25 dots filling left-to-right, large mono time above.
class TimerDots extends StatelessWidget {
  const TimerDots({
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

  static const _total = 25;

  @override
  Widget build(BuildContext context) {
    final filled = (progress * _total).round().clamp(0, _total);

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
        const SizedBox(height: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            timeDisplay,
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 96,
              color: inkColor,
              letterSpacing: -2,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 25 dots — one per minute of the default focus session
        Wrap(
          spacing: 5,
          runSpacing: 5,
          alignment: WrapAlignment.center,
          children: List.generate(_total, (i) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < filled ? activeColor : trackColor,
              ),
            );
          }),
        ),
        if (taskName != null && taskName!.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            taskName!,
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 18,
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

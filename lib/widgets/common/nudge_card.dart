import 'package:flutter/material.dart';
import '../../core/theme/app_typography.dart';

// "Work buddy" nudge — a yellow accent bar with a short contextual message.
// Shown on the home screen when Pop has something to suggest.
class NudgeCard extends StatelessWidget {
  const NudgeCard({
    super.key,
    required this.message,
    this.highlightedTime,
    required this.surfaceColor,
    required this.borderColor,
    required this.accentColor,
    required this.inkColor,
    required this.ink2Color,
  });

  final String message;
  final String? highlightedTime; // e.g. "10:14 am" — bolded in the message
  final Color surfaceColor;
  final Color borderColor;
  final Color accentColor;
  final Color inkColor;
  final Color ink2Color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Accent bar
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMessage(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage() {
    if (highlightedTime == null || !message.contains(highlightedTime!)) {
      return Text(
        message,
        style: TextStyle(fontFamily: AppFonts.ui, 
          fontSize: 13,
          color: ink2Color,
          height: 1.45,
        ),
      );
    }

    // Split around the highlighted time and bold it
    final parts = message.split(highlightedTime!);
    return Text.rich(
      TextSpan(
        style: TextStyle(fontFamily: AppFonts.ui, fontSize: 13, color: ink2Color, height: 1.45),
        children: [
          TextSpan(text: parts[0]),
          TextSpan(
            text: highlightedTime,
            style: TextStyle(fontFamily: AppFonts.ui, 
              fontSize: 13,
              color: inkColor,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          if (parts.length > 1) TextSpan(text: parts[1]),
        ],
      ),
    );
  }
}

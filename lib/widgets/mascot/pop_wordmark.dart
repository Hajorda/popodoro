import 'package:flutter/material.dart';
import '../../core/theme/app_typography.dart';

// "p○podoro." — the butter-yellow circle replaces the first 'o',
// with a thin ink border creating the logo mark.
class PopWordmark extends StatelessWidget {
  const PopWordmark({
    super.key,
    this.fontSize = 28,
    required this.color,
    required this.accentColor,
  });

  final double fontSize;
  final Color color;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontFamily: AppFonts.display, 
      fontSize: fontSize,
      color: color,
      letterSpacing: -0.02 * fontSize,
      height: 0.95,
    );

    final dotSize = fontSize * 0.38;
    final ringWidth = (fontSize * 0.045).clamp(1.0, 3.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('p', style: style),
        // Dot — sized and vertically centered to sit where 'o' would be
        Container(
          width: dotSize,
          height: dotSize,
          margin: EdgeInsets.only(bottom: fontSize * 0.04),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accentColor,
            border: Border.all(color: color, width: ringWidth),
          ),
        ),
        Text('podoro', style: style),
        Text('.', style: style.copyWith(color: accentColor)),
      ],
    );
  }
}

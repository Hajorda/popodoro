import 'package:flutter/material.dart';
import '../../core/theme/app_typography.dart';

enum PopButtonVariant { primary, secondary, ghost, icon }

// Design system buttons: pill-shaped, three visual weights.
// primary  — filled ink bg, cream text
// secondary — white bg, ink text, border
// ghost    — transparent, ink2 text
// icon     — circular, surface bg
class PopButton extends StatelessWidget {
  const PopButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = PopButtonVariant.primary,
    this.small = false,
    this.icon,
    required this.inkColor,
    required this.bgColor,
    required this.surfaceColor,
    required this.borderColor,
    required this.ink2Color,
  });

  final String label;
  final VoidCallback? onPressed;
  final PopButtonVariant variant;
  final bool small;
  final Widget? icon;
  final Color inkColor;
  final Color bgColor;
  final Color surfaceColor;
  final Color borderColor;
  final Color ink2Color;

  @override
  Widget build(BuildContext context) {
    final hPad = small ? 14.0 : 20.0;
    final vPad = small ? 8.0 : 12.0;
    final fontSize = small ? 13.0 : 15.0;

    final baseStyle = TextStyle(fontFamily: AppFonts.ui, 
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.005 * fontSize,
      height: 1.0,
    );

    switch (variant) {
      case PopButtonVariant.primary:
        return _buildRaw(
          backgroundColor: inkColor,
          foregroundColor: bgColor,
          textStyle: baseStyle.copyWith(color: bgColor),
          hPad: hPad,
          vPad: vPad,
          border: null,
        );

      case PopButtonVariant.secondary:
        return _buildRaw(
          backgroundColor: surfaceColor,
          foregroundColor: inkColor,
          textStyle: baseStyle.copyWith(color: inkColor),
          hPad: hPad,
          vPad: vPad,
          border: BorderSide(color: borderColor),
        );

      case PopButtonVariant.ghost:
        return _buildRaw(
          backgroundColor: Colors.transparent,
          foregroundColor: ink2Color,
          textStyle: baseStyle.copyWith(color: ink2Color),
          hPad: hPad,
          vPad: vPad,
          border: null,
        );

      case PopButtonVariant.icon:
        return GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: surfaceColor,
              border: Border.all(color: borderColor),
            ),
            child: Center(
              child: icon ??
                  Text(label, style: baseStyle.copyWith(color: inkColor)),
            ),
          ),
        );
    }
  }

  Widget _buildRaw({
    required Color backgroundColor,
    required Color foregroundColor,
    required TextStyle textStyle,
    required double hPad,
    required double vPad,
    BorderSide? border,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
          border: border != null ? Border.fromBorderSide(border) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[icon!, const SizedBox(width: 6)],
            Text(label, style: textStyle),
          ],
        ),
      ),
    );
  }
}

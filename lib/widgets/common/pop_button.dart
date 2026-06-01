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
      // Natural-ish leading (was 1.0) so ascenders/descenders don't clip at
      // large OS text scale.
      height: 1.1,
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
        return _Pressable(
          onTap: onPressed,
          behavior: HitTestBehavior.opaque,
          // Hit area expanded to >=48px for accessibility; the visible 40×40
          // circle stays centered and unchanged.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(
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
    return _Pressable(
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
            // Degrade gracefully if the label is long or text scale is large.
            Flexible(
              child: Text(
                label,
                style: textStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Wraps a control's tap area to add desktop affordances missing from a bare
// GestureDetector: a pointer (click) cursor on hover and a brief press-down
// scale cue. When [onTap] is null the control is treated as disabled — no
// cursor change and no press animation — so this is also safe for any
// future loading/disabled states.
class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.child,
    required this.onTap,
    this.behavior,
  });

  final Widget child;
  final VoidCallback? onTap;
  final HitTestBehavior? behavior;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  bool get _enabled => widget.onTap != null;

  void _setPressed(bool value) {
    if (!_enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: _enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: widget.behavior,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

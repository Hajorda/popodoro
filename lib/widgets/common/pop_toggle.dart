import 'package:flutter/material.dart';
import '../../core/theme/app_typography.dart';

// Design-system toggle row: label on the left, pill toggle on the right.
class PopToggle extends StatelessWidget {
  const PopToggle({
    super.key,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
    required this.activeColor,
    required this.surface2Color,
    required this.borderColor,
    required this.inkColor,
    required this.ink2Color,
    this.disabled = false,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final void Function(bool) onChanged;
  final Color activeColor;
  final Color surface2Color;
  final Color borderColor;
  final Color inkColor;
  final Color ink2Color;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.4 : 1.0,
      child: GestureDetector(
        onTap: disabled ? null : () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontFamily: AppFonts.ui,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: inkColor,
                      height: 1.3,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(fontFamily: AppFonts.ui, 
                        fontSize: 12,
                        color: ink2Color,
                        height: 1.4,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _PillToggle(
              value: value,
              activeColor: activeColor,
              surface2Color: surface2Color,
              borderColor: borderColor,
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _PillToggle extends StatelessWidget {
  const _PillToggle({
    required this.value,
    required this.activeColor,
    required this.surface2Color,
    required this.borderColor,
  });

  final bool value;
  final Color activeColor;
  final Color surface2Color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: 44,
      height: 26,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: value ? activeColor : surface2Color,
        border: Border.all(color: borderColor),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [BoxShadow(color: Color(0x29000000), blurRadius: 2, offset: Offset(0, 1))],
            ),
          ),
        ),
      ),
    );
  }
}

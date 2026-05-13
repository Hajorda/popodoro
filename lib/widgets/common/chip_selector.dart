import 'package:flutter/material.dart';
import '../../core/theme/app_typography.dart';

// Horizontal row of mutually-exclusive selection chips.
// T can be int, String, or any equatable value.
class ChipSelector<T> extends StatelessWidget {
  const ChipSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.inkColor,
    required this.bgColor,
    required this.surfaceColor,
    required this.borderColor,
    required this.ink2Color,
    this.labelBuilder,
  });

  final List<T> options;
  final T selected;
  final void Function(T) onSelect;
  final Color inkColor;
  final Color bgColor;
  final Color surfaceColor;
  final Color borderColor;
  final Color ink2Color;

  // Optional: convert T to display label. Defaults to toString().
  final String Function(T)? labelBuilder;

  String _label(T v) => labelBuilder != null ? labelBuilder!(v) : v.toString();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isActive = opt == selected;
        return GestureDetector(
          onTap: () => onSelect(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: isActive ? inkColor : surfaceColor,
              border: Border.all(
                color: isActive ? inkColor : borderColor,
              ),
            ),
            child: Text(
              _label(opt),
              style: TextStyle(fontFamily: AppFonts.ui, 
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isActive ? bgColor : ink2Color,
                height: 1.0,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

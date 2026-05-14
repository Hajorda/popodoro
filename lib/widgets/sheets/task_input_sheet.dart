import 'package:flutter/material.dart';
import '../../core/theme/app_typography.dart';
import 'package:provider/provider.dart';

import '../../controllers/settings_controller.dart';
import '../../controllers/timer_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/session_tag.dart';
import '../../services/sound_service.dart';
import '../common/chip_selector.dart';

// Shows a bottom sheet asking "what are you working on?" before starting focus.
Future<void> showTaskInputSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _TaskInputSheet(),
  );
}

class _TaskInputSheet extends StatefulWidget {
  const _TaskInputSheet();

  @override
  State<_TaskInputSheet> createState() => _TaskInputSheetState();
}

class _TaskInputSheetState extends State<_TaskInputSheet> {
  late TextEditingController _textCtrl;
  late int _selectedMinutes;
  SessionTag? _selectedTag;

  @override
  void initState() {
    super.initState();
    final timer = context.read<TimerController>();
    final settings = context.read<SettingsController>();
    _textCtrl = TextEditingController(text: timer.taskName);
    _selectedMinutes = settings.focusMinutes;
    _selectedTag = SessionTag.fromString(timer.tag);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _start() {
    final timer = context.read<TimerController>();
    timer.setTask(_textCtrl.text);
    timer.setTag(_selectedTag?.label ?? '');

    if (_selectedMinutes != context.read<SettingsController>().focusMinutes) {
      timer.setCustomFocusMinutes(_selectedMinutes);
    }

    context.read<SoundService>().playSwitch();
    timer.start();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: t.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  'What are you working on?',
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 22,
                    color: t.ink,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 16),

                // Task text field
                _TaskField(
                  controller: _textCtrl,
                  t: t,
                  onSubmitted: (_) => _start(),
                ),
                const SizedBox(height: 20),

                // Tag picker
                Text(
                  'TAG',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 10,
                    color: t.ink3,
                    letterSpacing: 0.14,
                  ),
                ),
                const SizedBox(height: 10),
                _TagPicker(
                  selected: _selectedTag,
                  t: t,
                  onSelect: (tag) => setState(
                    () => _selectedTag = _selectedTag == tag ? null : tag,
                  ),
                ),
                const SizedBox(height: 20),

                // Duration override
                Text(
                  'DURATION',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 10,
                    color: t.ink3,
                    letterSpacing: 0.14,
                  ),
                ),
                const SizedBox(height: 10),
                ChipSelector<int>(
                  options: SettingsController.focusOptions,
                  selected: _selectedMinutes,
                  onSelect: (v) => setState(() => _selectedMinutes = v),
                  labelBuilder: (v) => '$v min',
                  inkColor: t.ink,
                  bgColor: t.bg,
                  surfaceColor: t.surface2,
                  borderColor: t.border,
                  ink2Color: t.ink2,
                ),
                const SizedBox(height: 24),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: _SheetButton(
                        label: 'Skip',
                        onTap: () {
                          context.read<SoundService>().playSwitch();
                          context.read<TimerController>().setTask('');
                          context.read<TimerController>().setTag('');
                          context.read<TimerController>().start();
                          Navigator.of(context).pop();
                        },
                        t: t,
                        primary: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _SheetButton(
                        label: 'Start focus',
                        onTap: _start,
                        t: t,
                        primary: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tag picker ────────────────────────────────────────────────────────────────

class _TagPicker extends StatelessWidget {
  const _TagPicker({required this.selected, required this.t, required this.onSelect});

  final SessionTag? selected;
  final AppTokens t;
  final void Function(SessionTag) onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: SessionTag.values.map((tag) {
        final isSelected = tag == selected;
        final tagColor = tag.colorFor(t);
        return GestureDetector(
          onTap: () => onSelect(tag),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? tagColor.withValues(alpha: 0.14) : t.surface2,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSelected ? tagColor.withValues(alpha: 0.6) : t.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tag.emoji, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 5),
                Text(
                  tag.label,
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? tagColor : t.ink2,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Task text field ───────────────────────────────────────────────────────────

class _TaskField extends StatelessWidget {
  const _TaskField({
    required this.controller,
    required this.t,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final AppTokens t;
  final void Function(String) onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      onSubmitted: onSubmitted,
      style: TextStyle(fontFamily: AppFonts.ui, fontSize: 16, color: t.ink, height: 1.4),
      cursorColor: t.pop,
      decoration: InputDecoration(
        hintText: 'e.g. Draft Q3 roadmap…',
        hintStyle: TextStyle(fontFamily: AppFonts.ui, fontSize: 16, color: t.ink3, height: 1.4),
        filled: true,
        fillColor: t.surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.pop, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ── Sheet action button ───────────────────────────────────────────────────────

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.onTap,
    required this.t,
    required this.primary,
  });

  final String label;
  final VoidCallback onTap;
  final AppTokens t;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: primary ? t.ink : t.surface2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: primary ? t.ink : t.border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: primary ? t.bg : t.ink2,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

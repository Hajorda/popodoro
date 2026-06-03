import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../controllers/settings_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../services/together_service.dart';
import 'lobby_screen.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _taskController = TextEditingController();
  late int _focusMinutes;
  late int _breakMinutes;
  int _rounds = 1;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsController>();
    _focusMinutes = settings.focusMinutes;
    _breakMinutes = settings.shortBreakMinutes;
  }

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  Future<void> _startRoom() async {
    final together = context.read<TogetherService>();
    final ok = await together.createRoom(
      taskName: _taskController.text.trim().isEmpty
          ? null
          : _taskController.text.trim(),
      durationMinutes: _focusMinutes,
      breakMinutes: _breakMinutes,
      roundsTotal: _rounds,
    );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const LobbyScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final together = context.watch<TogetherService>();

    return Scaffold(
      backgroundColor: t.bg,
      appBar: _AppBar(t: t),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          // Task field
          _SectionLabel(t: t, label: 'WHAT ARE YOU FOCUSING ON?'),
          const SizedBox(height: 8),
          _TaskField(t: t, controller: _taskController),
          const SizedBox(height: 24),

          // Focus Duration
          _SectionLabel(t: t, label: 'FOCUS DURATION'),
          const SizedBox(height: 10),
          _ChipRow(
            t: t,
            options: SettingsController.focusOptions,
            selected: _focusMinutes,
            min: 1, max: 180,
            onSelect: (v) => setState(() => _focusMinutes = v),
          ),
          const SizedBox(height: 24),

          // Break Duration
          _SectionLabel(t: t, label: 'BREAK DURATION'),
          const SizedBox(height: 10),
          _ChipRow(
            t: t,
            options: SettingsController.shortBreakOptions,
            selected: _breakMinutes,
            min: 1, max: 60,
            onSelect: (v) => setState(() => _breakMinutes = v),
          ),
          const SizedBox(height: 24),

          // Rounds
          _SectionLabel(t: t, label: 'TOTAL ROUNDS'),
          const SizedBox(height: 10),
          _SessionPicker(
            t: t,
            selected: _rounds,
            onChanged: (v) => setState(() => _rounds = v),
          ),
          const SizedBox(height: 32),

          // Error
          if (together.error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.ember.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                together.error!,
                style: TextStyle(
                    fontFamily: AppFonts.ui, fontSize: 13, color: t.ember),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // CTA
          _StartButton(
            t: t,
            loading: together.loading,
            onTap: _startRoom,
          ),
        ],
      ),
    );
  }
}

// ── App bar ───────────────────────────────────────────────────────────────────

class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AppBar({required this.t});
  final AppTokens t;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: t.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.surface,
              border: Border.all(color: t.border),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                size: 14, color: t.ink),
          ),
        ),
      ),
      title: Text(
        'New Room',
        style: TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: t.ink,
        ),
      ),
      centerTitle: true,
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.t, required this.label});
  final AppTokens t;
  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: TextStyle(
          fontFamily: AppFonts.mono,
          fontSize: 10,
          color: t.ink3,
          letterSpacing: 0.14,
        ),
      );
}

class _TaskField extends StatelessWidget {
  const _TaskField({required this.t, required this.controller});
  final AppTokens t;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(
          fontFamily: AppFonts.display,
          fontSize: 18,
          color: t.ink,
          fontStyle: FontStyle.italic,
        ),
        decoration: InputDecoration(
          hintText: 'deep work, design, code…',
          hintStyle: TextStyle(
            fontFamily: AppFonts.display,
            fontSize: 18,
            color: t.ink3,
            fontStyle: FontStyle.italic,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        maxLines: 1,
        inputFormatters: [LengthLimitingTextInputFormatter(60)],
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.t,
    required this.options,
    required this.selected,
    required this.min,
    required this.max,
    required this.onSelect,
  });
  final AppTokens t;
  final List<int> options;
  final int selected;
  final int min;
  final int max;
  final ValueChanged<int> onSelect;

  void _showCustomDialog(BuildContext context) {
    final controller = TextEditingController(
      text: options.contains(selected) ? '' : '$selected',
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Custom duration',
            style: TextStyle(fontFamily: AppFonts.ui, fontSize: 16, fontWeight: FontWeight.w600, color: t.ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(fontFamily: AppFonts.display, fontSize: 32, color: t.ink, letterSpacing: -0.5),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '$min–$max',
                hintStyle: TextStyle(fontFamily: AppFonts.mono, fontSize: 14, color: t.ink3),
                suffix: Text('min', style: TextStyle(fontFamily: AppFonts.mono, fontSize: 12, color: t.ink3)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.pop, width: 2)),
              ),
            ),
            const SizedBox(height: 4),
            Text('$min – $max minutes', style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: t.ink3)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(fontFamily: AppFonts.ui, color: t.ink2)),
          ),
          TextButton(
            onPressed: () {
              final v = int.tryParse(controller.text);
              if (v != null && v >= min && v <= max) {
                onSelect(v);
                Navigator.of(ctx).pop();
              }
            },
            child: Text('Set', style: TextStyle(fontFamily: AppFonts.ui, color: t.pop, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCustom = !options.contains(selected);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...options.map((v) {
          final on = v == selected;
          return GestureDetector(
            onTap: () => onSelect(v),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: on ? t.ink : t.surface,
                border: Border.all(color: on ? t.ink : t.border),
                borderRadius: BorderRadius.circular(999),
              ),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontFamily: AppFonts.display, fontSize: 17, color: on ? t.bg : t.ink),
                  children: [
                    TextSpan(text: '$v'),
                    TextSpan(
                      text: ' min',
                      style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9, color: (on ? t.bg : t.ink).withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        GestureDetector(
          onTap: () => _showCustomDialog(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isCustom ? t.ink : t.surface,
              border: Border.all(color: isCustom ? t.ink : t.border),
              borderRadius: BorderRadius.circular(999),
            ),
            child: isCustom
                ? RichText(
                    text: TextSpan(
                      style: TextStyle(fontFamily: AppFonts.display, fontSize: 17, color: t.bg),
                      children: [
                        TextSpan(text: '$selected'),
                        TextSpan(
                          text: ' min',
                          style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9, color: t.bg.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 14, color: t.ink2),
                      const SizedBox(width: 3),
                      Text('Custom', style: TextStyle(fontFamily: AppFonts.ui, fontSize: 13, color: t.ink2, fontWeight: FontWeight.w500)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _SessionPicker extends StatelessWidget {
  const _SessionPicker({required this.t, required this.selected, required this.onChanged});
  final AppTokens t;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const maxSessions = 8;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(maxSessions, (i) {
                    final n = i + 1;
                    final on = n == selected;
                    return GestureDetector(
                      onTap: () => onChanged(n),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: on ? t.pop : t.surface2,
                          border: Border.all(color: on ? t.popDeep : t.border, width: on ? 2 : 1.5),
                        ),
                        child: Center(
                          child: Text(
                            '$n',
                            style: TextStyle(
                              fontFamily: AppFonts.display,
                              fontSize: 15,
                              color: on ? t.ink : t.ink3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.repeat_rounded, size: 12, color: t.ink3),
              const SizedBox(width: 5),
              Text(
                '$selected ${selected == 1 ? 'round' : 'rounds'} for this session',
                style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: t.ink3, letterSpacing: 0.05),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.t, required this.loading, required this.onTap});
  final AppTokens t;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: loading ? t.surface2 : t.pop,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: loading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: t.ink3),
                )
              : Text(
                  'Start when ready',
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: t.ink,
                  ),
                ),
        ),
      ),
    );
  }
}

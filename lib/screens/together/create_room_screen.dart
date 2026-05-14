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
  int _durationMinutes = 25;

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  Future<void> _startRoom() async {
    final together = context.read<TogetherService>();
    final breakMins = context.read<SettingsController>().shortBreakMinutes;
    final ok = await together.createRoom(
      taskName: _taskController.text.trim().isEmpty
          ? null
          : _taskController.text.trim(),
      durationMinutes: _durationMinutes,
      breakMinutes: breakMins,
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

          // Duration
          _SectionLabel(t: t, label: 'DURATION'),
          const SizedBox(height: 10),
          _DurationPicker(
            t: t,
            selected: _durationMinutes,
            onChanged: (v) => setState(() => _durationMinutes = v),
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

class _DurationPicker extends StatelessWidget {
  const _DurationPicker({required this.t, required this.selected, required this.onChanged});
  final AppTokens t;
  final int selected;
  final ValueChanged<int> onChanged;

  static const _options = [25, 50, 90];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _options.map((mins) {
        final isSelected = selected == mins;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: mins != _options.last ? 10 : 0),
            child: GestureDetector(
              onTap: () => onChanged(mins),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? t.ink : t.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? t.ink : t.border,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '$mins',
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? t.bg : t.ink,
                      ),
                    ),
                    Text(
                      'min',
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 10,
                        color: isSelected ? t.bg.withValues(alpha: 0.6) : t.ink3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
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

import 'package:flutter/material.dart';
import '../../core/theme/app_typography.dart';
import 'package:provider/provider.dart';

import '../../controllers/settings_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/pomodoro_state.dart';
import '../../services/window_service.dart';
import '../../widgets/common/chip_selector.dart';
import '../../widgets/common/pop_toggle.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: _SettingsAppBar(t: t),
      body: Consumer<SettingsController>(
        builder: (context, settings, _) => _SettingsBody(t: t, settings: settings),
      ),
    );
  }
}

// ── App bar ───────────────────────────────────────────────────────────────────

class _SettingsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _SettingsAppBar({required this.t});

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
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: t.ink),
          ),
        ),
      ),
      title: Text(
        'Settings',
        style: TextStyle(fontFamily: AppFonts.ui, 
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: t.ink,
        ),
      ),
      centerTitle: true,
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _SettingsBody extends StatelessWidget {
  const _SettingsBody({required this.t, required this.settings});

  final AppTokens t;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      children: [
        _Section(
          title: 'Durations',
          t: t,
          children: [
            _DurationRow(
              label: 'Focus',
              value: settings.focusMinutes,
              options: SettingsController.focusOptions,
              onSelect: (v) => settings.focusMinutes = v,
              t: t,
            ),
            const SizedBox(height: 20),
            _DurationRow(
              label: 'Short break',
              value: settings.shortBreakMinutes,
              options: SettingsController.shortBreakOptions,
              onSelect: (v) => settings.shortBreakMinutes = v,
              t: t,
            ),
            const SizedBox(height: 20),
            _DurationRow(
              label: 'Long break',
              value: settings.longBreakMinutes,
              options: SettingsController.longBreakOptions,
              onSelect: (v) => settings.longBreakMinutes = v,
              t: t,
            ),
            const SizedBox(height: 20),
            _DurationRow(
              label: 'Sessions before long break',
              value: settings.sessionsBeforeLongBreak,
              options: SettingsController.sessionOptions,
              onSelect: (v) => settings.sessionsBeforeLongBreak = v,
              t: t,
            ),
          ],
        ),
        const SizedBox(height: 8),
        _Section(
          title: 'Behaviour',
          t: t,
          children: [
            PopToggle(
              label: 'Auto-start breaks',
              subtitle: 'Break begins automatically when focus ends',
              value: settings.autoStartBreaks,
              onChanged: (v) => settings.autoStartBreaks = v,
              activeColor: t.pop,
              surface2Color: t.surface2,
              borderColor: t.border,
              inkColor: t.ink,
              ink2Color: t.ink2,
            ),
            Divider(color: t.border, height: 28),
            PopToggle(
              label: 'Auto-start focus',
              subtitle: 'Focus session begins automatically after a break',
              value: settings.autoStartFocus,
              onChanged: (v) => settings.autoStartFocus = v,
              activeColor: t.pop,
              surface2Color: t.surface2,
              borderColor: t.border,
              inkColor: t.ink,
              ink2Color: t.ink2,
            ),
            Divider(color: t.border, height: 28),
            PopToggle(
              label: 'Sound',
              subtitle: 'Chime on session complete, click on button tap',
              value: settings.soundEnabled,
              onChanged: (v) => settings.soundEnabled = v,
              activeColor: t.pop,
              surface2Color: t.surface2,
              borderColor: t.border,
              inkColor: t.ink,
              ink2Color: t.ink2,
            ),
          ],
        ),
        const SizedBox(height: 8),
        _Section(
          title: 'Appearance',
          t: t,
          children: [
            _ThemeRow(t: t, settings: settings),
            Divider(color: t.border, height: 28),
            _TimerStyleRow(t: t, settings: settings),
          ],
        ),
        const SizedBox(height: 8),
        _Section(
          title: 'Window',
          t: t,
          children: [
            _WindowRow(t: t),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Section wrapper ───────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.t, required this.children});

  final String title;
  final AppTokens t;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 12),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(fontFamily: AppFonts.mono, 
              fontSize: 10,
              color: t.ink3,
              letterSpacing: 0.14,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: t.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}

// ── Duration row ──────────────────────────────────────────────────────────────

class _DurationRow extends StatelessWidget {
  const _DurationRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onSelect,
    required this.t,
  });

  final String label;
  final int value;
  final List<int> options;
  final void Function(int) onSelect;
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontFamily: AppFonts.ui, 
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: t.ink,
          ),
        ),
        const SizedBox(height: 10),
        ChipSelector<int>(
          options: options,
          selected: value,
          onSelect: onSelect,
          labelBuilder: (v) => '$v min',
          inkColor: t.ink,
          bgColor: t.bg,
          surfaceColor: t.surface2,
          borderColor: t.border,
          ink2Color: t.ink2,
        ),
      ],
    );
  }
}

// ── Window row ────────────────────────────────────────────────────────────────

class _WindowRow extends StatelessWidget {
  const _WindowRow({required this.t});

  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        context.read<WindowService>().enterMiniMode();
      },
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Mini mode',
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: t.ink,
                    height: 1.3,
                  ),
                ),
                Text(
                  'Float as a compact pill overlay',
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 12,
                    color: t.ink2,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.picture_in_picture_alt_rounded, size: 18, color: t.ink3),
        ],
      ),
    );
  }
}

// ── Timer style row ───────────────────────────────────────────────────────────

class _TimerStyleRow extends StatelessWidget {
  const _TimerStyleRow({required this.t, required this.settings});

  final AppTokens t;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Timer style',
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: t.ink,
          ),
        ),
        const SizedBox(height: 10),
        ChipSelector<TimerAppearance>(
          options: TimerAppearance.values,
          selected: settings.timerAppearance,
          onSelect: (v) => settings.timerAppearance = v,
          labelBuilder: (v) => v.label,
          inkColor: t.ink,
          bgColor: t.bg,
          surfaceColor: t.surface2,
          borderColor: t.border,
          ink2Color: t.ink2,
        ),
      ],
    );
  }
}

// ── Theme row ─────────────────────────────────────────────────────────────────

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({required this.t, required this.settings});

  final AppTokens t;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Theme',
          style: TextStyle(fontFamily: AppFonts.ui, 
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: t.ink,
          ),
        ),
        const SizedBox(height: 10),
        ChipSelector<ThemeMode>(
          options: ThemeMode.values,
          selected: settings.themeMode,
          onSelect: (v) => settings.themeMode = v,
          labelBuilder: (v) => v.name[0].toUpperCase() + v.name.substring(1),
          inkColor: t.ink,
          bgColor: t.bg,
          surfaceColor: t.surface2,
          borderColor: t.border,
          ink2Color: t.ink2,
        ),
      ],
    );
  }
}

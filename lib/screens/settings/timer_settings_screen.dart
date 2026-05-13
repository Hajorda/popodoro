import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/settings_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../widgets/common/pop_toggle.dart';

class TimerSettingsScreen extends StatelessWidget {
  const TimerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: _AppBar(t: t),
      body: Consumer<SettingsController>(
        builder: (context, settings, _) => _Body(t: t, settings: settings),
      ),
    );
  }
}

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
            decoration: BoxDecoration(shape: BoxShape.circle, color: t.surface, border: Border.all(color: t.border)),
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: t.ink),
          ),
        ),
      ),
      title: Text('Timer & rhythm',
          style: TextStyle(fontFamily: AppFonts.ui, fontSize: 17, fontWeight: FontWeight.w600, color: t.ink)),
      centerTitle: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Done', style: TextStyle(fontFamily: AppFonts.ui, fontSize: 15, color: t.pop, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.t, required this.settings});
  final AppTokens t;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        // Rhythm preview hero
        const SizedBox(height: 12),
        _RhythmHero(t: t, settings: settings),
        const SizedBox(height: 22),

        // Focus duration
        _Field(t: t, label: 'Focus session', child: _ChipRow(
          t: t,
          options: SettingsController.focusOptions,
          selected: settings.focusMinutes,
          onSelect: (v) => settings.focusMinutes = v,
        )),
        const SizedBox(height: 18),

        // Short break
        _Field(t: t, label: 'Short break', child: _ChipRow(
          t: t,
          options: SettingsController.shortBreakOptions,
          selected: settings.shortBreakMinutes,
          onSelect: (v) => settings.shortBreakMinutes = v,
        )),
        const SizedBox(height: 18),

        // Long break
        _Field(t: t, label: 'Long break', child: _ChipRow(
          t: t,
          options: SettingsController.longBreakOptions,
          selected: settings.longBreakMinutes,
          onSelect: (v) => settings.longBreakMinutes = v,
        )),
        const SizedBox(height: 18),

        // Sessions before long break
        _Field(t: t, label: 'Sessions before long break',
          child: _SessionDots(t: t, settings: settings)),
        const SizedBox(height: 24),

        // Automation toggles
        _Label(t: t, label: 'Automation'),
        Container(
          decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.border)),
          child: Column(
            children: [
              PopToggle(
                label: 'Auto-start breaks',
                subtitle: 'Break begins the moment focus ends',
                value: settings.autoStartBreaks,
                onChanged: (v) => settings.autoStartBreaks = v,
                activeColor: t.pop, surface2Color: t.surface2, borderColor: t.border, inkColor: t.ink, ink2Color: t.ink2,
              ),
              Divider(color: t.border, height: 1, indent: 16),
              PopToggle(
                label: 'Auto-start next focus',
                subtitle: 'Pop nudges you instead — recommended off',
                value: settings.autoStartFocus,
                onChanged: (v) => settings.autoStartFocus = v,
                activeColor: t.pop, surface2Color: t.surface2, borderColor: t.border, inkColor: t.ink, ink2Color: t.ink2,
              ),
              Divider(color: t.border, height: 1, indent: 16),
              PopToggle(
                label: 'Sound',
                subtitle: 'Chime on complete, click on tap',
                value: settings.soundEnabled,
                onChanged: (v) => settings.soundEnabled = v,
                activeColor: t.pop, surface2Color: t.surface2, borderColor: t.border, inkColor: t.ink, ink2Color: t.ink2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Rhythm hero ───────────────────────────────────────────────────────────────

class _RhythmHero extends StatelessWidget {
  const _RhythmHero({required this.t, required this.settings});
  final AppTokens t;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border),
      ),
      child: Column(
        children: [
          Text('YOUR RHYTHM',
              style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: t.ink3, letterSpacing: 0.14)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${settings.focusMinutes}',
                  style: TextStyle(fontFamily: AppFonts.display, fontSize: 36, color: t.ink, letterSpacing: -0.5)),
              Text(' · ', style: TextStyle(fontFamily: AppFonts.display, fontSize: 36, color: t.ink3)),
              Text('${settings.shortBreakMinutes}',
                  style: TextStyle(fontFamily: AppFonts.display, fontSize: 36, color: t.ink, letterSpacing: -0.5)),
              Text(' · ', style: TextStyle(fontFamily: AppFonts.display, fontSize: 36, color: t.ink3)),
              Text('${settings.longBreakMinutes}',
                  style: TextStyle(fontFamily: AppFonts.display, fontSize: 36, color: t.ink, letterSpacing: -0.5)),
            ],
          ),
          const SizedBox(height: 4),
          Text('FOCUS · SHORT · LONG (MIN)',
              style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: t.ink3, letterSpacing: 0.14)),
          const SizedBox(height: 14),
          // Rhythm bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Flexible(flex: settings.focusMinutes, child: Container(color: t.pop)),
                  Flexible(flex: settings.shortBreakMinutes, child: Container(color: t.sage)),
                  Flexible(flex: settings.focusMinutes, child: Container(color: t.pop)),
                  Flexible(flex: settings.shortBreakMinutes, child: Container(color: t.sage)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Duration chip row ─────────────────────────────────────────────────────────

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.t, required this.options, required this.selected, required this.onSelect});
  final AppTokens t;
  final List<int> options;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((v) {
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
      }).toList(),
    );
  }
}

// ── Sessions dots picker ──────────────────────────────────────────────────────

class _SessionDots extends StatelessWidget {
  const _SessionDots({required this.t, required this.settings});
  final AppTokens t;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    const maxSessions = 6;
    final selected = settings.sessionsBeforeLongBreak;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: List.generate(maxSessions, (i) {
                final filled = i < selected;
                return GestureDetector(
                  onTap: () => settings.sessionsBeforeLongBreak = i + 1,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled ? t.pop : t.surface2,
                        border: Border.all(color: filled ? t.popDeep : t.border, width: 1.5),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Text(
            '$selected',
            style: TextStyle(fontFamily: AppFonts.mono, fontSize: 16, color: t.ink, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  const _Field({required this.t, required this.label, required this.child});
  final AppTokens t;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(t: t, label: label),
        child,
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.t, required this.label});
  final AppTokens t;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: t.ink3, letterSpacing: 0.14),
      ),
    );
  }
}

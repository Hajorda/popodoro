import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        const SizedBox(height: 12),
        _RhythmHero(t: t, settings: settings),
        const SizedBox(height: 22),

        _Field(t: t, label: 'Focus session', child: _ChipRow(
          t: t,
          options: SettingsController.focusOptions,
          selected: settings.focusMinutes,
          min: 1, max: 180,
          onSelect: (v) => settings.focusMinutes = v,
        )),
        const SizedBox(height: 18),

        _Field(t: t, label: 'Short break', child: _ChipRow(
          t: t,
          options: SettingsController.shortBreakOptions,
          selected: settings.shortBreakMinutes,
          min: 1, max: 60,
          onSelect: (v) => settings.shortBreakMinutes = v,
        )),
        const SizedBox(height: 18),

        _Field(t: t, label: 'Long break', child: _ChipRow(
          t: t,
          options: SettingsController.longBreakOptions,
          selected: settings.longBreakMinutes,
          min: 1, max: 120,
          onSelect: (v) => settings.longBreakMinutes = v,
        )),
        const SizedBox(height: 18),

        _Field(t: t, label: 'Sessions before long break',
          child: _SessionPicker(t: t, settings: settings)),
        const SizedBox(height: 24),

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
          const SizedBox(height: 10),
          // One full cycle summary
          Text(
            '${settings.sessionsBeforeLongBreak} sessions · then ${settings.longBreakMinutes}m long break',
            style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: t.ink3, letterSpacing: 0.05),
          ),
        ],
      ),
    );
  }
}

// ── Duration chip row ─────────────────────────────────────────────────────────

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
        // Custom chip — shows current custom value when active, "+" otherwise
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

// ── Sessions picker ───────────────────────────────────────────────────────────

class _SessionPicker extends StatelessWidget {
  const _SessionPicker({required this.t, required this.settings});
  final AppTokens t;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    const maxSessions = 8;
    final selected = settings.sessionsBeforeLongBreak;

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
                      onTap: () => settings.sessionsBeforeLongBreak = n,
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
          // Explanation row
          Row(
            children: [
              Icon(Icons.repeat_rounded, size: 12, color: t.ink3),
              const SizedBox(width: 5),
              Text(
                '$selected ${selected == 1 ? 'session' : 'sessions'}, then a ${settings.longBreakMinutes}m long break',
                style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: t.ink3, letterSpacing: 0.05),
              ),
            ],
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

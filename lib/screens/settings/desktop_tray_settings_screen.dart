import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/settings_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../widgets/common/pop_toggle.dart';

class DesktopTraySettingsScreen extends StatelessWidget {
  const DesktopTraySettingsScreen({super.key});

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
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.surface,
              border: Border.all(color: t.border),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 14,
              color: t.ink,
            ),
          ),
        ),
      ),
      title: Text(
        'System tray',
        style: TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: t.ink,
        ),
      ),
      centerTitle: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Done',
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 15,
              color: t.pop,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.t, required this.settings});
  final AppTokens t;
  final SettingsController settings;

  bool get _isDesktop => !kIsWeb && (Platform.isMacOS || Platform.isWindows);

  @override
  Widget build(BuildContext context) {
    final currentMode = settings.desktopTrayMode;
    final enabled = currentMode != DesktopTrayMode.off;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.border),
          ),
          child: Text(
            _isDesktop
                ? 'Keep Popodoro running in the tray when the window is closed. On macOS, timer mode shows time left in the menu bar. On Windows, timer mode updates tray tooltip text.'
                : 'System tray is available only on macOS and Windows.',
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 13,
              color: t.ink2,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.border),
          ),
          child: PopToggle(
            label: 'Keep running in tray',
            subtitle: _isDesktop
                ? 'Close hides app to tray instead of quitting'
                : 'Unsupported on this platform',
            value: enabled,
            disabled: !_isDesktop,
            onChanged: (v) => settings.desktopTrayMode = v
                ? DesktopTrayMode.icon
                : DesktopTrayMode.off,
            activeColor: t.pop,
            surface2Color: t.surface2,
            borderColor: t.border,
            inkColor: t.ink,
            ink2Color: t.ink2,
          ),
        ),
        const SizedBox(height: 16),
        _Label(t: t, label: 'Tray style'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ModeChip(
              t: t,
              label: 'Icon only',
              selected: currentMode == DesktopTrayMode.icon,
              disabled: !_isDesktop || !enabled,
              onTap: () => settings.desktopTrayMode = DesktopTrayMode.icon,
            ),
            _ModeChip(
              t: t,
              label: 'Icon + timer',
              selected: currentMode == DesktopTrayMode.timer,
              disabled: !_isDesktop || !enabled,
              onTap: () => settings.desktopTrayMode = DesktopTrayMode.timer,
            ),
          ],
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.t,
    required this.label,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final AppTokens t;
  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? t.ink : t.surface,
            border: Border.all(color: selected ? t.ink : t.border),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 13,
              color: selected ? t.bg : t.ink,
            ),
          ),
        ),
      ),
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
        style: TextStyle(
          fontFamily: AppFonts.mono,
          fontSize: 10,
          color: t.ink3,
          letterSpacing: 0.14,
        ),
      ),
    );
  }
}

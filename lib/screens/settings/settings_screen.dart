import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/history_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../models/pomodoro_state.dart';
import '../../services/auth_service.dart';
import '../../services/sync_service.dart';
import '../../services/update_service.dart';
import '../../services/window_service.dart';
import '../../services/bg_music_service.dart';
import 'account_screen.dart';
import 'appearance_screen.dart';
import 'background_sound_screen.dart';
import 'desktop_tray_settings_screen.dart';
import 'focus_guard_screen.dart';
import 'nudges_screen.dart';
import 'timer_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: _SettingsAppBar(t: t),
      body: Consumer2<SettingsController, HistoryController>(
        builder: (context, settings, history, _) =>
            _SettingsBody(t: t, settings: settings, history: history),
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
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 14,
              color: t.ink,
            ),
          ),
        ),
      ),
      title: Text(
        'Settings',
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

// ── Body ──────────────────────────────────────────────────────────────────────

class _SettingsBody extends StatelessWidget {
  const _SettingsBody({
    required this.t,
    required this.settings,
    required this.history,
  });
  final AppTokens t;
  final SettingsController settings;
  final HistoryController history;

  @override
  Widget build(BuildContext context) {
    final streak = history.streakDays;
    final totalSessions = history.allSessions.length;
    final totalMins = history.totalFocusedMinutesAllTime;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        // Quick stats strip
        const SizedBox(height: 12),
        _StatsStrip(
          t: t,
          streak: streak,
          sessions: totalSessions,
          totalMins: totalMins,
        ),
        const SizedBox(height: 8),

        // Focus group
        _GroupLabel(t: t, label: 'Focus'),
        _SetGroup(
          t: t,
          children: [
            _NavRow(
              t: t,
              icon: '◐',
              iconBg: t.pop,
              label: 'Timer & rhythm',
              value:
                  '${settings.focusMinutes} · ${settings.shortBreakMinutes} · ${settings.longBreakMinutes}',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const TimerSettingsScreen(),
                ),
              ),
            ),
            _Separator(t: t),
            _NavRow(
              t: t,
              icon: '◍',
              iconBg: t.surface2,
              label: "Pop's nudges",
              value: 'on · golden hrs',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const NudgesScreen()),
              ),
            ),
            _Separator(t: t),
            _NavRow(
              t: t,
              icon: '♪',
              iconBg: t.surface2,
              label: 'Sounds',
              value: settings.soundEnabled ? 'on' : 'off',
              isLast: false,
              onTap: () {},
            ),
            _Separator(t: t),
            _NavRow(
              t: t,
              icon: '♫',
              iconBg: t.sage.withValues(alpha: 0.25),
              label: 'Ambient sounds',
              value: settings.bgSoundId.isEmpty
                  ? 'off'
                  : kBgTracks
                      .where((track) => track.id == settings.bgSoundId)
                      .map((track) => track.label)
                      .firstOrNull ?? 'off',
              isLast: false,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const BackgroundSoundScreen(),
                ),
              ),
            ),
            _Separator(t: t),
            _NavRow(
              t: t,
              icon: '◉',
              iconBg: t.lavender.withValues(alpha: 0.25),
              label: 'Focus guard',
              value: settings.focusGuardEnabled ? 'on' : 'off',
              isLast: true,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const FocusGuardScreen(),
                ),
              ),
            ),
          ],
        ),

        // Look & feel
        _GroupLabel(t: t, label: 'Look & feel'),
        _SetGroup(
          t: t,
          children: [
            _NavRow(
              t: t,
              icon: '●',
              iconBg: t.ink,
              label: 'Appearance',
              value:
                  '${settings.themeMode.name[0].toUpperCase()}${settings.themeMode.name.substring(1)} · ${settings.timerAppearance.label}',
              isLast: true,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AppearanceScreen(),
                ),
              ),
            ),
          ],
        ),

        // Window (desktop only)
        if (WindowService.isDesktop) ...[
          _GroupLabel(t: t, label: 'Window'),
          _SetGroup(
            t: t,
            children: [
              _ActionRow(
                t: t,
                icon: Icons.picture_in_picture_alt_rounded,
                label: 'Mini mode',
                subtitle: 'Float as a compact pill overlay',
                isLast: false,
                onTap: () {
                  Navigator.of(context).pop();
                  context.read<WindowService>().enterMiniMode();
                },
              ),
              _Separator(t: t),
              _NavRow(
                t: t,
                icon: '◉',
                iconBg: t.surface2,
                label: 'System tray',
                value: settings.desktopTrayMode.label,
                isLast: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DesktopTraySettingsScreen(),
                  ),
                ),
              ),
            ],
          ),
        ],

        // Account
        _GroupLabel(t: t, label: 'Account'),
        _SetGroup(
          t: t,
          children: [
            Consumer2<AuthService, SyncService>(
              builder: (context, auth, sync, _) => _NavRow(
                t: t,
                icon: auth.isSignedIn ? '✓' : '↑',
                iconBg: auth.isSignedIn ? t.sage : t.surface2,
                label: 'Sync & backup',
                value: auth.isSignedIn
                    ? (sync.pendingCount > 0
                        ? '${sync.pendingCount} pending'
                        : 'synced')
                    : 'sign in',
                isLast: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const AccountScreen()),
                ),
              ),
            ),
          ],
        ),

        // About
        _GroupLabel(t: t, label: 'About'),
        _AboutSection(t: t),

        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Stats strip ───────────────────────────────────────────────────────────────

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({
    required this.t,
    required this.streak,
    required this.sessions,
    required this.totalMins,
  });
  final AppTokens t;
  final int streak;
  final int sessions;
  final int totalMins;

  String _fmtMins(int m) {
    if (m < 60) return '${m}m';
    return '${m ~/ 60}h';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: t.dim,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MiniStat(
            t: t,
            value: streak > 0 ? '🔥 $streak' : '—',
            label: 'streak',
          ),
          Container(width: 1, height: 28, color: t.border),
          _MiniStat(t: t, value: sessions.toString(), label: 'popped'),
          Container(width: 1, height: 28, color: t.border),
          _MiniStat(t: t, value: _fmtMins(totalMins), label: 'focused'),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.t, required this.value, required this.label});
  final AppTokens t;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontSize: 20,
            color: t.ink,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 9,
            color: t.ink3,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

// ── Group primitives ──────────────────────────────────────────────────────────

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.t, required this.label});
  final AppTokens t;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10, left: 4),
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

class _SetGroup extends StatelessWidget {
  const _SetGroup({required this.t, required this.children});
  final AppTokens t;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator({required this.t});
  final AppTokens t;
  @override
  Widget build(BuildContext context) =>
      Divider(color: t.border, height: 1, indent: 56);
}

// ── Row types ─────────────────────────────────────────────────────────────────

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.t,
    required this.icon,
    required this.iconBg,
    required this.label,
    this.value,
    this.isLast = false,
    required this.onTap,
  });
  final AppTokens t;
  final String icon;
  final Color iconBg;
  final String label;
  final String? value;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  icon,
                  style: TextStyle(
                    fontSize: 14,
                    color: iconBg == t.ink ? t.bg : t.ink,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: t.ink,
                ),
              ),
            ),
            if (value != null) ...[
              Text(
                value!,
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 12,
                  color: t.ink2,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(Icons.chevron_right_rounded, size: 18, color: t.ink3),
          ],
        ),
      ),
    );
  }
}

// ── About section ─────────────────────────────────────────────────────────────

enum _UpdateState { idle, checking, upToDate, available, error }

class _AboutSection extends StatefulWidget {
  const _AboutSection({required this.t});
  final AppTokens t;

  @override
  State<_AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends State<_AboutSection> {
  String _version = '—';
  _UpdateState _updateState = _UpdateState.idle;
  UpdateInfo? _updateInfo;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = info.version);
  }

  Future<void> _checkForUpdate() async {
    if (_updateState == _UpdateState.checking) return;
    setState(() => _updateState = _UpdateState.checking);
    try {
      final info = await UpdateService.checkForUpdate();
      if (!mounted) return;
      setState(() {
        _updateInfo = info;
        _updateState =
            info != null ? _UpdateState.available : _UpdateState.upToDate;
      });
    } catch (_) {
      if (mounted) setState(() => _updateState = _UpdateState.error);
    }
  }

  Future<void> _openDownload() async {
    final url = _updateInfo?.downloadUrl;
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return _SetGroup(
      t: t,
      children: [
        // Version row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: t.surface2,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Center(
                  child: Text(
                    'v',
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: t.ink2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Version',
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: t.ink,
                  ),
                ),
              ),
              Text(
                _version,
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 13,
                  color: t.ink3,
                ),
              ),
            ],
          ),
        ),

        _Separator(t: t),

        // Check for updates row
        GestureDetector(
          onTap: _updateState == _UpdateState.available
              ? _openDownload
              : _checkForUpdate,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: t.sage.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.arrow_circle_up_rounded,
                      size: 16,
                      color: t.sage,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _updateState == _UpdateState.available
                            ? 'Update available'
                            : 'Check for updates',
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _updateState == _UpdateState.available
                              ? t.sage
                              : t.ink,
                        ),
                      ),
                      if (_updateState == _UpdateState.available &&
                          _updateInfo != null)
                        Text(
                          'v${_updateInfo!.version} ready to download',
                          style: TextStyle(
                            fontFamily: AppFonts.ui,
                            fontSize: 12,
                            color: t.sage,
                            height: 1.4,
                          ),
                        )
                      else if (_updateState == _UpdateState.upToDate)
                        Text(
                          "You're on the latest version",
                          style: TextStyle(
                            fontFamily: AppFonts.ui,
                            fontSize: 12,
                            color: t.ink3,
                            height: 1.4,
                          ),
                        )
                      else if (_updateState == _UpdateState.error)
                        Text(
                          'Check failed — try again',
                          style: TextStyle(
                            fontFamily: AppFonts.ui,
                            fontSize: 12,
                            color: t.ember,
                            height: 1.4,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (_updateState == _UpdateState.checking)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: t.ink3,
                    ),
                  )
                else if (_updateState == _UpdateState.available)
                  Icon(Icons.download_rounded, size: 18, color: t.sage)
                else
                  Icon(Icons.chevron_right_rounded, size: 18, color: t.ink3),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Action row ────────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.t,
    required this.icon,
    required this.label,
    this.subtitle,
    this.isLast = false,
    required this.onTap,
  });
  final AppTokens t;
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: t.ink,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
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
            Icon(icon, size: 18, color: t.ink3),
          ],
        ),
      ),
    );
  }
}

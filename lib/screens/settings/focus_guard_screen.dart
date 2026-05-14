import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/settings_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../services/focus_guard_service.dart';

class FocusGuardScreen extends StatelessWidget {
  const FocusGuardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: _AppBar(t: t),
      body: Consumer2<SettingsController, FocusGuardService>(
        builder: (context, settings, guard, _) =>
            _Body(t: t, settings: settings, guard: guard),
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
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: t.ink),
          ),
        ),
      ),
      title: Text(
        'Focus guard',
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

class _Body extends StatelessWidget {
  const _Body({required this.t, required this.settings, required this.guard});
  final AppTokens t;
  final SettingsController settings;
  final FocusGuardService guard;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        // Hero description card
        _HeroCard(t: t),
        const SizedBox(height: 24),

        // Enable toggle
        _SectionLabel(t: t, label: 'CAMERA ACCESS'),
        const SizedBox(height: 10),
        _EnableTile(t: t, settings: settings, guard: guard),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Requires camera permission. No video is recorded or stored — '
            'only a snapshot is taken every 5 seconds for analysis.',
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 12,
              color: t.ink3,
              height: 1.5,
            ),
          ),
        ),

        // Status indicator when active
        if (settings.focusGuardEnabled) ...[
          const SizedBox(height: 24),
          _SectionLabel(t: t, label: 'WHAT IT DETECTS'),
          const SizedBox(height: 10),
          _DetectList(t: t),
          const SizedBox(height: 24),
          _SectionLabel(t: t, label: 'HOW IT WORKS'),
          const SizedBox(height: 10),
          _HowItWorksCard(t: t),
          if (!guard.isModelLoaded) ...[
            const SizedBox(height: 20),
            _ModelNotReadyBanner(t: t, guard: guard),
          ],
        ],
      ],
    );
  }
}

// ── Hero card ─────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.t});
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.pop.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.pop.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: t.pop.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.visibility_rounded, size: 20, color: t.pop),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stay accountable',
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Focus guard uses on-device AI to pause your session '
                  'if you walk away or pick up your phone — keeping you honest.',
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 13,
                    color: t.ink2,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Enable tile ───────────────────────────────────────────────────────────────

class _EnableTile extends StatefulWidget {
  const _EnableTile({required this.t, required this.settings, required this.guard});
  final AppTokens t;
  final SettingsController settings;
  final FocusGuardService guard;

  @override
  State<_EnableTile> createState() => _EnableTileState();
}

class _EnableTileState extends State<_EnableTile> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final enabled = widget.settings.focusGuardEnabled;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: enabled ? t.pop.withValues(alpha: 0.5) : t.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              enabled ? Icons.camera_alt_rounded : Icons.camera_alt_outlined,
              size: 20,
              color: enabled ? t.pop : t.ink3,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enable focus guard',
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: t.ink,
                    ),
                  ),
                  Text(
                    enabled
                        ? (widget.guard.isModelLoaded ? 'Active · AI model ready' : 'Loading model…')
                        : 'Off',
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 10,
                      color: enabled ? t.pop : t.ink3,
                      letterSpacing: 0.08,
                    ),
                  ),
                ],
              ),
            ),
            if (_loading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: t.pop,
                ),
              )
            else
              GestureDetector(
                onTap: () => _toggle(context),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 26,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: enabled ? t.pop : t.surface2,
                    border: Border.all(
                      color: enabled ? t.pop : t.border,
                    ),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    alignment:
                        enabled ? Alignment.centerRight : Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: enabled ? t.ink : t.ink3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(BuildContext context) async {
    final guard = widget.guard;
    final settings = widget.settings;
    final enabling = !settings.focusGuardEnabled;

    if (enabling) {
      setState(() => _loading = true);
      final ok = await guard.initialize();
      setState(() => _loading = false);
      if (!ok && context.mounted) {
        _showPermissionError(context);
        return;
      }
    }

    settings.focusGuardEnabled = enabling;
  }

  void _showPermissionError(BuildContext context) {
    final t = widget.t;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Camera permission needed',
          style: TextStyle(fontFamily: AppFonts.ui, color: t.ink, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Please allow camera access in System Settings → Privacy & Security → Camera.',
          style: TextStyle(fontFamily: AppFonts.ui, color: t.ink2, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: t.pop, fontFamily: AppFonts.ui)),
          ),
        ],
      ),
    );
  }
}

// ── Detect list ───────────────────────────────────────────────────────────────

class _DetectList extends StatelessWidget {
  const _DetectList({required this.t});
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border),
      ),
      child: Column(
        children: [
          _DetectRow(
            t: t,
            emoji: '🚶',
            label: 'You leave your desk',
            sublabel: 'No person detected for 5 s',
            isLast: false,
          ),
          Divider(color: t.border, height: 1, indent: 54),
          _DetectRow(
            t: t,
            emoji: '📱',
            label: 'Phone in view',
            sublabel: 'Cell phone detected for 5 s',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _DetectRow extends StatelessWidget {
  const _DetectRow({
    required this.t,
    required this.emoji,
    required this.label,
    required this.sublabel,
    required this.isLast,
  });
  final AppTokens t;
  final String emoji;
  final String label;
  final String sublabel;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 14),
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
                Text(
                  sublabel,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 10,
                    color: t.ink3,
                    letterSpacing: 0.08,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.pause_circle_outline_rounded, size: 18, color: t.ink3),
        ],
      ),
    );
  }
}

// ── How it works card ─────────────────────────────────────────────────────────

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard({required this.t});
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.dim,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HowRow(t: t, step: '1', text: 'Camera captures a snapshot every 5 seconds during focus'),
          _HowRow(t: t, step: '2', text: 'On-device YOLO model runs — nothing leaves your device'),
          _HowRow(t: t, step: '3', text: 'Timer pauses if you walk away or pick up your phone'),
          _HowRow(t: t, step: '4', text: 'Timer resumes automatically when you return', isLast: true),
        ],
      ),
    );
  }
}

class _HowRow extends StatelessWidget {
  const _HowRow({required this.t, required this.step, required this.text, this.isLast = false});
  final AppTokens t;
  final String step;
  final String text;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.surface,
              border: Border.all(color: t.border),
            ),
            child: Center(
              child: Text(
                step,
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 9,
                  color: t.ink3,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 13,
                color: t.ink2,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Model not ready banner ────────────────────────────────────────────────────

class _ModelNotReadyBanner extends StatefulWidget {
  const _ModelNotReadyBanner({required this.t, required this.guard});
  final AppTokens t;
  final FocusGuardService guard;

  @override
  State<_ModelNotReadyBanner> createState() => _ModelNotReadyBannerState();
}

class _ModelNotReadyBannerState extends State<_ModelNotReadyBanner> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.ember.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.ember.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: t.ember),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'AI model not loaded. Tap to retry.',
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 13,
                color: t.ink2,
              ),
            ),
          ),
          if (_loading)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: t.ember),
            )
          else
            GestureDetector(
              onTap: _retry,
              child: Text(
                'Retry',
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 13,
                  color: t.ember,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _retry() async {
    setState(() => _loading = true);
    await widget.guard.initialize();
    if (mounted) setState(() => _loading = false);
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

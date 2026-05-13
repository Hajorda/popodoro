import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/settings_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../models/pomodoro_state.dart';
import '../../widgets/mascot/pop_mascot.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

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
      title: Text('Appearance',
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

        // Pop preview
        _PopPreview(t: t),
        const SizedBox(height: 22),

        // Theme mode
        _Label(t: t, label: 'Mode'),
        _ThemeCards(t: t, settings: settings),
        const SizedBox(height: 22),

        // Timer style
        _Label(t: t, label: 'Timer style'),
        _TimerStyleGrid(t: t, settings: settings),
      ],
    );
  }
}

// ── Pop preview ───────────────────────────────────────────────────────────────

class _PopPreview extends StatelessWidget {
  const _PopPreview({required this.t});
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: t.border),
      ),
      child: Column(
        children: [
          PopMascot(
            size: 96,
            mood: PopMood.hi,
            accentColor: t.pop,
            bumpColor: t.bump,
            bumpEdgeColor: t.bumpEdge,
            inkColor: t.ink,
          ),
          const SizedBox(height: 10),
          Text('Preview', style: TextStyle(fontFamily: AppFonts.display, fontSize: 20, color: t.ink, letterSpacing: -0.2)),
          const SizedBox(height: 2),
          Text('YOUR POP, RIGHT NOW', style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9, color: t.ink3, letterSpacing: 0.14)),
        ],
      ),
    );
  }
}

// ── Theme mode cards ──────────────────────────────────────────────────────────

class _ThemeCards extends StatelessWidget {
  const _ThemeCards({required this.t, required this.settings});
  final AppTokens t;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    const options = [
      _ThemeOpt(mode: ThemeMode.light, label: 'Light', lightBg: Color(0xFFFBF8F2), darkBg: Color(0xFFFBF8F2)),
      _ThemeOpt(mode: ThemeMode.dark, label: 'Dark', lightBg: Color(0xFF14120F), darkBg: Color(0xFF14120F)),
      _ThemeOpt(mode: ThemeMode.system, label: 'Auto', lightBg: Color(0xFFFBF8F2), darkBg: Color(0xFF14120F)),
    ];

    return Row(
      children: options.map((opt) {
        final on = settings.themeMode == opt.mode;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => settings.themeMode = opt.mode,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: on ? t.pop : t.border, width: on ? 2 : 1),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // preview swatch
                    SizedBox(
                      height: 64,
                      child: opt.mode == ThemeMode.system
                          ? Row(children: [
                              Expanded(child: Container(color: opt.lightBg)),
                              Expanded(child: Container(color: opt.darkBg)),
                            ])
                          : Container(color: opt.lightBg),
                    ),
                    Container(
                      color: t.surface,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        opt.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 12,
                          color: t.ink,
                          fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                        ),
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

class _ThemeOpt {
  const _ThemeOpt({required this.mode, required this.label, required this.lightBg, required this.darkBg});
  final ThemeMode mode;
  final String label;
  final Color lightBg;
  final Color darkBg;
}

// ── Timer style grid ──────────────────────────────────────────────────────────

class _TimerStyleGrid extends StatelessWidget {
  const _TimerStyleGrid({required this.t, required this.settings});
  final AppTokens t;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final options = TimerAppearance.values;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.8,
      children: options.map((opt) {
        final on = settings.timerAppearance == opt;
        return GestureDetector(
          onTap: () => settings.timerAppearance = opt,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: on ? t.pop : t.border, width: on ? 2 : 1),
            ),
            child: Row(
              children: [
                _TimerThumb(t: t, kind: opt),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(opt.label, style: TextStyle(fontFamily: AppFonts.ui, fontSize: 13, color: t.ink, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(on ? 'SELECTED' : '',
                          style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9, color: t.pop, letterSpacing: 0.06)),
                    ],
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

class _TimerThumb extends StatelessWidget {
  const _TimerThumb({required this.t, required this.kind});
  final AppTokens t;
  final TimerAppearance kind;

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case TimerAppearance.ring:
        return SizedBox(
          width: 36,
          height: 36,
          child: CustomPaint(painter: _RingThumbPainter(track: t.surface2, fill: t.pop)),
        );

      case TimerAppearance.dots:
        return SizedBox(
          width: 36,
          height: 36,
          child: Wrap(
            spacing: 3,
            runSpacing: 3,
            children: List.generate(16, (i) => Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < 7 ? t.pop : t.surface2,
              ),
            )),
          ),
        );

      case TimerAppearance.kernel:
        return PopMascot(
          size: 36,
          mood: PopMood.working,
          accentColor: t.pop,
          bumpColor: t.bump,
          bumpEdgeColor: t.bumpEdge,
          inkColor: t.ink,
        );

      case TimerAppearance.numerals:
        return Text(
          '14:32',
          style: TextStyle(fontFamily: AppFonts.display, fontSize: 20, color: t.ink, letterSpacing: -1, height: 1),
        );
    }
  }
}

class _RingThumbPainter extends CustomPainter {
  const _RingThumbPainter({required this.track, required this.fill});
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 3;
    const stroke = 4.0;
    canvas.drawCircle(c, r, Paint()..color = track..style = PaintingStyle.stroke..strokeWidth = stroke);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -1.57, // -90deg
      3.8,   // ~220deg fill
      false,
      Paint()..color = fill..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingThumbPainter old) => false;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

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

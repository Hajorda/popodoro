import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/timer_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../models/pomodoro_state.dart';
import '../../services/sound_service.dart';
import '../../services/window_service.dart';
import '../../widgets/mascot/pop_mascot.dart';
import '../../widgets/common/pop_button.dart';

class BreakScreen extends StatelessWidget {
  const BreakScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Consumer<TimerController>(
          builder: (context, timer, _) => _BreakContent(timer: timer, t: t),
        ),
      ),
    );
  }
}

class _BreakContent extends StatelessWidget {
  const _BreakContent({required this.timer, required this.t});

  final TimerController timer;
  final AppTokens t;

  bool get _isLong => timer.phase == TimerPhase.longBreak;

  Color get _accentColor => _isLong ? t.lavender : t.sage;

  @override
  Widget build(BuildContext context) {
    final isRunning = timer.status == TimerStatus.running;
    final isPaused = timer.status == TimerStatus.paused;
    final isIdle = timer.status == TimerStatus.idle;

    return Stack(
      children: [
        Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        // Phase pill
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _accentColor.withValues(alpha: 0.35)),
            ),
            child: Text(
              _isLong ? 'LONG BREAK' : 'SHORT BREAK',
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 10,
                letterSpacing: 0.12,
                color: _isLong ? t.lavender : t.sage,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const Spacer(flex: 2),
        // Pop mascot (resting)
        Center(
          child: PopMascot(
            size: 130,
            mood: PopMood.resting,
            accentColor: t.pop,
            bumpColor: t.bump,
            bumpEdgeColor: t.bumpEdge,
            inkColor: t.ink,
          ),
        ),
        const SizedBox(height: 28),
        // Headline
        Text(
          _isLong ? 'well earned.' : 'take five.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontSize: 36,
            color: t.ink,
            height: 1.05,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _isLong
              ? 'You knocked out a full round. Step away.'
              : 'Short recharge. Back soon.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 14,
            color: t.ink2,
            height: 1.4,
          ),
        ),
        const Spacer(flex: 2),
        // Timer display
        Text(
          timer.timeDisplay,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 64,
            fontWeight: FontWeight.w700,
            color: t.ink,
            height: 1.0,
            letterSpacing: -2,
          ),
        ),
        const SizedBox(height: 8),
        // Thin accent progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: _ProgressBar(
            progress: timer.progress,
            color: _accentColor,
            trackColor: t.surface2,
          ),
        ),
        const Spacer(flex: 3),
        // Action buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isRunning || isPaused) ...[
                PopButton(
                  label: isRunning ? '⏸ Pause' : '▶ Resume',
                  variant: PopButtonVariant.secondary,
                  small: true,
                  onPressed: () {
                    context.read<SoundService>().playSwitch();
                    isRunning ? timer.pause() : timer.start();
                  },
                  inkColor: t.ink,
                  bgColor: t.bg,
                  surfaceColor: t.surface,
                  borderColor: t.border,
                  ink2Color: t.ink2,
                ),
                const SizedBox(width: 10),
              ],
              if (isIdle)
                PopButton(
                  label: 'Start break',
                  variant: PopButtonVariant.primary,
                  onPressed: () {
                    context.read<SoundService>().playSwitch();
                    timer.start();
                  },
                  inkColor: t.ink,
                  bgColor: t.bg,
                  surfaceColor: t.surface,
                  borderColor: t.border,
                  ink2Color: t.ink2,
                ),
              if (isRunning || isPaused)
                PopButton(
                  label: 'Skip break →',
                  variant: PopButtonVariant.ghost,
                  small: true,
                  onPressed: () {
                    context.read<SoundService>().playSwitch();
                    timer.skipPhase();
                  },
                  inkColor: t.ink,
                  bgColor: t.bg,
                  surfaceColor: t.surface,
                  borderColor: t.border,
                  ink2Color: t.ink2,
                ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
        ),
        // Mini mode button — top right
        Positioned(
          top: 12,
          right: 16,
          child: GestureDetector(
            onTap: () => context.read<WindowService>().enterMiniMode(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.surface,
                border: Border.all(color: t.border),
              ),
              child: Icon(Icons.picture_in_picture_alt_rounded, size: 16, color: t.ink2),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 4,
        color: trackColor,
        child: FractionallySizedBox(
          widthFactor: progress.clamp(0.0, 1.0),
          alignment: Alignment.centerLeft,
          child: Container(color: color),
        ),
      ),
    );
  }
}

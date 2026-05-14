import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_typography.dart';

import '../../controllers/settings_controller.dart';
import '../../controllers/timer_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/pomodoro_state.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/today/today_screen.dart';
import '../../screens/together/buddies_screen.dart';
import '../../services/sound_service.dart';
import '../../services/window_service.dart';
import '../../widgets/mascot/pop_mascot.dart';
import '../../widgets/mascot/pop_wordmark.dart';
import '../../widgets/timer/timer_display.dart';
import '../../widgets/common/pop_button.dart';
import '../../widgets/common/nudge_card.dart';
import '../../widgets/sheets/task_input_sheet.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Consumer<TimerController>(
          builder: (context, timer, _) => _HomeContent(timer: timer, t: t),
        ),
      ),
    );
  }
}

// ── Full home content ─────────────────────────────────────────────────────────

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.timer, required this.t});

  final TimerController timer;
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    final isFocusIdle =
        timer.status == TimerStatus.idle && timer.phase == TimerPhase.focus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopBar(t: t),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
          child: _GreetingRow(t: t, timer: timer),
        ),
        const SizedBox(height: 12),
        if (isFocusIdle)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: NudgeCard(
              message: "You're usually a beast at 10:14 am. Want to pop one?",
              highlightedTime: '10:14 am',
              surfaceColor: t.surface,
              borderColor: t.border,
              accentColor: t.pop,
              inkColor: t.ink,
              ink2Color: t.ink2,
            ),
          ),
        const SizedBox(height: 4),
        Expanded(child: _TimerCenter(timer: timer, t: t)),
        _SessionInfo(timer: timer, t: t),
        const SizedBox(height: 20),
        _ActionRow(timer: timer, t: t),
        const SizedBox(height: 28),
      ],
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.t});

  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          PopWordmark(fontSize: 24, color: t.ink, accentColor: t.pop),
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const TodayScreen()),
                ),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.surface,
                    border: Border.all(color: t.border),
                  ),
                  child: Icon(Icons.today_rounded, size: 16, color: t.ink2),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const BuddiesScreen()),
                ),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.surface,
                    border: Border.all(color: t.border),
                  ),
                  child: Icon(Icons.people_rounded, size: 16, color: t.ink2),
                ),
              ),
              if (WindowService.isDesktop) ...[
                const SizedBox(width: 8),
                GestureDetector(
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
              ],
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
                ),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.surface,
                    border: Border.all(color: t.border),
                  ),
                  child: Icon(Icons.tune_rounded, size: 16, color: t.ink2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Greeting row ──────────────────────────────────────────────────────────────

class _GreetingRow extends StatelessWidget {
  const _GreetingRow({required this.t, required this.timer});

  final AppTokens t;
  final TimerController timer;

  PopMood get _mood {
    if (timer.status == TimerStatus.complete) return PopMood.celebrating;
    switch (timer.phase) {
      case TimerPhase.focus:
        return timer.status == TimerStatus.running ? PopMood.working : PopMood.hi;
      case TimerPhase.shortBreak:
      case TimerPhase.longBreak:
        return PopMood.resting;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          PopMascot(
            size: 44,
            mood: _mood,
            accentColor: t.pop,
            bumpColor: t.bump,
            bumpEdgeColor: t.bumpEdge,
            inkColor: t.ink,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _dateLabel(),
                style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: t.ink3, letterSpacing: 0.08),
              ),
              Text(
                _greeting(),
                style: TextStyle(fontFamily: AppFonts.display, fontSize: 22, color: t.ink, height: 1.1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _greeting() {
    if (timer.status == TimerStatus.complete) return 'nice work!';
    switch (timer.phase) {
      case TimerPhase.focus:
        return timer.status == TimerStatus.running ? 'in the zone.' : 'ready when you are.';
      case TimerPhase.shortBreak:
        return 'take five.';
      case TimerPhase.longBreak:
        return 'well earned.';
    }
  }

  String _dateLabel() {
    final now = DateTime.now();
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return '${days[now.weekday - 1]} · ${months[now.month - 1]} ${now.day}';
  }
}

// ── Timer center ──────────────────────────────────────────────────────────────

class _TimerCenter extends StatelessWidget {
  const _TimerCenter({required this.timer, required this.t});

  final TimerController timer;
  final AppTokens t;

  Color get _accentColor {
    switch (timer.phase) {
      case TimerPhase.focus: return t.pop;
      case TimerPhase.shortBreak: return t.sage;
      case TimerPhase.longBreak: return t.lavender;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appearance = context.read<SettingsController>().timerAppearance;
    return LayoutBuilder(builder: (context, c) {
      final size = (c.maxWidth * 0.78).clamp(200.0, 320.0);
      return Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
          child: KeyedSubtree(
            key: ValueKey(appearance),
            child: TimerDisplay(
              appearance: appearance,
              progress: timer.progress,
              timeDisplay: timer.timeDisplay,
              sessionLabel: timer.sessionDisplay,
              taskName: timer.taskName.isNotEmpty ? timer.taskName : null,
              ringColor: _accentColor,
              trackColor: t.surface2,
              inkColor: t.ink,
              ink2Color: t.ink2,
              ink3Color: t.ink3,
              surfaceColor: t.surface,
              borderColor: t.border,
              bumpColor: t.bump,
              bumpEdgeColor: t.bumpEdge,
              size: size,
              strokeWidth: size * 0.045,
            ),
          ),
        ),
      );
    });
  }
}

// ── Session info ──────────────────────────────────────────────────────────────

class _SessionInfo extends StatelessWidget {
  const _SessionInfo({required this.timer, required this.t});

  final TimerController timer;
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          timer.sessionDisplay,
          style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: t.ink3, letterSpacing: 0.14),
          textAlign: TextAlign.center,
        ),
        if (timer.taskName.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              timer.taskName,
              style: TextStyle(fontFamily: AppFonts.display, 
                fontSize: 18,
                color: t.ink,
                fontStyle: FontStyle.italic,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

// ── Action row ────────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.timer, required this.t});

  final TimerController timer;
  final AppTokens t;

  void _onPrimary(BuildContext context) {
    final snd = context.read<SoundService>();
    final isIdle = timer.status == TimerStatus.idle;
    final isComplete = timer.status == TimerStatus.complete;

    if ((isIdle || isComplete) && timer.phase == TimerPhase.focus) {
      // Task sheet plays its own switch sound on confirm
      showTaskInputSheet(context);
    } else if (isIdle || isComplete) {
      snd.playSwitch();
      timer.start();
    } else {
      snd.playSwitch();
      timer.skipPhase();
    }
  }

  String get _primaryLabel {
    final isIdle = timer.status == TimerStatus.idle;
    final isComplete = timer.status == TimerStatus.complete;
    if (isIdle || isComplete) {
      return timer.phase == TimerPhase.focus ? 'Start focus' : 'Start break';
    }
    return 'End';
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = timer.status == TimerStatus.running;
    final isPaused = timer.status == TimerStatus.paused;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
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
          PopButton(
            label: _primaryLabel,
            variant: PopButtonVariant.primary,
            onPressed: () => _onPrimary(context),
            inkColor: t.ink,
            bgColor: t.bg,
            surfaceColor: t.surface,
            borderColor: t.border,
            ink2Color: t.ink2,
          ),
          if (isRunning && timer.phase == TimerPhase.focus) ...[
            const SizedBox(width: 10),
            PopButton(
              label: '+ 5',
              variant: PopButtonVariant.secondary,
              small: true,
              onPressed: () {
                context.read<SoundService>().playSwitch();
                timer.addMinutes(5);
              },
              inkColor: t.ink,
              bgColor: t.bg,
              surfaceColor: t.surface,
              borderColor: t.border,
              ink2Color: t.ink2,
            ),
          ],
        ],
      ),
    );
  }
}

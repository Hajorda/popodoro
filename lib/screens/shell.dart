import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/timer_controller.dart';
import '../models/pomodoro_state.dart';
import '../services/window_service.dart';
import '../widgets/pip/mini_timer_pill.dart';
import 'break/break_screen.dart';
import 'complete/session_complete_screen.dart';
import 'home/home_screen.dart';

// Top-level screen router. Watches WindowService (mini mode) and TimerController
// and swaps between the four surfaces: MiniTimerPill, Home, Break, SessionComplete.
class PopodoroShell extends StatelessWidget {
  const PopodoroShell({super.key});

  @override
  Widget build(BuildContext context) {
    final windowService = context.watch<WindowService>();

    // Mini mode short-circuits all other routing — always show the pill.
    if (windowService.isMiniMode) {
      return const MiniTimerPill();
    }

    return Consumer<TimerController>(
      builder: (context, timer, _) {
        final Widget screen;
        final String key;

        if (timer.awaitingCycleAck) {
          screen = const SessionCompleteScreen();
          key = 'complete';
        } else if (timer.phase == TimerPhase.shortBreak ||
            timer.phase == TimerPhase.longBreak) {
          screen = const BreakScreen();
          key = 'break-${timer.phase.name}';
        } else {
          screen = const HomeScreen();
          key = 'home';
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(key: ValueKey(key), child: screen),
        );
      },
    );
  }
}

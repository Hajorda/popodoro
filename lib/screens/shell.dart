import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/timer_controller.dart';
import '../models/pomodoro_state.dart';
import '../services/together_service.dart';
import '../services/window_service.dart';
import '../widgets/pip/mini_timer_pill.dart';
import 'break/break_screen.dart';
import 'complete/session_complete_screen.dart';
import 'home/home_screen.dart';

// Top-level screen router. Watches WindowService (mini mode) and TimerController
// and swaps between the four surfaces: MiniTimerPill, Home, Break, SessionComplete.
//
// It also owns the reactive "auto-exit mini mode when a session finishes" rule:
// it listens to TimerController and TogetherService, and when either signals a
// finished session it calls WindowService.exitMiniMode() so the floating PiP
// window is never left stranded on screen.
class PopodoroShell extends StatefulWidget {
  const PopodoroShell({super.key});

  @override
  State<PopodoroShell> createState() => _PopodoroShellState();
}

class _PopodoroShellState extends State<PopodoroShell> {
  TimerController? _timer;
  TogetherService? _together;
  WindowService? _windowService;

  // Previous-frame snapshots so we can detect *transitions* (edges) rather than
  // steady states. This keeps the auto-exit one-shot per finish.
  TimerStatus? _prevTimerStatus;
  bool _prevAwaitingCycleAck = false;
  bool _prevRoomComplete = false;
  TimerPhase? _prevPhase;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final timer = context.read<TimerController>();
    final together = context.read<TogetherService>();
    _windowService = context.read<WindowService>();

    if (!identical(timer, _timer)) {
      _timer?.removeListener(_onTimerChanged);
      _timer = timer;
      _timer!.addListener(_onTimerChanged);
      _prevTimerStatus = timer.status;
      _prevAwaitingCycleAck = timer.awaitingCycleAck;
      _prevPhase = timer.phase;
    }

    if (!identical(together, _together)) {
      _together?.removeListener(_onTogetherChanged);
      _together = together;
      _together!.addListener(_onTogetherChanged);
      _prevRoomComplete = together.room?.isComplete ?? false;
    }
  }

  // Solo timer finished: a running phase ended without auto-starting the next
  // one (status running -> idle/complete), or the cycle-complete gate engaged
  // (awaitingCycleAck rose). Either way the pill has nothing actionable, so we
  // pop back to the full window.
  void _onTimerChanged() {
    final timer = _timer;
    if (timer == null) return;

    final status = timer.status;
    final awaiting = timer.awaitingCycleAck;
    final phase = timer.phase;

    final stoppedRunning = _prevTimerStatus == TimerStatus.running &&
        (status == TimerStatus.idle || status == TimerStatus.complete);
    final cycleJustCompleted = awaiting && !_prevAwaitingCycleAck;

    if (stoppedRunning || cycleJustCompleted) {
      _exitMiniModeIfActive();
    }

    // Apply per-phase window opacity when the phase changes in mini mode.
    if (phase != _prevPhase) {
      _windowService?.applyPhaseOpacity(phase);
    }

    _prevTimerStatus = status;
    _prevAwaitingCycleAck = awaiting;
    _prevPhase = phase;
  }

  // Together co-focus room reached `complete`: the shared session is over, so
  // get the user out of the floating pill.
  void _onTogetherChanged() {
    final roomComplete = _together?.room?.isComplete ?? false;
    if (roomComplete && !_prevRoomComplete) {
      _exitMiniModeIfActive();
    }
    _prevRoomComplete = roomComplete;
  }

  // Guarded + idempotent: only acts while in mini mode; exitMiniMode itself also
  // no-ops when already in full mode.
  void _exitMiniModeIfActive() {
    final ws = _windowService;
    if (ws != null && ws.isMiniMode) {
      ws.exitMiniMode();
    }
  }

  @override
  void dispose() {
    _timer?.removeListener(_onTimerChanged);
    _together?.removeListener(_onTogetherChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final windowService = context.watch<WindowService>();

    final Widget body;
    // Mini mode short-circuits all other routing — always show the pill.
    if (windowService.isMiniMode) {
      body = const MiniTimerPill();
    } else {
      body = Consumer<TimerController>(
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

    // Desktop shortcut: Esc exits the floating mini/PiP window. We guard on
    // isMiniMode so Esc is a no-op in the full window (and exitMiniMode itself
    // is idempotent). The Focus is non-autofocusing to avoid fighting the home
    // body's autofocus Focus when in full mode; Esc still reaches the binding
    // via focus traversal / the focused descendant.
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (windowService.isMiniMode) {
            windowService.exitMiniMode();
          }
        },
      },
      child: Focus(
        child: body,
      ),
    );
  }
}

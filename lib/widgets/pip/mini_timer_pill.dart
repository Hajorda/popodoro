import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../../controllers/timer_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../models/pomodoro_state.dart';
import '../../services/together_service.dart';
import '../../services/window_service.dart';

// Compact always-on-top overlay shown in mini (PiP) mode.
// Fills the 240×80 window completely. Draggable via native window drag.
class MiniTimerPill extends StatelessWidget {
  const MiniTimerPill({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final together = context.watch<TogetherService>();
    final windowService = context.read<WindowService>();

    // Co-focus session takes over the pill display.
    final room = together.room;
    final inCoFocus = together.isInRoom && room != null && (room.isFocusing || room.isOnBreak);

    if (inCoFocus) {
      final dotColor = room.isOnBreak ? t.sage : t.pop;
      final label = room.isOnBreak ? 'SHORT BREAK' : 'TOGETHER';

      return GestureDetector(
        onPanStart: (_) => windowManager.startDragging(),
        child: Material(
          color: t.bg,
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: t.border, width: 0.5)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
                ),
                const SizedBox(width: 10),
                Text(
                  room.timeDisplay,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: t.ink,
                    letterSpacing: -1,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 9,
                      letterSpacing: 0.12,
                      color: t.ink3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _PillIconButton(
                  icon: Icons.open_in_full_rounded,
                  color: t.ink3,
                  onTap: () => windowService.exitMiniMode(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Solo timer pill.
    final timer = context.watch<TimerController>();
    final isRunning = timer.status == TimerStatus.running;

    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Material(
        color: t.bg,
        child: Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: t.border, width: 0.5)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _PhaseDot(phase: timer.phase, t: t),
              const SizedBox(width: 10),
              Text(
                timer.timeDisplay,
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: t.ink,
                  letterSpacing: -1,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  timer.phase.labelUpper,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 9,
                    letterSpacing: 0.12,
                    color: t.ink3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _PillIconButton(
                icon: isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: t.ink2,
                onTap: () {
                  if (isRunning) {
                    timer.pause();
                  } else {
                    timer.start();
                  }
                },
              ),
              const SizedBox(width: 2),
              _PillIconButton(
                icon: Icons.open_in_full_rounded,
                color: t.ink3,
                onTap: () => windowService.exitMiniMode(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhaseDot extends StatelessWidget {
  const _PhaseDot({required this.phase, required this.t});

  final TimerPhase phase;
  final AppTokens t;

  Color get _color {
    switch (phase) {
      case TimerPhase.focus: return t.pop;
      case TimerPhase.shortBreak: return t.sage;
      case TimerPhase.longBreak: return t.lavender;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 8,
      height: 8,
      decoration: BoxDecoration(shape: BoxShape.circle, color: _color),
    );
  }
}

class _PillIconButton extends StatelessWidget {
  const _PillIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 30,
        height: 30,
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

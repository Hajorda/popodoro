enum TimerPhase { focus, shortBreak, longBreak }

enum TimerStatus { idle, running, paused, complete }

extension TimerPhaseX on TimerPhase {
  String get label {
    switch (this) {
      case TimerPhase.focus: return 'focus';
      case TimerPhase.shortBreak: return 'short break';
      case TimerPhase.longBreak: return 'long break';
    }
  }

  String get labelUpper {
    switch (this) {
      case TimerPhase.focus: return 'FOCUS';
      case TimerPhase.shortBreak: return 'SHORT BREAK';
      case TimerPhase.longBreak: return 'LONG BREAK';
    }
  }
}

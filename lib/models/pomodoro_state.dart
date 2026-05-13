enum TimerPhase { focus, shortBreak, longBreak }

enum TimerAppearance { ring, dots, kernel, numerals }

extension TimerAppearanceX on TimerAppearance {
  String get label {
    switch (this) {
      case TimerAppearance.ring: return 'Ring';
      case TimerAppearance.dots: return 'Dots';
      case TimerAppearance.kernel: return 'Kernel';
      case TimerAppearance.numerals: return 'Numerals';
    }
  }
}

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

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/pomodoro_state.dart';
import 'settings_controller.dart';

class TimerController extends ChangeNotifier {
  TimerController({required this.settings, this.onFocusComplete}) {
    settings.addListener(_onSettingsChanged);
  }

  final SettingsController settings;

  // Fire-and-forget callback when a focus session ends (plays completion sound).
  final Future<void> Function()? onFocusComplete;

  TimerPhase _phase = TimerPhase.focus;
  TimerStatus _status = TimerStatus.idle;
  int _secondsRemaining = -1;
  int _completedSessions = 0;
  int _currentSession = 1;
  String _taskName = '';
  Timer? _ticker;

  // Set true when all N sessions in a cycle finish — holds state so the
  // SessionCompleteScreen can be shown before transitioning to long break.
  bool _awaitingCycleAck = false;

  // ── Getters ─────────────────────────────────────────────────────────────────

  TimerPhase get phase => _phase;
  TimerStatus get status => _status;
  String get taskName => _taskName;
  int get completedSessions => _completedSessions;
  int get currentSession => _currentSession;
  bool get awaitingCycleAck => _awaitingCycleAck;

  int get totalSecondsForPhase {
    switch (_phase) {
      case TimerPhase.focus: return settings.focusMinutes * 60;
      case TimerPhase.shortBreak: return settings.shortBreakMinutes * 60;
      case TimerPhase.longBreak: return settings.longBreakMinutes * 60;
    }
  }

  int get secondsRemaining {
    if (_secondsRemaining < 0) return totalSecondsForPhase;
    return _secondsRemaining;
  }

  double get progress {
    final total = totalSecondsForPhase;
    if (total == 0) return 0;
    return 1.0 - (secondsRemaining / total).clamp(0.0, 1.0);
  }

  String get timeDisplay {
    final secs = secondsRemaining;
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get sessionDisplay {
    final total = settings.sessionsBeforeLongBreak;
    return '${_phase.labelUpper} · ${_currentSession.toString().padLeft(2, '0')} / 0$total';
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  void start() {
    if (_status == TimerStatus.running) return;
    if (_secondsRemaining < 0) _secondsRemaining = totalSecondsForPhase;
    _status = TimerStatus.running;
    _ticker = Timer.periodic(const Duration(seconds: 1), _tick);
    notifyListeners();
  }

  void pause() {
    _ticker?.cancel();
    _status = TimerStatus.paused;
    notifyListeners();
  }

  void reset() {
    _ticker?.cancel();
    _status = TimerStatus.idle;
    _secondsRemaining = totalSecondsForPhase;
    notifyListeners();
  }

  void addMinutes(int minutes) {
    _secondsRemaining = (secondsRemaining + minutes * 60)
        .clamp(0, totalSecondsForPhase + minutes * 60);
    notifyListeners();
  }

  void setTask(String name) {
    _taskName = name.trim();
    notifyListeners();
  }

  void setCustomFocusMinutes(int minutes) {
    if (_status == TimerStatus.idle || _status == TimerStatus.complete) {
      _secondsRemaining = minutes * 60;
      notifyListeners();
    }
  }

  // User manually skips the current phase (bypasses cycle-complete gate).
  void skipPhase() {
    _ticker?.cancel();
    _advancePhase(autoStart: false, ignoreCycleGate: true);
    notifyListeners();
  }

  // Called when user taps the CTA on SessionCompleteScreen.
  void acknowledgeCycleComplete() {
    if (!_awaitingCycleAck) return;
    _awaitingCycleAck = false;
    // Phase and seconds are already set to longBreak; just decide whether to run.
    if (settings.autoStartBreaks) {
      _status = TimerStatus.running;
      _ticker = Timer.periodic(const Duration(seconds: 1), _tick);
    } else {
      _status = TimerStatus.idle;
    }
    notifyListeners();
  }

  // ── Internal ─────────────────────────────────────────────────────────────────

  void _tick(Timer _) {
    final current = secondsRemaining;
    if (current > 0) {
      _secondsRemaining = current - 1;
      notifyListeners();
    } else {
      _ticker?.cancel();
      _status = TimerStatus.complete;
      _advancePhase(autoStart: true);
      notifyListeners();
    }
  }

  void _advancePhase({required bool autoStart, bool ignoreCycleGate = false}) {
    final wasFocus = _phase == TimerPhase.focus;

    if (wasFocus) {
      _completedSessions++;
      _currentSession = _completedSessions + 1;
      final isCycleComplete =
          _completedSessions % settings.sessionsBeforeLongBreak == 0;
      _phase = isCycleComplete ? TimerPhase.longBreak : TimerPhase.shortBreak;
      _taskName = '';
      onFocusComplete?.call();

      // Gate: show cycle-complete screen before the long break starts.
      // Bypass if the user explicitly skipped (ignoreCycleGate) or
      // if this wasn't a full cycle.
      if (isCycleComplete && !ignoreCycleGate) {
        _awaitingCycleAck = true;
        _secondsRemaining = totalSecondsForPhase;
        _status = TimerStatus.idle;
        return;
      }
    } else {
      _phase = TimerPhase.focus;
    }

    _secondsRemaining = totalSecondsForPhase;

    final shouldAutoStart = autoStart &&
        (wasFocus ? settings.autoStartBreaks : settings.autoStartFocus);

    if (shouldAutoStart) {
      _status = TimerStatus.running;
      _ticker = Timer.periodic(const Duration(seconds: 1), _tick);
    } else {
      _status = TimerStatus.idle;
    }
  }

  void _onSettingsChanged() {
    if (_status != TimerStatus.running && _status != TimerStatus.paused) {
      _secondsRemaining = totalSecondsForPhase;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    settings.removeListener(_onSettingsChanged);
    _ticker?.cancel();
    super.dispose();
  }
}

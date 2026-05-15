import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pomodoro_state.dart';

enum DesktopTrayMode { off, icon, timer }

extension DesktopTrayModeX on DesktopTrayMode {
  String get label {
    switch (this) {
      case DesktopTrayMode.off:
        return 'Off';
      case DesktopTrayMode.icon:
        return 'Icon only';
      case DesktopTrayMode.timer:
        return 'Icon + timer';
    }
  }
}

// All user-configurable settings. Persisted to SharedPreferences immediately
// on every change so there's no explicit "save" step.
class SettingsController extends ChangeNotifier {
  SettingsController._({
    required SharedPreferences prefs,
    required int focusMinutes,
    required int shortBreakMinutes,
    required int longBreakMinutes,
    required int sessionsBeforeLongBreak,
    required bool soundEnabled,
    required bool autoStartBreaks,
    required bool autoStartFocus,
    required ThemeMode themeMode,
    required TimerAppearance timerAppearance,
    required DesktopTrayMode desktopTrayMode,
    required String bgSoundId,
    required double bgVolume,
    required bool focusGuardEnabled,
    required bool showGreeting,
    required bool showNudgeCard,
    required bool showProjectRow,
    required bool showSessionInfo,
  }) : _prefs = prefs,
       _focusMinutes = focusMinutes,
       _shortBreakMinutes = shortBreakMinutes,
       _longBreakMinutes = longBreakMinutes,
       _sessionsBeforeLongBreak = sessionsBeforeLongBreak,
       _soundEnabled = soundEnabled,
       _autoStartBreaks = autoStartBreaks,
       _autoStartFocus = autoStartFocus,
       _themeMode = themeMode,
       _timerAppearance = timerAppearance,
       _desktopTrayMode = desktopTrayMode,
       _bgSoundId = bgSoundId,
       _bgVolume = bgVolume,
       _focusGuardEnabled = focusGuardEnabled,
       _showGreeting = showGreeting,
       _showNudgeCard = showNudgeCard,
       _showProjectRow = showProjectRow,
       _showSessionInfo = showSessionInfo;

  // Load from disk. Call once before runApp.
  static Future<SettingsController> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsController._(
      prefs: prefs,
      focusMinutes: prefs.getInt(_kFocus) ?? 25,
      shortBreakMinutes: prefs.getInt(_kShort) ?? 5,
      longBreakMinutes: prefs.getInt(_kLong) ?? 15,
      sessionsBeforeLongBreak: prefs.getInt(_kSessions) ?? 4,
      soundEnabled: prefs.getBool(_kSound) ?? true,
      autoStartBreaks: prefs.getBool(_kAutoBreak) ?? false,
      autoStartFocus: prefs.getBool(_kAutoFocus) ?? false,
      themeMode: ThemeMode.values[prefs.getInt(_kTheme) ?? 0],
      timerAppearance:
          TimerAppearance.values[prefs.getInt(_kTimerAppearance) ?? 0],
      desktopTrayMode:
          DesktopTrayMode.values[prefs.getInt(_kDesktopTrayMode) ?? 0],
      bgSoundId: prefs.getString(_kBgSoundId) ?? '',
      bgVolume: prefs.getDouble(_kBgVolume) ?? 0.4,
      focusGuardEnabled: prefs.getBool(_kFocusGuard) ?? false,
      showGreeting: prefs.getBool(_kShowGreeting) ?? true,
      showNudgeCard: prefs.getBool(_kShowNudgeCard) ?? true,
      showProjectRow: prefs.getBool(_kShowProjectRow) ?? true,
      showSessionInfo: prefs.getBool(_kShowSessionInfo) ?? true,
    );
  }

  // ── Storage keys ─────────────────────────────────────────────────────────────
  static const _kFocus = 'focusMinutes';
  static const _kShort = 'shortBreakMinutes';
  static const _kLong = 'longBreakMinutes';
  static const _kSessions = 'sessionsBeforeLongBreak';
  static const _kSound = 'soundEnabled';
  static const _kAutoBreak = 'autoStartBreaks';
  static const _kAutoFocus = 'autoStartFocus';
  static const _kTheme = 'themeMode';
  static const _kTimerAppearance = 'timerAppearance';
  static const _kDesktopTrayMode = 'desktopTrayMode';
  static const _kBgSoundId = 'bgSoundId';
  static const _kBgVolume = 'bgVolume';
  static const _kFocusGuard = 'focusGuardEnabled';
  static const _kShowGreeting = 'showGreeting';
  static const _kShowNudgeCard = 'showNudgeCard';
  static const _kShowProjectRow = 'showProjectRow';
  static const _kShowSessionInfo = 'showSessionInfo';

  final SharedPreferences _prefs;

  // ── State ────────────────────────────────────────────────────────────────────
  int _focusMinutes;
  int _shortBreakMinutes;
  int _longBreakMinutes;
  int _sessionsBeforeLongBreak;
  bool _soundEnabled;
  bool _autoStartBreaks;
  bool _autoStartFocus;
  ThemeMode _themeMode;
  TimerAppearance _timerAppearance;
  DesktopTrayMode _desktopTrayMode;
  String _bgSoundId;
  double _bgVolume;
  bool _focusGuardEnabled;
  bool _showGreeting;
  bool _showNudgeCard;
  bool _showProjectRow;
  bool _showSessionInfo;

  // ── Getters ──────────────────────────────────────────────────────────────────
  SharedPreferences get prefs => _prefs;
  int get focusMinutes => _focusMinutes;
  int get shortBreakMinutes => _shortBreakMinutes;
  int get longBreakMinutes => _longBreakMinutes;
  int get sessionsBeforeLongBreak => _sessionsBeforeLongBreak;
  bool get soundEnabled => _soundEnabled;
  bool get autoStartBreaks => _autoStartBreaks;
  bool get autoStartFocus => _autoStartFocus;
  ThemeMode get themeMode => _themeMode;
  TimerAppearance get timerAppearance => _timerAppearance;
  DesktopTrayMode get desktopTrayMode => _desktopTrayMode;
  String get bgSoundId => _bgSoundId;
  double get bgVolume => _bgVolume;
  bool get focusGuardEnabled => _focusGuardEnabled;
  bool get showGreeting => _showGreeting;
  bool get showNudgeCard => _showNudgeCard;
  bool get showProjectRow => _showProjectRow;
  bool get showSessionInfo => _showSessionInfo;

  // Valid option sets used by the UI
  static const focusOptions = [15, 25, 50, 90];
  static const shortBreakOptions = [5, 10, 15];
  static const longBreakOptions = [15, 20, 30];
  static const sessionOptions = [2, 3, 4, 6];

  // ── Setters (persist on write) ────────────────────────────────────────────────
  set focusMinutes(int v) {
    if (_focusMinutes == v) return;
    _focusMinutes = v;
    _prefs.setInt(_kFocus, v);
    notifyListeners();
  }

  set shortBreakMinutes(int v) {
    if (_shortBreakMinutes == v) return;
    _shortBreakMinutes = v;
    _prefs.setInt(_kShort, v);
    notifyListeners();
  }

  set longBreakMinutes(int v) {
    if (_longBreakMinutes == v) return;
    _longBreakMinutes = v;
    _prefs.setInt(_kLong, v);
    notifyListeners();
  }

  set sessionsBeforeLongBreak(int v) {
    if (_sessionsBeforeLongBreak == v) return;
    _sessionsBeforeLongBreak = v;
    _prefs.setInt(_kSessions, v);
    notifyListeners();
  }

  set soundEnabled(bool v) {
    if (_soundEnabled == v) return;
    _soundEnabled = v;
    _prefs.setBool(_kSound, v);
    notifyListeners();
  }

  set autoStartBreaks(bool v) {
    if (_autoStartBreaks == v) return;
    _autoStartBreaks = v;
    _prefs.setBool(_kAutoBreak, v);
    notifyListeners();
  }

  set autoStartFocus(bool v) {
    if (_autoStartFocus == v) return;
    _autoStartFocus = v;
    _prefs.setBool(_kAutoFocus, v);
    notifyListeners();
  }

  set themeMode(ThemeMode v) {
    if (_themeMode == v) return;
    _themeMode = v;
    _prefs.setInt(_kTheme, v.index);
    notifyListeners();
  }

  set timerAppearance(TimerAppearance v) {
    if (_timerAppearance == v) return;
    _timerAppearance = v;
    _prefs.setInt(_kTimerAppearance, v.index);
    notifyListeners();
  }

  set desktopTrayMode(DesktopTrayMode v) {
    if (_desktopTrayMode == v) return;
    _desktopTrayMode = v;
    _prefs.setInt(_kDesktopTrayMode, v.index);
    notifyListeners();
  }

  set bgSoundId(String v) {
    if (_bgSoundId == v) return;
    _bgSoundId = v;
    _prefs.setString(_kBgSoundId, v);
    notifyListeners();
  }

  set bgVolume(double v) {
    if (_bgVolume == v) return;
    _bgVolume = v;
    _prefs.setDouble(_kBgVolume, v);
    notifyListeners();
  }

  set focusGuardEnabled(bool v) {
    if (_focusGuardEnabled == v) return;
    _focusGuardEnabled = v;
    _prefs.setBool(_kFocusGuard, v);
    notifyListeners();
  }

  set showGreeting(bool v) {
    if (_showGreeting == v) return;
    _showGreeting = v;
    _prefs.setBool(_kShowGreeting, v);
    notifyListeners();
  }

  set showNudgeCard(bool v) {
    if (_showNudgeCard == v) return;
    _showNudgeCard = v;
    _prefs.setBool(_kShowNudgeCard, v);
    notifyListeners();
  }

  set showProjectRow(bool v) {
    if (_showProjectRow == v) return;
    _showProjectRow = v;
    _prefs.setBool(_kShowProjectRow, v);
    notifyListeners();
  }

  set showSessionInfo(bool v) {
    if (_showSessionInfo == v) return;
    _showSessionInfo = v;
    _prefs.setBool(_kShowSessionInfo, v);
    notifyListeners();
  }
}

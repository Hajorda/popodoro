import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../models/pomodoro_state.dart';

class WindowService extends ChangeNotifier {
  WindowService({required SharedPreferences prefs}) : _prefs = prefs;

  final SharedPreferences _prefs;
  bool _isMiniMode = false;

  bool get isMiniMode => _isMiniMode;

  static bool get isDesktop =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows);

  static const Size miniSize = Size(240, 80);
  static const Size fullSize = Size(440, 680);

  static const _kMiniX = 'miniWindowX';
  static const _kMiniY = 'miniWindowY';

  // ── Opacity constants ───────────────────────────────────────────────────────
  // During break phases the pill dims slightly so it's less visually heavy.
  // Supported on macOS; on Windows setOpacity is a no-op.
  static const double _kFocusOpacity = 1.0;
  static const double _kBreakOpacity = 0.75;

  Future<void> enterMiniMode() async {
    if (!isDesktop) return;
    await windowManager.setResizable(false);
    await windowManager.setSkipTaskbar(true);
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    await windowManager.setMinimumSize(miniSize);
    await windowManager.setSize(miniSize);
    await windowManager.setAlwaysOnTop(true);
    await _restoreOrDefaultPosition();
    _isMiniMode = true;
    notifyListeners();
  }

  Future<void> exitMiniMode() async {
    if (!isDesktop) return;
    // Idempotent: callers (e.g. reactive listeners on session-finish) may fire
    // this more than once. Bail early if we're already in full mode so we don't
    // re-run window-manager calls or overwrite the saved mini position.
    if (!_isMiniMode) return;
    await _saveCurrentPosition();
    // Restore full opacity before expanding.
    await _setOpacity(_kFocusOpacity);
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setSkipTaskbar(false);
    await windowManager.setMinimumSize(const Size(300, 500));
    await windowManager.setSize(fullSize);
    await windowManager.setResizable(true);
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.center();
    _isMiniMode = false;
    notifyListeners();
  }

  // Called by the pill whenever the timer phase changes while in mini mode.
  // Dims the window during break phases so the pill is less visually heavy.
  Future<void> applyPhaseOpacity(TimerPhase phase) async {
    if (!isDesktop || !_isMiniMode) return;
    final opacity = (phase == TimerPhase.focus) ? _kFocusOpacity : _kBreakOpacity;
    await _setOpacity(opacity);
  }

  Future<void> _setOpacity(double opacity) async {
    try {
      await windowManager.setOpacity(opacity);
    } catch (_) {
      // setOpacity may throw on platforms where it's unsupported (e.g. some
      // Linux configurations). Swallow silently — opacity is purely cosmetic.
    }
  }

  Future<void> _saveCurrentPosition() async {
    try {
      final offset = await windowManager.getPosition();
      await _prefs.setDouble(_kMiniX, offset.dx);
      await _prefs.setDouble(_kMiniY, offset.dy);
    } catch (_) {}
  }

  Future<void> _restoreOrDefaultPosition() async {
    final x = _prefs.getDouble(_kMiniX);
    final y = _prefs.getDouble(_kMiniY);
    if (x != null && y != null) {
      await windowManager.setPosition(Offset(x, y));
    }
  }
}

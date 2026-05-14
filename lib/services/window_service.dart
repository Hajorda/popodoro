import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

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
    await _saveCurrentPosition();
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

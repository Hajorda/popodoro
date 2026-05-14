import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../controllers/settings_controller.dart';
import '../controllers/timer_controller.dart';
import 'together_service.dart';

class DesktopTrayService with WindowListener, TrayListener {
  SettingsController? _settings;
  TimerController? _timer;
  TogetherService? _together;
  Menu? _menu;

  bool _windowListenerAttached = false;
  bool _trayInitialized = false;
  bool _isQuittingFromTray = false;
  bool _isUpdatingTray = false;
  bool _pendingTrayUpdate = false;

  bool get _supportedPlatform =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows);

  DesktopTrayService bind({
    required SettingsController settings,
    required TimerController timer,
    required TogetherService together,
  }) {
    if (!_supportedPlatform) return this;

    if (!identical(_settings, settings)) {
      _settings?.removeListener(_onSettingsChanged);
      _settings = settings;
      settings.addListener(_onSettingsChanged);
    }

    if (!identical(_timer, timer)) {
      _timer?.removeListener(_onTimerChanged);
      _timer = timer;
      timer.addListener(_onTimerChanged);
    }

    if (!identical(_together, together)) {
      _together?.removeListener(_onTogetherChanged);
      _together = together;
      together.addListener(_onTogetherChanged);
    }

    _scheduleTrayUpdate();
    return this;
  }

  Future<void> _ensureTrayInitialized() async {
    if (_trayInitialized) return;

    await trayManager.setIcon(
      await _resolveIconAssetPath(),
      isTemplate: Platform.isMacOS,
    );
    trayManager.addListener(this);

    _menu = Menu(
      items: [
        MenuItem(key: 'show_window', label: 'Show Popodoro'),
        MenuItem(key: 'hide_window', label: 'Hide window'),
        MenuItem.separator(),
        MenuItem(key: 'quit_app', label: 'Quit Popodoro'),
      ],
    );
    await trayManager.setContextMenu(_menu!);

    if (!_windowListenerAttached) {
      windowManager.addListener(this);
      _windowListenerAttached = true;
    }

    _trayInitialized = true;
  }

  void _scheduleTrayUpdate() {
    if (_isUpdatingTray) {
      _pendingTrayUpdate = true;
      return;
    }

    _isUpdatingTray = true;
    unawaited(() async {
      do {
        _pendingTrayUpdate = false;
        await _applyTrayState();
      } while (_pendingTrayUpdate);
      _isUpdatingTray = false;
    }());
  }

  Future<void> _applyTrayState() async {
    final settings = _settings;
    final timer = _timer;
    if (settings == null || timer == null || !_supportedPlatform) return;

    final mode = settings.desktopTrayMode;
    final keepRunningInTray = mode != DesktopTrayMode.off;
    await windowManager.setPreventClose(keepRunningInTray);

    if (!keepRunningInTray) {
      if (_trayInitialized) {
        await trayManager.destroy();
        trayManager.removeListener(this);
        _trayInitialized = false;
      }
      return;
    }

    await _ensureTrayInitialized();

    // Prefer co-focus timer when actively in a together session.
    final together = _together;
    final room = together?.room;
    final inCoFocus = together != null &&
        together.isInRoom &&
        room != null &&
        (room.isFocusing || room.isOnBreak);

    final timeLabel = inCoFocus ? room.timeDisplay : timer.timeDisplay;

    await trayManager.setToolTip(_toolTipText(mode, timeLabel));
    if (Platform.isMacOS) {
      await trayManager.setTitle(
        mode == DesktopTrayMode.timer ? timeLabel : '',
      );
    }
  }

  String _toolTipText(DesktopTrayMode mode, String timeLabel) {
    if (mode == DesktopTrayMode.timer) {
      return 'Popodoro · $timeLabel';
    }
    return 'Popodoro';
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _hideWindow() async {
    await windowManager.hide();
  }

  Future<void> _toggleWindow() async {
    final visible = await windowManager.isVisible();
    if (visible) {
      await _hideWindow();
    } else {
      await _showWindow();
    }
  }

  Future<void> _quitFromTray() async {
    _isQuittingFromTray = true;
    await windowManager.setPreventClose(false);
    if (_trayInitialized) {
      await trayManager.destroy();
      trayManager.removeListener(this);
      _trayInitialized = false;
    }
    await windowManager.destroy();
  }

  void _onSettingsChanged() => _scheduleTrayUpdate();
  void _onTimerChanged() => _scheduleTrayUpdate();
  void _onTogetherChanged() => _scheduleTrayUpdate();

  @override
  Future<void> onWindowClose() async {
    if (!_supportedPlatform) return;

    final mode = _settings?.desktopTrayMode ?? DesktopTrayMode.off;
    if (_isQuittingFromTray || mode == DesktopTrayMode.off) {
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
      return;
    }

    await windowManager.hide();
  }

  @override
  void onTrayIconMouseDown() {
    if (Platform.isWindows) {
      unawaited(_toggleWindow());
    } else {
      unawaited(trayManager.popUpContextMenu());
    }
  }

  @override
  void onTrayIconRightMouseDown() {
    if (Platform.isWindows) {
      unawaited(trayManager.popUpContextMenu());
    } else {
      unawaited(_toggleWindow());
    }
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show_window':
        unawaited(_showWindow());
        break;
      case 'hide_window':
        unawaited(_hideWindow());
        break;
      case 'quit_app':
        unawaited(_quitFromTray());
        break;
    }
  }

  Future<String> _resolveIconAssetPath() async {
    // macOS uses a template image (black on transparent, auto-tinted by the OS).
    // Windows uses the full-color app icon.
    if (!kIsWeb && Platform.isMacOS) {
      return 'assets/icon/tray_icon.png';
    }
    return 'assets/icon/icon.png';
  }

  void dispose() {
    _settings?.removeListener(_onSettingsChanged);
    _timer?.removeListener(_onTimerChanged);
    _together?.removeListener(_onTogetherChanged);
    if (_windowListenerAttached) {
      windowManager.removeListener(this);
      _windowListenerAttached = false;
    }
    if (_trayInitialized) {
      unawaited(trayManager.destroy());
      trayManager.removeListener(this);
      _trayInitialized = false;
    }
  }
}

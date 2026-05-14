import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../controllers/settings_controller.dart';
import '../controllers/timer_controller.dart';

class DesktopTrayService with WindowListener, TrayListener {
  SettingsController? _settings;
  TimerController? _timer;
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
    await trayManager.setToolTip(_toolTipText(mode, timer));
    if (Platform.isMacOS) {
      await trayManager.setTitle(
        mode == DesktopTrayMode.timer ? timer.timeDisplay : '',
      );
    }
  }

  String _toolTipText(DesktopTrayMode mode, TimerController timer) {
    if (mode == DesktopTrayMode.timer) {
      return 'Popodoro · ${timer.timeDisplay}';
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
    const localAsset = 'assets/icon/icon.png';
    final packagedAsset =
        '${Directory.current.path}/data/flutter_assets/$localAsset';
    if (await File(packagedAsset).exists()) return localAsset;
    return localAsset;
  }

  void dispose() {
    _settings?.removeListener(_onSettingsChanged);
    _timer?.removeListener(_onTimerChanged);
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

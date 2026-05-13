import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'controllers/history_controller.dart';
import 'controllers/settings_controller.dart';
import 'controllers/timer_controller.dart';
import 'core/theme/app_theme.dart';
import 'screens/shell.dart';
import 'services/sound_service.dart';
import 'services/window_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  const WindowOptions windowOptions = WindowOptions(
    size: Size(440, 680),
    minimumSize: Size(300, 500),
    center: true,
    title: 'Popodoro',
    titleBarStyle: TitleBarStyle.normal,
    skipTaskbar: false,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  final settings = await SettingsController.load();
  final history = HistoryController(prefs: settings.prefs);
  runApp(PopodoroApp(settings: settings, history: history));
}

class PopodoroApp extends StatelessWidget {
  const PopodoroApp({super.key, required this.settings, required this.history});

  final SettingsController settings;
  final HistoryController history;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: history),
        ChangeNotifierProvider<WindowService>(
          create: (ctx) => WindowService(prefs: ctx.read<SettingsController>().prefs),
        ),
        Provider<SoundService>(
          create: (ctx) => SoundService(ctx.read<SettingsController>()),
          dispose: (_, svc) => svc.dispose(),
        ),
        ChangeNotifierProxyProvider<SettingsController, TimerController>(
          create: (ctx) => TimerController(
            settings: ctx.read<SettingsController>(),
            onFocusComplete: ctx.read<SoundService>().playConfirmation,
            onSessionComplete: ctx.read<HistoryController>().record,
          ),
          update: (_, s, previous) => previous!,
        ),
      ],
      child: Consumer<SettingsController>(
        builder: (context, s, _) => MaterialApp(
          title: 'Popodoro',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: s.themeMode,
          home: const PopodoroShell(),
        ),
      ),
    );
  }
}

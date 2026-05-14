import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'controllers/history_controller.dart';
import 'controllers/project_controller.dart';
import 'controllers/settings_controller.dart';
import 'controllers/timer_controller.dart';
import 'core/theme/app_theme.dart';
import 'database/app_database.dart';
import 'screens/shell.dart';
import 'services/auth_service.dart';
import 'services/bg_music_service.dart';
import 'services/desktop_tray_service.dart';
import 'services/focus_guard_service.dart';
import 'services/obsidian_service.dart';
import 'services/project_service.dart';
import 'services/sound_service.dart';
import 'services/sync_service.dart';
import 'services/together_service.dart';
import 'services/update_service.dart';
import 'services/window_service.dart';
import 'widgets/update_dialog.dart';

const _supabaseUrl = 'https://ysbbdxvwittczfrezzlm.supabase.co';
const _supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlzYmJkeHZ3aXR0Y3pmcmV6emxtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg3MDcxNDQsImV4cCI6MjA5NDI4MzE0NH0.2zrSPEtZkYahEmEuW9n9bCIvuCkjZ1jZKMBFTFMEHn4';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);

  if (!kIsWeb && (Platform.isMacOS || Platform.isWindows)) {
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
  }

  final settings = await SettingsController.load();
  final db = await AppDatabase.open();
  final sync = SyncService(db: db);
  final history = HistoryController(
    db: db,
    legacyPrefs: settings.prefs,
    onNewSession: sync.requestSync,
  );

  runApp(PopodoroApp(settings: settings, history: history, db: db, sync: sync));
}

class PopodoroApp extends StatefulWidget {
  const PopodoroApp({
    super.key,
    required this.settings,
    required this.history,
    required this.db,
    required this.sync,
  });

  final SettingsController settings;
  final HistoryController history;
  final AppDatabase db;
  final SyncService sync;

  @override
  State<PopodoroApp> createState() => _PopodoroAppState();
}

class _PopodoroAppState extends State<PopodoroApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final updateInfo = await UpdateService.checkForUpdate();
      if (updateInfo != null && _navigatorKey.currentContext != null) {
        showDialog(
          context: _navigatorKey.currentContext!,
          builder: (context) => UpdateDialog(updateInfo: updateInfo),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.settings),
        ChangeNotifierProvider.value(value: widget.history),
        ChangeNotifierProvider.value(value: widget.sync),
        // AuthService depends on SyncService, so it comes after.
        ChangeNotifierProxyProvider<SyncService, AuthService>(
          create: (ctx) => AuthService(sync: ctx.read<SyncService>()),
          update: (_, sync, previous) => previous!,
        ),
        ChangeNotifierProvider<WindowService>(
          create: (ctx) =>
              WindowService(prefs: ctx.read<SettingsController>().prefs),
        ),
        ChangeNotifierProvider<TogetherService>(
          create: (_) => TogetherService(),
        ),
        ChangeNotifierProvider<ObsidianService>(
          create: (ctx) =>
              ObsidianService(prefs: ctx.read<SettingsController>().prefs),
        ),
        Provider<ProjectService>(
          create: (_) => ProjectService(widget.db),
        ),
        ChangeNotifierProxyProvider<ObsidianService, ProjectController>(
          create: (ctx) => ProjectController(
            projectService: ctx.read<ProjectService>(),
            obsidianService: ctx.read<ObsidianService>(),
          ),
          update: (_, __, previous) => previous!,
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
            onProjectSessionComplete: (sessionId, duration) =>
                ctx.read<ProjectController>().onSessionComplete(
                      sessionId: sessionId,
                      durationMinutes: duration,
                    ),
          ),
          update: (_, s, previous) => previous!,
        ),
        ChangeNotifierProxyProvider2<
          SettingsController,
          TimerController,
          BgMusicService
        >(
          lazy: false,
          create: (ctx) =>
              BgMusicService(settings: ctx.read<SettingsController>()),
          update: (_, settings, timer, previous) {
            (previous ?? BgMusicService(settings: settings)).bindTimer(timer);
            return previous!;
          },
        ),
        ChangeNotifierProxyProvider2<
          SettingsController,
          TimerController,
          FocusGuardService
        >(
          lazy: false,
          create: (ctx) => FocusGuardService(
            settings: ctx.read<SettingsController>(),
            db: widget.db,
          ),
          update: (_, settings, timer, previous) {
            (previous ?? FocusGuardService(settings: settings, db: widget.db))
                .bindTimer(timer);
            return previous!;
          },
        ),
        ProxyProvider3<
          SettingsController,
          TimerController,
          TogetherService,
          DesktopTrayService
        >(
          lazy: false,
          create: (_) => DesktopTrayService(),
          update: (_, settings, timer, together, previous) =>
              (previous ?? DesktopTrayService()).bind(
                settings: settings,
                timer: timer,
                together: together,
              ),
          dispose: (_, service) => service.dispose(),
        ),
      ],
      child: Consumer<SettingsController>(
        builder: (context, s, _) => MaterialApp(
          navigatorKey: _navigatorKey,
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

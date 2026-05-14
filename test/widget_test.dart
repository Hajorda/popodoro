import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:popodoro/controllers/history_controller.dart';
import 'package:popodoro/controllers/settings_controller.dart';
import 'package:popodoro/database/app_database.dart';
import 'package:popodoro/main.dart';
import 'package:popodoro/services/sync_service.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsController.load();
    final db = await AppDatabase.openInMemory();
    final sync = SyncService(db: db);
    final history = HistoryController(db: db);
    await tester.pumpWidget(
      PopodoroApp(settings: settings, history: history, db: db, sync: sync),
    );
    await tester.pump();
  });
}

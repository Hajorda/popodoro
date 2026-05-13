import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:popodoro/controllers/history_controller.dart';
import 'package:popodoro/controllers/settings_controller.dart';
import 'package:popodoro/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsController.load();
    final history = HistoryController(prefs: settings.prefs);
    await tester.pumpWidget(PopodoroApp(settings: settings, history: history));
    await tester.pump();
  });
}

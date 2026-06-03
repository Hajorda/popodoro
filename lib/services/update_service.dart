import 'package:auto_updater/auto_updater.dart';

class UpdateService {
  static const String _appcastUrl =
      'https://hajorda.github.io/popodoro/appcast.xml';

  /// Initializes the auto updater and checks for updates.
  static Future<void> checkForUpdate() async {
    try {
      await autoUpdater.setFeedURL(_appcastUrl);
      await autoUpdater.checkForUpdates();
    } catch (e) {
      // Fail silently for background checks to not annoy the user
      // if they are offline.
      print('Update check failed: $e');
    }
  }
}

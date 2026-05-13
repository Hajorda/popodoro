import 'package:audioplayers/audioplayers.dart';
import '../controllers/settings_controller.dart';

// Two dedicated players so confirmation and switch sounds never interrupt
// each other (e.g. the user taps a button right as a session ends).
class SoundService {
  SoundService(this._settings);

  final SettingsController _settings;
  final AudioPlayer _confirmPlayer = AudioPlayer();
  final AudioPlayer _switchPlayer = AudioPlayer();

  // Played when a focus session completes.
  Future<void> playConfirmation() async {
    if (!_settings.soundEnabled) return;
    await _confirmPlayer.play(AssetSource('sounds/confirmation_002.ogg'));
  }

  // Played on button interactions (start, pause, skip, etc.).
  Future<void> playSwitch() async {
    if (!_settings.soundEnabled) return;
    await _switchPlayer.play(AssetSource('sounds/switch_002.ogg'));
  }

  void dispose() {
    _confirmPlayer.dispose();
    _switchPlayer.dispose();
  }
}

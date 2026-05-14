import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../controllers/settings_controller.dart';
import '../controllers/timer_controller.dart';
import '../models/pomodoro_state.dart';

// ── Track catalogue ────────────────────────────────────────────────────────────
// Add your R2 public URL below. Format: https://pub-XXXX.r2.dev/ or custom domain.
// Each BgTrack maps an id (stored in prefs) to its stream URL.

const _kR2Base = 'https://YOUR_R2_PUBLIC_URL/'; // ← replace with your R2 URL

class BgTrack {
  const BgTrack({
    required this.id,
    required this.label,
    required this.emoji,
    required this.filename,
  });

  final String id;
  final String label;
  final String emoji;
  final String filename;

  String get url => '$_kR2Base$filename';
}

// ── Available tracks ──────────────────────────────────────────────────────────
// Add more entries here as you upload more files to R2.
const List<BgTrack> kBgTracks = [
  BgTrack(id: 'lofi', label: 'Lo-fi beats', emoji: '🎵', filename: 'lofi.mp3'),
  // BgTrack(id: 'rain', label: 'Rain', emoji: '🌧', filename: 'rain.mp3'),
  // BgTrack(id: 'white_noise', label: 'White noise', emoji: '🌊', filename: 'white_noise.mp3'),
];

// ── Service ────────────────────────────────────────────────────────────────────

class BgMusicService extends ChangeNotifier {
  BgMusicService({required SettingsController settings}) : _settings = settings {
    settings.addListener(_requestSync);
    unawaited(_player.setReleaseMode(ReleaseMode.loop));
  }

  final SettingsController _settings;
  final AudioPlayer _player = AudioPlayer();
  TimerController? _timer;

  String? _loadedUrl; // URL currently loaded / playing
  bool _isPlaying = false;
  bool _isSyncing = false;
  bool _pendingSync = false;

  // True when a preview is active (ignores timer state).
  bool _previewing = false;
  bool get isPreviewing => _previewing;

  // ── Wiring ─────────────────────────────────────────────────────────────────

  void bindTimer(TimerController timer) {
    if (identical(_timer, timer)) return;
    _timer?.removeListener(_requestSync);
    _timer = timer;
    timer.addListener(_requestSync);
    _requestSync();
  }

  // ── Preview (play a track in settings without starting the timer) ───────────

  Future<void> previewTrack(String trackId) async {
    _previewing = true;
    notifyListeners();
    final track = kBgTracks.where((t) => t.id == trackId).firstOrNull;
    if (track == null) { _previewing = false; notifyListeners(); return; }
    await _loadAndPlay(track.url, _settings.bgVolume);
  }

  Future<void> stopPreview() async {
    _previewing = false;
    notifyListeners();
    _requestSync(); // hand back control to the timer-based logic
  }

  // ── Internal sync ──────────────────────────────────────────────────────────

  void _requestSync() {
    if (_isSyncing) { _pendingSync = true; return; }
    _isSyncing = true;
    unawaited(() async {
      do {
        _pendingSync = false;
        await _sync();
      } while (_pendingSync);
      _isSyncing = false;
    }());
  }

  Future<void> _sync() async {
    // Let the preview logic handle things independently.
    if (_previewing) return;

    final id = _settings.bgSoundId;
    final track = kBgTracks.where((t) => t.id == id).firstOrNull;
    final url = track?.url;

    final timer = _timer;
    final shouldPlay = url != null &&
        timer != null &&
        timer.status == TimerStatus.running &&
        timer.phase == TimerPhase.focus;

    if (!shouldPlay) {
      if (_isPlaying) {
        await _player.pause();
        _isPlaying = false;
      }
      return;
    }

    if (url != _loadedUrl) {
      await _loadAndPlay(url, _settings.bgVolume);
    } else if (!_isPlaying) {
      await _player.setVolume(_settings.bgVolume);
      await _player.resume();
      _isPlaying = true;
    } else {
      // Already playing the right track. Keep volume in sync if it changed.
      await _player.setVolume(_settings.bgVolume);
    }
  }

  Future<void> setVolume(double v) => _player.setVolume(v);

  Future<void> _loadAndPlay(String url, double volume) async {
    await _player.stop();
    _loadedUrl = url;
    _isPlaying = false;
    await _player.setVolume(volume);
    await _player.play(UrlSource(url));
    _isPlaying = true;
  }

  // ── Cleanup ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _settings.removeListener(_requestSync);
    _timer?.removeListener(_requestSync);
    unawaited(_player.stop());
    _player.dispose();
    super.dispose();
  }
}

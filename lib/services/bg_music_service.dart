import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../controllers/settings_controller.dart';
import '../controllers/timer_controller.dart';
import '../models/pomodoro_state.dart';

// ── Track catalogue ────────────────────────────────────────────────────────────

class BgTrack {
  const BgTrack({
    required this.id,
    required this.label,
    required this.emoji,
    required this.url,
  });

  final String id;
  final String label;
  final String emoji;
  final String url;
}

const List<BgTrack> kBgTracks = [
  BgTrack(
    id: 'white_noise',
    label: 'White noise',
    emoji: '🌊',
    url: 'https://popodoro.ablt.dev/03-White-Noise-10min.mp3',
  ),
  BgTrack(
    id: 'rain',
    label: 'Rain sounds',
    emoji: '🌧',
    url: 'https://popodoro.ablt.dev/central_park_rain.mp3',
  ),
];

// ── Service ────────────────────────────────────────────────────────────────────

class BgMusicService extends ChangeNotifier {
  BgMusicService({required SettingsController settings}) : _settings = settings {
    settings.addListener(_requestSync);
    unawaited(_player.setReleaseMode(ReleaseMode.loop));
  }

  final SettingsController _settings;
  final AudioPlayer _player = AudioPlayer();
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(minutes: 5),
  ));
  TimerController? _timer;

  // Download state (per track id).
  final Map<String, double> _progress = {}; // 0.0–1.0 while downloading
  final Map<String, CancelToken> _tokens = {};

  // Playback state.
  String? _loadedTrackId; // id of the track loaded in the player
  bool _isPlaying = false;
  bool _isSyncing = false;
  bool _pendingSync = false;
  bool _previewing = false;

  // ── Public state ───────────────────────────────────────────────────────────

  bool get isPreviewing => _previewing;

  /// Returns download progress (0–1) while the track is being cached, or null
  /// if the track is already cached / not downloading.
  double? downloadProgress(String id) => _progress[id];
  bool isDownloading(String id) => _progress.containsKey(id);

  // ── Wiring ─────────────────────────────────────────────────────────────────

  void bindTimer(TimerController timer) {
    if (identical(_timer, timer)) return;
    _timer?.removeListener(_requestSync);
    _timer = timer;
    timer.addListener(_requestSync);
    _requestSync();
  }

  // ── Preview API (settings screen) ─────────────────────────────────────────

  Future<void> previewTrack(String trackId) async {
    _previewing = true;
    notifyListeners();
    final track = kBgTracks.where((t) => t.id == trackId).firstOrNull;
    if (track == null) { _previewing = false; notifyListeners(); return; }
    await _loadAndPlay(track);
  }

  Future<void> stopPreview() async {
    if (!_previewing) return;
    _previewing = false;
    await _player.pause();
    _isPlaying = false;
    notifyListeners();
    _requestSync(); // hand control back to timer logic
  }

  // ── Volume (called live from slider) ──────────────────────────────────────

  Future<void> setVolume(double v) => _player.setVolume(v);

  // ── Cache management ───────────────────────────────────────────────────────

  /// Returns the local cached path for [track], downloading if needed.
  /// Returns null on network / disk error.
  Future<String?> ensureCached(String trackId) async {
    final track = kBgTracks.where((t) => t.id == trackId).firstOrNull;
    if (track == null) return null;
    return _ensureCached(track);
  }

  Future<String?> _ensureCached(BgTrack track) async {
    final file = await _cacheFile(track);
    if (file.existsSync()) return file.path;

    // Cancel any stale download for this track.
    _tokens[track.id]?.cancel('superseded');
    final token = CancelToken();
    _tokens[track.id] = token;

    _progress[track.id] = 0.0;
    notifyListeners();

    try {
      await file.parent.create(recursive: true);
      await _dio.download(
        track.url,
        file.path,
        cancelToken: token,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _progress[track.id] = received / total;
            notifyListeners();
          }
        },
      );
      _progress.remove(track.id);
      _tokens.remove(track.id);
      notifyListeners();
      return file.path;
    } on DioException catch (e) {
      _progress.remove(track.id);
      _tokens.remove(track.id);
      // Remove partial file so a retry starts fresh.
      if (file.existsSync()) file.deleteSync();
      notifyListeners();
      if (e.type != DioExceptionType.cancel) {
        debugPrint('[BgMusic] download error for ${track.id}: $e');
      }
      return null;
    }
  }

  Future<File> _cacheFile(BgTrack track) async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/bg_sounds/${track.id}.mp3');
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
    if (_previewing) return;

    final id = _settings.bgSoundId;
    final track = kBgTracks.where((t) => t.id == id).firstOrNull;
    final timer = _timer;

    final shouldPlay = track != null &&
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

    if (track.id != _loadedTrackId) {
      await _loadAndPlay(track);
    } else if (!_isPlaying) {
      await _player.setVolume(_settings.bgVolume);
      await _player.resume();
      _isPlaying = true;
    } else {
      await _player.setVolume(_settings.bgVolume);
    }
  }

  Future<void> _loadAndPlay(BgTrack track) async {
    await _player.stop();
    _isPlaying = false;

    final localPath = await _ensureCached(track);
    if (localPath == null) return; // download failed

    // Check if selection changed while we were downloading.
    if (!_previewing && _settings.bgSoundId != track.id) return;

    _loadedTrackId = track.id;
    await _player.setVolume(_settings.bgVolume);
    await _player.play(DeviceFileSource(localPath));
    _isPlaying = true;
  }

  // ── Cleanup ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    for (final t in _tokens.values) {
      t.cancel('disposed');
    }
    _tokens.clear();
    _settings.removeListener(_requestSync);
    _timer?.removeListener(_requestSync);
    unawaited(_player.stop());
    _player.dispose();
    _dio.close();
    super.dispose();
  }
}

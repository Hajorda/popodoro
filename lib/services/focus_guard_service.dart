import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

// ignore_for_file: unused_field

import '../controllers/settings_controller.dart';
import '../controllers/timer_controller.dart';
import '../database/app_database.dart';
import '../models/pomodoro_state.dart';

// ── Detection types ────────────────────────────────────────────────────────────

enum GuardStatus { idle, active, noPersonDetected, phoneDetected, cameraError }

// COCO class indices for YOLO (80-class model).
// If your model uses different indices, change these.
const _kPersonClass = 0;
const _kPhoneClass = 67;
const _kConfidenceThreshold = 0.30;

// Input resolution expected by the model.
const _kInputSize = 640;

// ── Service ────────────────────────────────────────────────────────────────────

class FocusGuardService extends ChangeNotifier {
  FocusGuardService({
    required SettingsController settings,
    required AppDatabase db,
  })  : _settings = settings,
        _db = db {
    _settings.addListener(_onSettingsChanged);
  }

  final SettingsController _settings;
  final AppDatabase _db;
  TimerController? _timer;

  // Inference
  Interpreter? _interpreter;
  int _numFeatures = 84; // 4 bbox + 80 classes (auto-detected)
  int _numAnchors = 8400;
  bool _transposedOutput = false; // true if output is [boxes, features]

  // Camera
  CameraController? _camera;
  bool _cameraReady = false;

  // Session
  Timer? _checkTimer;
  bool _checking = false;
  bool _guardPaused = false; // true when we paused the timer
  String? _currentSessionId;

  // Current session events (cleared when a new focus session starts)
  final List<DetectionEventRow> _sessionEvents = [];
  List<DetectionEventRow> get sessionEvents => List.unmodifiable(_sessionEvents);

  // Public state
  GuardStatus _status = GuardStatus.idle;
  GuardStatus get status => _status;

  bool get isModelLoaded => _interpreter != null;

  // ── Initialization ──────────────────────────────────────────────────────────

  /// Call from FocusGuardScreen to request camera permission and load the model.
  /// Returns true on success. On macOS/Windows the OS permission dialog is
  /// triggered here by briefly opening the camera.
  Future<bool> initialize() async {
    final cameraOk = await _requestAndTestCamera();
    if (!cameraOk) {
      _status = GuardStatus.cameraError;
      notifyListeners();
      return false;
    }
    final modelOk = await _loadModel();
    if (!modelOk) {
      _status = GuardStatus.cameraError;
      notifyListeners();
      return false;
    }
    return true;
  }

  /// On mobile, shows the permission dialog via permission_handler.
  /// On macOS/Windows, briefly opens the camera which triggers the OS dialog.
  Future<bool> _requestAndTestCamera() async {
    if (kIsWeb) return false;
    if (!Platform.isMacOS && !Platform.isWindows) {
      final status = await Permission.camera.request();
      if (!status.isGranted) return false;
    }
    // Probe camera — on macOS this triggers the system permission dialog.
    return _probeCamera();
  }

  Future<bool> _probeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return false;
      final ctrl = CameraController(
        cameras.first,
        ResolutionPreset.low,
        enableAudio: false,
      );
      await ctrl.initialize();
      await ctrl.dispose();
      return true;
    } catch (e) {
      debugPrint('[FocusGuard] camera probe failed: $e');
      return false;
    }
  }

  Future<bool> _loadModel() async {
    try {
      _interpreter?.close();
      _interpreter = await Interpreter.fromAsset(
        'assets/models/yolo26n_int8.tflite',
        options: InterpreterOptions()..threads = 2,
      );
      _interpreter!.allocateTensors();

      // Auto-detect output layout.
      final outShape = _interpreter!.getOutputTensor(0).shape;
      debugPrint('[FocusGuard] output shape: $outShape');
      if (outShape.length == 3) {
        // [batch, A, B] — larger dim is num_anchors
        if (outShape[1] > outShape[2]) {
          // [1, 8400, 84] — transposed
          _transposedOutput = true;
          _numAnchors = outShape[1];
          _numFeatures = outShape[2];
        } else {
          // [1, 84, 8400] — standard YOLOv8
          _transposedOutput = false;
          _numFeatures = outShape[1];
          _numAnchors = outShape[2];
        }
      }
      debugPrint(
        '[FocusGuard] model ready — '
        '${_transposedOutput ? "transposed" : "standard"} '
        'features=$_numFeatures anchors=$_numAnchors',
      );
      return true;
    } catch (e) {
      debugPrint('[FocusGuard] model load error: $e');
      return false;
    }
  }

  // ── Timer binding ───────────────────────────────────────────────────────────

  void bindTimer(TimerController timer) {
    if (identical(_timer, timer)) return;
    _timer?.removeListener(_onTimerChanged);
    _timer = timer;
    timer.addListener(_onTimerChanged);
    _onTimerChanged();
  }

  void _onSettingsChanged() => _onTimerChanged();

  void _onTimerChanged() {
    final timer = _timer;
    if (timer == null || !_settings.focusGuardEnabled) {
      _stopChecking();
      _disposeCamera();
      if (_status != GuardStatus.idle) {
        _status = GuardStatus.idle;
        notifyListeners();
      }
      return;
    }

    final isFocusRunning = timer.phase == TimerPhase.focus &&
        timer.status == TimerStatus.running;

    if (isFocusRunning && _interpreter != null) {
      final newSessionId =
          timer.sessionStartTime?.millisecondsSinceEpoch.toString();
      if (newSessionId != _currentSessionId) {
        // New focus session started — reset state.
        _currentSessionId = newSessionId;
        _sessionEvents.clear();
        _guardPaused = false;
      }
      unawaited(_startCamera());
    } else {
      _stopChecking();
      if (!isFocusRunning) _disposeCamera();
      // Resume if guard had paused and timer phase changed (break started).
      if (_guardPaused && timer.phase != TimerPhase.focus) {
        _guardPaused = false;
      }
      if (_status != GuardStatus.idle) {
        _status = GuardStatus.idle;
        notifyListeners();
      }
    }
  }

  // ── Camera lifecycle ────────────────────────────────────────────────────────

  Future<void> _startCamera() async {
    if (_cameraReady) {
      _startCheckLoop();
      return;
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _status = GuardStatus.cameraError;
        notifyListeners();
        return;
      }
      _camera?.dispose();
      _camera = CameraController(
        cameras.first,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _camera!.initialize();
      _cameraReady = true;
      _startCheckLoop();
    } catch (e) {
      debugPrint('[FocusGuard] camera init error: $e');
      _status = GuardStatus.cameraError;
      notifyListeners();
    }
  }

  void _disposeCamera() {
    _camera?.dispose();
    _camera = null;
    _cameraReady = false;
  }

  // ── Check loop ──────────────────────────────────────────────────────────────

  void _startCheckLoop() {
    if (_checkTimer != null) return;
    _checkTimer = Timer.periodic(const Duration(seconds: 5), (_) => _runCheck());
    unawaited(_runCheck()); // immediate first check
  }

  void _stopChecking() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _checking = false;
  }

  Future<void> _runCheck() async {
    final timer = _timer;
    if (timer == null) return;
    if (_camera == null || !_cameraReady) return;
    if (_interpreter == null) return;
    if (_checking) return;
    _checking = true;

    try {
      final file = await _camera!.takePicture();
      // TFLite Interpreter is not sendable across isolates — inference on main.
      final detection = await _runInference(file.path);
      await File(file.path).delete(); // clean up temp capture
      await _handleDetection(detection);
    } catch (e) {
      debugPrint('[FocusGuard] check error: $e');
    } finally {
      _checking = false;
    }
  }

  Future<_DetectionResult> _runInference(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return const _DetectionResult(false, false);

      // Resize to model input size.
      final resized =
          img.copyResize(decoded, width: _kInputSize, height: _kInputSize);

      // Build uint8 input buffer [1, 640, 640, 3].
      final inputBytes = Uint8List(_kInputSize * _kInputSize * 3);
      var idx = 0;
      for (var y = 0; y < _kInputSize; y++) {
        for (var x = 0; x < _kInputSize; x++) {
          final pixel = resized.getPixel(x, y);
          inputBytes[idx++] = pixel.r.toInt().clamp(0, 255);
          inputBytes[idx++] = pixel.g.toInt().clamp(0, 255);
          inputBytes[idx++] = pixel.b.toInt().clamp(0, 255);
        }
      }

      final interpreter = _interpreter!;
      interpreter.getInputTensor(0).data = inputBytes;
      interpreter.invoke();
      final rawOut = interpreter.getOutputTensor(0).data.buffer.asFloat32List();

      return _parseOutput(rawOut);
    } catch (e) {
      debugPrint('[FocusGuard] inference error: $e');
      return const _DetectionResult(true, false); // safe default: assume person present
    }
  }

  _DetectionResult _parseOutput(Float32List raw) {
    bool personFound = false;
    bool phoneFound = false;

    // Determine class offset — classes start after the 4 bbox values.
    final numClasses = _numFeatures - 4;
    if (numClasses <= 0) return const _DetectionResult(true, false);

    final personIdx = _kPersonClass;
    final phoneIdx = _kPhoneClass;

    if (!_transposedOutput) {
      // Standard: [features, anchors] — raw[feature * anchors + anchor]
      for (var a = 0; a < _numAnchors; a++) {
        if (personIdx < numClasses) {
          final score = raw[(4 + personIdx) * _numAnchors + a];
          if (score > _kConfidenceThreshold) { personFound = true; }
        }
        if (phoneIdx < numClasses) {
          final score = raw[(4 + phoneIdx) * _numAnchors + a];
          if (score > _kConfidenceThreshold) { phoneFound = true; }
        }
        if (personFound && phoneFound) break;
      }
    } else {
      // Transposed: [anchors, features] — raw[anchor * features + feature]
      for (var a = 0; a < _numAnchors; a++) {
        final base = a * _numFeatures;
        if (personIdx < numClasses) {
          final score = raw[base + 4 + personIdx];
          if (score > _kConfidenceThreshold) { personFound = true; }
        }
        if (phoneIdx < numClasses) {
          final score = raw[base + 4 + phoneIdx];
          if (score > _kConfidenceThreshold) { phoneFound = true; }
        }
        if (personFound && phoneFound) break;
      }
    }

    return _DetectionResult(personFound, phoneFound);
  }

  Future<void> _handleDetection(_DetectionResult result) async {
    final timer = _timer;
    if (timer == null) return;

    final noPerson = !result.personPresent;
    final phonePresent = result.phoneDetected;
    final shouldPause = noPerson || phonePresent;

    if (shouldPause && timer.status == TimerStatus.running) {
      timer.pause();
      _guardPaused = true;

      if (noPerson) {
        await _recordEvent('no_person', 0.0);
        _status = GuardStatus.noPersonDetected;
      } else {
        await _recordEvent('phone', 0.0);
        _status = GuardStatus.phoneDetected;
      }
      notifyListeners();
    } else if (!shouldPause && _guardPaused && timer.status == TimerStatus.paused) {
      timer.start();
      _guardPaused = false;
      _status = GuardStatus.active;
      notifyListeners();
    } else if (!shouldPause && _status != GuardStatus.active) {
      _status = GuardStatus.active;
      notifyListeners();
    }
  }

  Future<void> _recordEvent(String type, double confidence) async {
    final sessionId = _currentSessionId;
    if (sessionId == null) return;
    final row = DetectionEventRow(
      sessionId: sessionId,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      type: type,
      confidence: confidence,
    );
    _sessionEvents.add(row);
    await _db.insertDetectionEvent(row);
  }

  // ── Stats queries (called from stats screen) ────────────────────────────────

  Future<List<DetectionSummaryRow>> fetchSummaries({int limit = 30}) =>
      _db.fetchDetectionSummaries(limit: limit);

  // ── Cleanup ─────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _stopChecking();
    _disposeCamera();
    _interpreter?.close();
    _settings.removeListener(_onSettingsChanged);
    _timer?.removeListener(_onTimerChanged);
    super.dispose();
  }
}

// ── Detection result ───────────────────────────────────────────────────────────

class _DetectionResult {
  const _DetectionResult(this.personPresent, this.phoneDetected);
  final bool personPresent;
  final bool phoneDetected;
}


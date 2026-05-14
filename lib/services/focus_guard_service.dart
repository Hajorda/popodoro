import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

enum CameraFailure { permissionDenied, noCamera, notSupported, other }

const _kPersonClass = 0;
const _kPhoneClass = 67; // falls back gracefully if model has fewer classes
const _kConfidenceThreshold = 0.30;

// Method channel for native macOS camera — matches FocusGuardPlugin.swift
const _kChannel = 'com.popodoro/focus_guard';

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

  // macOS native channel
  static const _channel = MethodChannel(_kChannel);

  // Inference
  Interpreter? _interpreter;
  int _numFeatures = 84;
  int _numAnchors = 8400;
  bool _transposedOutput = false;
  int _inputSize = 640; // auto-detected from model input tensor

  // Camera (mobile / Windows — camera package)
  CameraController? _camera;
  bool _cameraReady = false;

  // macOS native session state
  bool _macSessionOpen = false;

  // Session
  Timer? _checkTimer;
  bool _checking = false;
  bool _guardPaused = false;
  String? _currentSessionId;

  CameraFailure? _lastCameraFailure;
  CameraFailure? get lastCameraFailure => _lastCameraFailure;

  final List<DetectionEventRow> _sessionEvents = [];
  List<DetectionEventRow> get sessionEvents => List.unmodifiable(_sessionEvents);

  GuardStatus _status = GuardStatus.idle;
  GuardStatus get status => _status;

  bool get isModelLoaded => _interpreter != null;

  // ── Initialization ──────────────────────────────────────────────────────────

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

  Future<bool> _requestAndTestCamera() async {
    if (kIsWeb) {
      _lastCameraFailure = CameraFailure.other;
      return false;
    }

    if (Platform.isMacOS) {
      return _requestAndTestCameraMacOS();
    }

    if (Platform.isWindows) {
      // camera package has no Windows implementation in this Flutter version.
      // Upgrading Flutter to Dart >=3.11 and adding camera_desktop would enable it.
      _lastCameraFailure = CameraFailure.notSupported;
      return false;
    }

    // Mobile: use permission_handler
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      _lastCameraFailure = CameraFailure.permissionDenied;
      return false;
    }

    return _probeCameraMobile();
  }

  // ── macOS native path ───────────────────────────────────────────────────────

  Future<bool> _requestAndTestCameraMacOS() async {
    try {
      final String result =
          await _channel.invokeMethod<String>('requestPermission') ?? 'denied';
      if (result != 'granted') {
        _lastCameraFailure = CameraFailure.permissionDenied;
        return false;
      }
      final bool has =
          await _channel.invokeMethod<bool>('hasCameras') ?? false;
      if (!has) {
        _lastCameraFailure = CameraFailure.noCamera;
        return false;
      }
      _lastCameraFailure = null;
      return true;
    } on PlatformException catch (e) {
      debugPrint('[FocusGuard] macOS camera check error: ${e.code} ${e.message}');
      _lastCameraFailure = CameraFailure.other;
      return false;
    }
  }

  Future<void> _openMacSession() async {
    if (_macSessionOpen) return;
    try {
      await _channel.invokeMethod<void>('openSession');
      _macSessionOpen = true;
    } on PlatformException catch (e) {
      debugPrint('[FocusGuard] openSession error: ${e.code} ${e.message}');
      if (e.code == 'PERMISSION_DENIED') {
        _lastCameraFailure = CameraFailure.permissionDenied;
      } else if (e.code == 'NO_CAMERA') {
        _lastCameraFailure = CameraFailure.noCamera;
      } else {
        _lastCameraFailure = CameraFailure.other;
      }
      _status = GuardStatus.cameraError;
      notifyListeners();
    }
  }

  Future<void> _closeMacSession() async {
    if (!_macSessionOpen) return;
    try {
      await _channel.invokeMethod<void>('closeSession');
    } catch (_) {}
    _macSessionOpen = false;
  }

  // ── Mobile camera path ──────────────────────────────────────────────────────

  Future<bool> _probeCameraMobile() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _lastCameraFailure = CameraFailure.noCamera;
        return false;
      }
      final ctrl = CameraController(
        cameras.first,
        ResolutionPreset.low,
        enableAudio: false,
      );
      await ctrl.initialize();
      await ctrl.dispose();
      _lastCameraFailure = null;
      return true;
    } on CameraException catch (e) {
      final code = e.code;
      if (code == 'CameraAccessDenied' ||
          code == 'CameraAccessDeniedWithoutPrompt' ||
          code == 'CameraAccessRestricted' ||
          code == 'AudioAccessDenied' ||
          code == 'permissionDenied') {
        _lastCameraFailure = CameraFailure.permissionDenied;
      } else {
        _lastCameraFailure = CameraFailure.other;
      }
      debugPrint('[FocusGuard] camera probe failed (${e.code}): ${e.description}');
      return false;
    } catch (e) {
      _lastCameraFailure = CameraFailure.other;
      debugPrint('[FocusGuard] camera probe failed: $e');
      return false;
    }
  }

  // ── Model loading ───────────────────────────────────────────────────────────

  Future<bool> _loadModel() async {
    try {
      _interpreter?.close();
      _interpreter = await Interpreter.fromAsset(
        'assets/models/yolo26n_int8.tflite',
        options: InterpreterOptions()..threads = 2,
      );
      _interpreter!.allocateTensors();

      // Auto-detect input size and type.
      final inTensor = _interpreter!.getInputTensor(0);
      final inShape = inTensor.shape;
      debugPrint('[FocusGuard] input shape: $inShape  type: ${inTensor.type}');
      if (inShape.length == 4 && inShape[1] > 0) {
        _inputSize = inShape[1];
      }

      final outShape = _interpreter!.getOutputTensor(0).shape;
      debugPrint('[FocusGuard] output shape: $outShape');
      if (outShape.length == 3) {
        if (outShape[1] > outShape[2]) {
          _transposedOutput = true;
          _numAnchors = outShape[1];
          _numFeatures = outShape[2];
        } else {
          _transposedOutput = false;
          _numFeatures = outShape[1];
          _numAnchors = outShape[2];
        }
      }
      final numClasses = _numFeatures - 4;
      debugPrint(
        '[FocusGuard] model ready — '
        'input=$_inputSize '
        '${_transposedOutput ? "transposed" : "standard"} '
        'anchors=$_numAnchors features=$_numFeatures classes=$numClasses '
        '(person=class0, phone=class${_kPhoneClass < numClasses ? _kPhoneClass : "n/a"})',
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
        _currentSessionId = newSessionId;
        _sessionEvents.clear();
        _guardPaused = false;
      }
      unawaited(_startCamera());
    } else {
      _stopChecking();
      if (!isFocusRunning) _disposeCamera();
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
    if (Platform.isMacOS) {
      await _openMacSession();
      if (_macSessionOpen) _startCheckLoop();
      return;
    }

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
    if (Platform.isMacOS && !kIsWeb) {
      unawaited(_closeMacSession());
      return;
    }
    _camera?.dispose();
    _camera = null;
    _cameraReady = false;
  }

  // ── Check loop ──────────────────────────────────────────────────────────────

  void _startCheckLoop() {
    if (_checkTimer != null) return;
    _checkTimer = Timer.periodic(const Duration(seconds: 5), (_) => _runCheck());
    unawaited(_runCheck());
  }

  void _stopChecking() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _checking = false;
  }

  Future<void> _runCheck() async {
    final timer = _timer;
    if (timer == null) return;
    if (_interpreter == null) return;
    if (_checking) return;
    _checking = true;

    try {
      _DetectionResult detection;

      if (!kIsWeb && Platform.isMacOS) {
        detection = await _runCheckMacOS();
      } else {
        if (_camera == null || !_cameraReady) return;
        final file = await _camera!.takePicture();
        final bytes = await File(file.path).readAsBytes();
        await File(file.path).delete();
        detection = await _runInferenceFromBytes(bytes);
      }

      await _handleDetection(detection);
    } catch (e) {
      debugPrint('[FocusGuard] check error: $e');
    } finally {
      _checking = false;
    }
  }

  Future<_DetectionResult> _runCheckMacOS() async {
    try {
      final data = await _channel.invokeMethod<Uint8List>('captureFrame');
      if (data == null) return const _DetectionResult(true, false);
      return _runInferenceFromBytes(data);
    } on PlatformException catch (e) {
      debugPrint('[FocusGuard] captureFrame error: ${e.code} ${e.message}');
      return const _DetectionResult(true, false); // safe: assume person present
    }
  }

  Future<_DetectionResult> _runInferenceFromBytes(Uint8List bytes) async {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return const _DetectionResult(false, false);

      final sz = _inputSize;
      final resized = img.copyResize(decoded, width: sz, height: sz);

      // Float32 input: hybrid int8 models have float32 I/O (int8 weights only).
      // Values in [0, 255] — normalization is baked into the model graph.
      final inputFloat = Float32List(sz * sz * 3);
      var idx = 0;
      for (var y = 0; y < sz; y++) {
        for (var x = 0; x < sz; x++) {
          final pixel = resized.getPixel(x, y);
          inputFloat[idx++] = pixel.r.toDouble();
          inputFloat[idx++] = pixel.g.toDouble();
          inputFloat[idx++] = pixel.b.toDouble();
        }
      }

      // Use .data= + .invoke() directly to preserve the 4D tensor shape
      // set by allocateTensors(). interpreter.run() internally resizes to 1D
      // which breaks the PAD op (SizeOfDimension 4 != 1).
      _interpreter!.getInputTensor(0).data = inputFloat.buffer.asUint8List();
      _interpreter!.invoke();

      // Output bytes reinterpreted as float32 (row-major, same layout as tensor)
      final raw = _interpreter!.getOutputTensor(0).data.buffer.asFloat32List();
      return _parseOutput(raw);
    } catch (e) {
      debugPrint('[FocusGuard] inference error: $e');
      return const _DetectionResult(true, false);
    }
  }

  // Flat row-major array from TFLite tensor copy:
  //   transposed [1, anchors, features] → raw[a * features + f]
  //   standard   [1, features, anchors] → raw[f * anchors + a]
  _DetectionResult _parseOutput(Float32List raw) {
    bool personFound = false;
    bool phoneFound = false;

    final numClasses = _numFeatures - 4;
    if (numClasses <= 0) return const _DetectionResult(true, false);

    if (_transposedOutput) {
      for (var a = 0; a < _numAnchors; a++) {
        final base = a * _numFeatures;
        if (_kPersonClass < numClasses) {
          if (raw[base + 4 + _kPersonClass] > _kConfidenceThreshold) personFound = true;
        }
        if (_kPhoneClass < numClasses) {
          if (raw[base + 4 + _kPhoneClass] > _kConfidenceThreshold) phoneFound = true;
        }
        if (personFound && phoneFound) break;
      }
    } else {
      for (var a = 0; a < _numAnchors; a++) {
        if (_kPersonClass < numClasses) {
          if (raw[(4 + _kPersonClass) * _numAnchors + a] > _kConfidenceThreshold) personFound = true;
        }
        if (_kPhoneClass < numClasses) {
          if (raw[(4 + _kPhoneClass) * _numAnchors + a] > _kConfidenceThreshold) phoneFound = true;
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

  // ── Stats queries ───────────────────────────────────────────────────────────

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

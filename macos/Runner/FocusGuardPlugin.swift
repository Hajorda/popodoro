import AVFoundation
import Cocoa
import FlutterMacOS

// Method channel name — must match FocusGuardService._kChannel
private let kChannel = "com.popodoro/focus_guard"

class FocusGuardPlugin: NSObject, FlutterPlugin, AVCapturePhotoCaptureDelegate {

  // MARK: – Registration

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: kChannel, binaryMessenger: registrar.messenger)
    let instance = FocusGuardPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  // MARK: – State

  private var session: AVCaptureSession?
  private var photoOutput: AVCapturePhotoOutput?
  private var pendingResult: FlutterResult?

  // MARK: – FlutterPlugin

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "requestPermission":
      requestPermission(result: result)
    case "hasCameras":
      result(hasCameras())
    case "openSession":
      openSession(result: result)
    case "captureFrame":
      captureFrame(result: result)
    case "closeSession":
      closeSession()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: – Permission

  private func requestPermission(result: @escaping FlutterResult) {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      result("granted")
    case .denied, .restricted:
      result("denied")
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { granted in
        DispatchQueue.main.async {
          result(granted ? "granted" : "denied")
        }
      }
    @unknown default:
      result("denied")
    }
  }

  // MARK: – Camera availability

  private func hasCameras() -> Bool {
    if #available(macOS 10.15, *) {
      let discovery = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
        mediaType: .video,
        position: .unspecified
      )
      return !discovery.devices.isEmpty
    } else {
      return AVCaptureDevice.default(for: .video) != nil
    }
  }

  // MARK: – Session lifecycle

  private func openSession(result: @escaping FlutterResult) {
    guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
      result(FlutterError(code: "PERMISSION_DENIED", message: "Camera permission not granted", details: nil))
      return
    }
    guard let device = bestCamera() else {
      result(FlutterError(code: "NO_CAMERA", message: "No camera found", details: nil))
      return
    }

    closeSession() // tear down any existing session

    let s = AVCaptureSession()
    s.sessionPreset = .low

    do {
      let input = try AVCaptureDeviceInput(device: device)
      guard s.canAddInput(input) else {
        result(FlutterError(code: "SESSION_ERROR", message: "Cannot add camera input", details: nil))
        return
      }
      s.addInput(input)
    } catch {
      result(FlutterError(code: "SESSION_ERROR", message: error.localizedDescription, details: nil))
      return
    }

    let output = AVCapturePhotoOutput()
    guard s.canAddOutput(output) else {
      result(FlutterError(code: "SESSION_ERROR", message: "Cannot add photo output", details: nil))
      return
    }
    s.addOutput(output)

    s.startRunning()
    session = s
    photoOutput = output
    result(nil)
  }

  private func closeSession() {
    session?.stopRunning()
    session = nil
    photoOutput = nil
    pendingResult = nil
  }

  private func bestCamera() -> AVCaptureDevice? {
    if #available(macOS 10.15, *) {
      let discovery = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
        mediaType: .video,
        position: .unspecified
      )
      return discovery.devices.first
    } else {
      return AVCaptureDevice.default(for: .video)
    }
  }

  // MARK: – Frame capture

  private func captureFrame(result: @escaping FlutterResult) {
    guard let output = photoOutput, let s = session, s.isRunning else {
      result(FlutterError(code: "SESSION_NOT_OPEN", message: "Call openSession first", details: nil))
      return
    }
    guard pendingResult == nil else {
      result(FlutterError(code: "BUSY", message: "Capture already in progress", details: nil))
      return
    }
    pendingResult = result
    let settings = AVCapturePhotoSettings()
    output.capturePhoto(with: settings, delegate: self)
  }

  // AVCapturePhotoCaptureDelegate
  func photoOutput(
    _ output: AVCapturePhotoOutput,
    didFinishProcessingPhoto photo: AVCapturePhoto,
    error: Error?
  ) {
    defer { pendingResult = nil }
    guard let result = pendingResult else { return }

    if let error = error {
      result(FlutterError(code: "CAPTURE_ERROR", message: error.localizedDescription, details: nil))
      return
    }
    guard let jpegData = photo.fileDataRepresentation() else {
      result(FlutterError(code: "CAPTURE_ERROR", message: "No JPEG data", details: nil))
      return
    }
    result(FlutterStandardTypedData(bytes: jpegData))
  }
}

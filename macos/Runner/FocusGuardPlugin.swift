import AVFoundation
import Cocoa
import CoreImage
import CoreVideo
import FlutterMacOS

// Method channel name — must match FocusGuardService._kChannel
private let kChannel = "com.popodoro/focus_guard"

class FocusGuardPlugin: NSObject, FlutterPlugin, AVCaptureVideoDataOutputSampleBufferDelegate {

  // MARK: – Registration

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: kChannel, binaryMessenger: registrar.messenger)
    let instance = FocusGuardPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  // MARK: – State

  private var session: AVCaptureSession?
  private let videoQueue = DispatchQueue(label: "com.popodoro.focusguard.video", qos: .userInitiated)
  private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

  // Latest JPEG bytes from the video stream; written on videoQueue, read on videoQueue.
  private var latestFrameData: Data?
  private var frameCount = 0

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
        DispatchQueue.main.async { result(granted ? "granted" : "denied") }
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

    closeSession()

    let s = AVCaptureSession()
    s.sessionPreset = .medium

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

    let output = AVCaptureVideoDataOutput()
    // BGRA is cheapest to convert via CoreImage on macOS
    output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    output.alwaysDiscardsLateVideoFrames = true
    output.setSampleBufferDelegate(self, queue: videoQueue)

    guard s.canAddOutput(output) else {
      result(FlutterError(code: "SESSION_ERROR", message: "Cannot add video output", details: nil))
      return
    }
    s.addOutput(output)

    s.startRunning()
    session = s
    result(nil)
  }

  private func closeSession() {
    session?.stopRunning()
    session = nil
    videoQueue.async {
      self.latestFrameData = nil
      self.frameCount = 0
    }
  }

  // MARK: – AVCaptureVideoDataOutputSampleBufferDelegate

  func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    latestFrameData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.7])
    frameCount += 1
    if frameCount <= 3 || frameCount % 30 == 0 {
      NSLog("[FocusGuard-Swift] frame #%d size=%d", frameCount, latestFrameData?.count ?? 0)
    }
  }

  // MARK: – Frame capture

  private func captureFrame(result: @escaping FlutterResult) {
    guard let s = session, s.isRunning else {
      result(FlutterError(code: "SESSION_NOT_OPEN", message: "Call openSession first", details: nil))
      return
    }
    videoQueue.async { [weak self] in
      guard let self = self else { return }
      guard let data = self.latestFrameData else {
        // Camera just started — no frame yet; caller treats nil as "person present" (safe)
        DispatchQueue.main.async { result(nil) }
        return
      }
      let typed = FlutterStandardTypedData(bytes: data)
      DispatchQueue.main.async { result(typed) }
    }
  }
}

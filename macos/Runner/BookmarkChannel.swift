import Cocoa
import FlutterMacOS

/// Provides security-scoped bookmark support over a Flutter method channel.
///
/// macOS sandbox: `user-selected.read-write` only lasts for the picker session.
/// To keep access across relaunches, create a bookmark after the user picks a
/// folder, persist the opaque bytes (returned as base64), and resolve them on
/// the next launch with `startAccessingSecurityScopedResource()`.
///
/// Required entitlements:
///   com.apple.security.files.bookmarks.app-scope
///   com.apple.security.files.user-selected.read-write
class BookmarkChannel {
    static let name = "popodoro/bookmarks"

    // Maps resolved path → URL so we can call stopAccessing later.
    private static var active: [String: URL] = [:]

    static func register(with registrar: FlutterPluginRegistrar) {
        let ch = FlutterMethodChannel(name: name, binaryMessenger: registrar.messenger)
        ch.setMethodCallHandler { call, result in
            switch call.method {
            case "createBookmark":
                guard let path = call.arguments as? String else {
                    result(FlutterError(code: "ARGS", message: "path required", details: nil))
                    return
                }
                create(path: path, result: result)

            case "resolveBookmark":
                guard let b64 = call.arguments as? String else {
                    result(FlutterError(code: "ARGS", message: "base64 required", details: nil))
                    return
                }
                resolve(base64: b64, result: result)

            case "stopAccessing":
                if let path = call.arguments as? String { stop(path: path) }
                result(nil)

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    // ── Create ────────────────────────────────────────────────────────────────

    private static func create(path: String, result: @escaping FlutterResult) {
        let url = URL(fileURLWithPath: path)
        do {
            let data = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            result(data.base64EncodedString())
        } catch {
            result(FlutterError(code: "CREATE_FAILED", message: error.localizedDescription, details: nil))
        }
    }

    // ── Resolve ───────────────────────────────────────────────────────────────

    private static func resolve(base64: String, result: @escaping FlutterResult) {
        guard let data = Data(base64Encoded: base64) else {
            result(FlutterError(code: "DECODE", message: "Cannot decode base64 bookmark", details: nil))
            return
        }
        var stale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            // Start accessing — must be balanced with stopAccessing.
            guard url.startAccessingSecurityScopedResource() else {
                result(FlutterError(code: "ACCESS", message: "startAccessingSecurityScopedResource returned false", details: nil))
                return
            }
            active[url.path] = url
            result(["path": url.path, "stale": stale])
        } catch {
            result(FlutterError(code: "RESOLVE_FAILED", message: error.localizedDescription, details: nil))
        }
    }

    // ── Stop ──────────────────────────────────────────────────────────────────

    private static func stop(path: String) {
        if let url = active.removeValue(forKey: path) {
            url.stopAccessingSecurityScopedResource()
        }
    }
}

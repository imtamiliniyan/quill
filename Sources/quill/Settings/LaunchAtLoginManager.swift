import Foundation

/// Thin SwiftUI-facing wrapper around the LaunchAgent logic that already
/// ships as `quill install --launch-at-login` / `--uninstall`
/// (`Install.swift`). Calls that same `ParsableCommand` directly in-process
/// instead of reimplementing login-item handling a second time.
enum LaunchAtLoginManager {
    private static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.tamiliniyan.quill.plist")
    }

    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    /// Returns whether the toggle actually took effect, so the UI can
    /// revert an optimistic switch if `Install` failed (e.g. binary not
    /// found at `~/bin/quill` yet).
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            let args = enabled ? ["--launch-at-login"] : ["--uninstall"]
            let install = try Install.parse(args)
            try install.run()
            return true
        } catch {
            FileHandle.standardError.write(Data("launch-at-login toggle failed: \(error)\n".utf8))
            return false
        }
    }
}

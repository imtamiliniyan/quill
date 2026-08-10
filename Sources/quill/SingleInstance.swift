import Darwin
import Foundation

/// Ensures only one quill daemon ever holds the Fn-key tap at a time.
///
/// Without this, the "Launch at login" LaunchAgent daemon and a
/// double-clicked Quill.app (or a second `quill run`) each install their
/// own listen-only CGEventTap. Neither tap consumes the key, so both
/// processes independently capture audio, transcribe, and inject text on
/// every single Fn hold — every dictation lands in the focused field
/// twice. Confirmed via `ps`: a `~/bin/quill run --skip-doctor` daemon
/// and an `/Applications/Quill.app` process running side by side.
///
/// Fix: an flock()'d lock file. Whichever process grabs it first is the
/// one real daemon; anyone else asks that instance to open its window
/// (so double-clicking the app while the background daemon is already
/// running still does something useful) and exits instead of starting a
/// second listener.
enum SingleInstance {
    static let openMainNotification = Notification.Name("com.tamiliniyan.quill.openMain")

    private static var lockFileHandle: FileHandle?

    private static var lockURL: URL {
        let dir = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Quill", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("quill.lock")
    }

    /// Tries to become the one running instance. Returns true if this
    /// process now holds the lock (safe to start the daemon); false if
    /// another instance already holds it.
    static func acquire() -> Bool {
        let path = lockURL.path
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }
        guard let handle = FileHandle(forWritingAtPath: path) else {
            // Couldn't even open the lock file — fail open rather than
            // refuse to run at all.
            return true
        }
        if flock(handle.fileDescriptor, LOCK_EX | LOCK_NB) == 0 {
            lockFileHandle = handle
            return true
        }
        try? handle.close()
        return false
    }

    /// Ask the already-running instance to open its main window, since
    /// this process is exiting instead of starting a competing daemon.
    static func requestOpenMain() {
        DistributedNotificationCenter.default().postNotificationName(
            openMainNotification, object: nil, userInfo: nil, deliverImmediately: true
        )
    }

    /// Called by the one real daemon so a second launch can reach it.
    static func observeOpenMainRequests(_ handler: @escaping () -> Void) {
        DistributedNotificationCenter.default().addObserver(
            forName: openMainNotification, object: nil, queue: .main
        ) { _ in handler() }
    }
}

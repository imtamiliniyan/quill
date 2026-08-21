import Darwin
import Foundation

/// Captures the app's own debug/error output — everything already written
/// via `FileHandle.standardError.write` throughout the codebase (model
/// loads, hotkey failures, Auto Cleanup/Medium fallbacks, transcription
/// errors, and so on) — into a local, capped log a user can review and
/// optionally attach to feedback (`FeedbackView`'s "Include debug info").
///
/// Deliberately NOT a crash reporter and NOT a telemetry pipe: nothing
/// here is ever sent anywhere on its own. Quill has no server to send it
/// to in the first place — the only way any of this content leaves this
/// Mac is the user explicitly attaching it to an email they review and
/// send themselves, same as the rest of Send Feedback.
///
/// Captures by redirecting the process's own stderr through a pipe rather
/// than touching the ~30 existing `FileHandle.standardError.write` call
/// sites individually — every one of them is captured for free, and any
/// future one will be too, with zero risk of a new call site quietly
/// being missed. The original stderr is preserved and still receives
/// everything unchanged (so `swift run`/Console.app output isn't
/// affected) — this only adds a second destination.
///
/// One deliberate exception worth calling out: `Quill.swift`'s
/// transcription-complete log line used to print the raw dictated text
/// itself (fine when stderr just vanished into nowhere; not fine once
/// that output is captured and attachable). It was rewritten to log a
/// word count instead before this file was wired in — this actor never
/// sees, and can't accidentally capture, dictation content.
actor QuillLog {
    static let shared = QuillLog()

    private var lines: [String] = []
    private let maxMemoryLines = 1000
    private let maxFileBytes = 512 * 1024

    private var started = false
    // Held for the process's lifetime. Confirmed the hard way: a local
    // `let pipe = Pipe()` that goes out of scope at the end of `start()`
    // gets deallocated while its `readabilityHandler` dispatch source is
    // still active on the read end's fd — that's an abort (SIGABRT), not
    // a graceful failure.
    private var pipe: Pipe?

    private var logURL: URL {
        let dir = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Quill", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("debug.log")
    }

    /// Installs the stderr redirect. Safe to call once, early in app
    /// launch — idempotent. Installing it is independent of
    /// `QuillSettings.debugLoggingEnabled`: capture (this redirect,
    /// harmless plumbing either way) and retention (`append`, below,
    /// which checks the setting) are separate questions, so flipping that
    /// setting later takes effect immediately with no restart needed.
    func start() {
        guard !started else { return }
        started = true

        // Without this, writing to `originalFD` below after its other end
        // has gone away (e.g. the terminal/launcher that owned it exits)
        // raises SIGPIPE, which kills the whole process by default since
        // nothing else in this app already ignores it. Confirmed: without
        // this line, a background-launched `swift run` died with exit 141
        // (128 + SIGPIPE) the moment its original stderr destination
        // closed — this is standard practice for any process that does
        // manual fd writes like this one.
        signal(SIGPIPE, SIG_IGN)

        let newPipe = Pipe()
        pipe = newPipe
        let originalFD = dup(STDERR_FILENO)
        dup2(newPipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)

        newPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            // Forward to the real stderr fd unchanged — capturing is
            // additive, never a replacement for normal stderr output.
            if originalFD >= 0 {
                data.withUnsafeBytes { raw in
                    _ = Darwin.write(originalFD, raw.baseAddress, raw.count)
                }
            }
            guard let text = String(data: data, encoding: .utf8) else { return }
            Task { await QuillLog.shared.append(text) }
        }
    }

    private func append(_ text: String) {
        guard QuillSettings.debugLoggingEnabled else { return }
        let newLines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard !newLines.isEmpty else { return }
        lines.append(contentsOf: newLines)
        if lines.count > maxMemoryLines {
            lines.removeFirst(lines.count - maxMemoryLines)
        }
        appendToFile(newLines)
    }

    private func appendToFile(_ newLines: [String]) {
        let text = newLines.joined(separator: "\n") + "\n"
        guard let data = text.data(using: .utf8) else { return }
        let url = logURL
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write(data)
        } else {
            try? data.write(to: url)
        }
        trimFileIfNeeded()
    }

    /// Keeps `debug.log` bounded — drops the older half once it crosses
    /// `maxFileBytes`, rather than growing forever like a normal append
    /// log would.
    private func trimFileIfNeeded() {
        let url = logURL
        guard
            let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int,
            size > maxFileBytes,
            let full = try? Data(contentsOf: url)
        else { return }
        let trimmed = full.suffix(maxFileBytes / 2)
        try? trimmed.write(to: url)
    }

    /// A bounded tail for attaching to feedback — short enough that the
    /// `mailto:` draft it feeds (`FeedbackView.sendFeedback`) reliably
    /// opens rather than silently failing on an oversized body.
    func recentText(maxChars: Int = 4000) -> String {
        let joined = lines.joined(separator: "\n")
        guard joined.count > maxChars else { return joined }
        return "…(older lines truncated)…\n" + String(joined.suffix(maxChars))
    }

    var isEmpty: Bool { lines.isEmpty }

    func approximateByteCount() -> Int {
        lines.reduce(0) { $0 + $1.utf8.count + 1 }
    }

    /// Wipes both the in-memory buffer and the on-disk file — called from
    /// the manual "Clear Log" control in Settings, and automatically
    /// whenever `QuillSettings.debugLoggingEnabled` is turned off, so
    /// "off" reads as "there is no log," not "an old one just lingers."
    func clear() {
        lines.removeAll()
        try? FileManager.default.removeItem(at: logURL)
    }
}

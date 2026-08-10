import AppKit
import CoreGraphics
import Foundation

/// Types the given text at the current cursor location.
///
/// Uses clipboard-paste (set the pasteboard, synthesize Cmd+V), not raw
/// synthetic keystrokes. The original implementation posted
/// `CGEventKeyboardSetUnicodeString` events directly — reliable in native
/// AppKit/UIKit text fields, but Electron apps (Claude Desktop, Slack,
/// VS Code, etc.) run their own text editors on top of Chromium and don't
/// consistently pick up synthetic per-character keyboard events the way a
/// native `NSTextField` does. Confirmed empirically: dictation transcribed
/// correctly (visible in the daemon's log) but nothing appeared while Claude
/// Desktop was focused. A simulated Cmd+V goes through the exact same path
/// as a real paste, which every one of these apps already has to support —
/// this is the same approach Wispr Flow and similar tools use, for the
/// same reason.
enum TextInjector {
    static func inject(_ text: String) {
        guard !text.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        let previous = pasteboard.string(forType: .string)
        let previousChangeCount = pasteboard.changeCount

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        postCmdV()

        // Restore whatever was on the clipboard before we touched it, but
        // only if nothing else changed it in the meantime (the target app
        // needs a moment to actually read the paste first).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard pasteboard.changeCount == previousChangeCount + 1 else { return }
            pasteboard.clearContents()
            if let previous {
                pasteboard.setString(previous, forType: .string)
            }
        }
    }

    private static func postCmdV() {
        // Same tap location as before — .cgSessionEventTap collides with
        // HotkeyMonitor's own listen-only tap at that spot and gets
        // silently swallowed; .cgAnnotatedSessionEventTap is further down
        // the pipeline and delivers reliably. Confirmed empirically.
        let source = CGEventSource(stateID: .hidSystemState)

        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // 'v'
        vDown?.flags = .maskCommand
        vDown?.post(tap: .cgAnnotatedSessionEventTap)

        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        vUp?.flags = .maskCommand
        vUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
}

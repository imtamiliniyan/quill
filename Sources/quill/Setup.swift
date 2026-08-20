import ApplicationServices
import ArgumentParser
import AVFoundation
import Foundation

struct Setup: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Walk through first-run permission setup."
    )

    func run() throws {
        print("quill setup")
        print("============")
        print()
        print("Quill needs two permissions:")
        print("  1. Accessibility: to detect the Fn key globally and inject text at the cursor.")
        print("  2. Microphone: to record audio while you hold Fn.")
        print()
        print("These attach to your terminal app (Terminal/iTerm/Ghostty/etc.), not quill itself.")
        print()

        try waitForAccessibility()
        print()
        try waitForMicrophone()
        print()
        print("✓ all set. Run `quill` to start the daemon.")
    }

    private func waitForAccessibility() throws {
        if AXIsProcessTrusted() {
            print("✓ accessibility already granted")
            return
        }

        print("→ opening accessibility prompt...")
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)

        print()
        print("  1. Toggle your terminal on in the Accessibility list.")
        print("  2. Re-run `quill setup`. macOS only picks up the grant on a fresh process.")
        throw ExitCode(0)
    }

    private func waitForMicrophone() throws {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            print("✓ microphone already granted")
            return
        case .denied, .restricted:
            print("✗ microphone is denied. macOS won't re-prompt once denied.")
            print("  opening Settings → Privacy & Security → Microphone...")
            openSettings("Privacy_Microphone")
            print("  enable your terminal, then re-run `quill setup`.")
            throw ExitCode(1)
        case .notDetermined:
            print("→ requesting microphone access...")
            let semaphore = DispatchSemaphore(value: 0)
            var granted = false
            AVCaptureDevice.requestAccess(for: .audio) { ok in
                granted = ok
                semaphore.signal()
            }
            semaphore.wait()
            if granted {
                print("  ✓ microphone granted")
            } else {
                print("  ✗ microphone denied")
                throw ExitCode(1)
            }
        @unknown default:
            print("? microphone in unknown state")
        }
    }

    private func openSettings(_ pane: String) {
        let url = "x-apple.systempreferences:com.apple.preference.security?\(pane)"
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [url]
        try? task.run()
    }
}

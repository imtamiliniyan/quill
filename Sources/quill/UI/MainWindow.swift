import AppKit
import SwiftUI

/// The app's persistent, reusable window — unlike OnboardingWindow (shown
/// once, for first-run setup), this one is opened and closed repeatedly:
/// today, just for the model-download-progress view triggered from the
/// menu bar switcher; Phase 2 adds the full Dictation/Insights/Style/
/// Settings sidebar around this same window.
@MainActor
final class MainWindow {
    private var window: NSWindow?
    let downloadState = ModelDownloadState()

    func showDownload(model: TranscriptionModel, box: TranscriberBox, onSwitched: @escaping () -> Void) {
        downloadState.start(model: model, box: box, onSwitched: onSwitched)
        show()
    }

    private func show() {
        if window == nil {
            let hosting = NSHostingView(rootView: ModelDownloadView(state: downloadState))
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            win.title = "Quill"
            win.contentView = hosting
            win.isReleasedWhenClosed = false
            win.center()
            window = win
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        window?.orderOut(nil)
    }
}

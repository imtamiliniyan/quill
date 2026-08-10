import AppKit
import SwiftUI

/// A real, activating, titled window — unlike RecordingOverlay's
/// non-activating panel, this one needs actual keyboard/mouse interaction.
/// Shown whenever OnboardingState.isReady is false; reappears automatically
/// if something regresses later (permission revoked, etc.) instead of the
/// app just dying, as it did before this file existed.
@MainActor
final class OnboardingWindow {
    private var window: NSWindow?
    let state: OnboardingState
    var onFinished: (() -> Void)?

    init(state: OnboardingState) {
        self.state = state
    }

    func show() {
        if window == nil {
            let content = OnboardingView(state: state, onFinished: { [weak self] in
                self?.hide()
                self?.onFinished?()
            })
            let hosting = NSHostingView(rootView: content)
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 580),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            win.title = "Welcome to Quill"
            win.contentView = hosting
            win.isReleasedWhenClosed = false
            win.center()
            window = win
        }
        state.startPolling()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        state.stopPolling()
        window?.orderOut(nil)
    }
}

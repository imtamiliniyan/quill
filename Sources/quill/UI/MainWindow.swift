import AppKit
import SwiftUI

/// The app's persistent, reusable window. Two things live here:
///
/// - the model-download-progress view (triggered from the menu bar switcher)
/// - the full Dictation/Insights/Style/Settings sidebar ("Open Quill")
///
/// Quill runs with no dock icon day-to-day (`.accessory` — it's a menu bar
/// utility). But a window with zero dock/Cmd-Tab presence is disorienting
/// once you're actually looking at it, so we borrow the pattern several
/// menu bar apps use: flip to a real dock icon (`.regular`) only while the
/// main app window is open, and drop back to `.accessory` the moment it
/// closes.
@MainActor
final class MainWindow: NSObject, NSWindowDelegate {
    private var downloadWindow: NSWindow?
    private var mainAppWindow: NSWindow?
    let downloadState = ModelDownloadState()
    private let appState = AppViewState()
    private let menuBar: MenuBarController

    init(menuBar: MenuBarController) {
        self.menuBar = menuBar
    }

    func showDownload(model: TranscriptionModel, box: TranscriberBox, onSwitched: @escaping () -> Void) {
        downloadState.start(model: model, box: box, onSwitched: onSwitched)
        showDownloadWindow()
    }

    /// Opens the full app window — the menu bar's "Open Quill" item and the
    /// download flow's completed state both land here.
    func showMain() {
        if mainAppWindow == nil {
            let hosting = NSHostingView(rootView: MainView(state: appState, menuBar: menuBar))
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 940, height: 620),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            win.title = "Quill"
            win.contentView = hosting
            win.isReleasedWhenClosed = false
            win.minSize = NSSize(width: 600, height: 400)
            win.center()
            win.delegate = self
            mainAppWindow = win
        }
        // Show a dock icon only while this window is around — clicking it
        // to change a tone or a setting shouldn't require digging through
        // the menu bar again, but Quill still shouldn't clutter the dock
        // the rest of the time.
        NSApp.setActivationPolicy(.regular)
        mainAppWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closed = notification.object as? NSWindow, closed === mainAppWindow else { return }
        NSApp.setActivationPolicy(.accessory)
    }

    private func showDownloadWindow() {
        if downloadWindow == nil {
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
            downloadWindow = win
        }
        downloadWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        downloadWindow?.orderOut(nil)
        mainAppWindow?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }
}

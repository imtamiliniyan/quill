import AppKit

/// Status bar item in the top-right of the menu bar. Shows recording state at
/// a glance and provides the only persistent control surface for the daemon
/// (since we run as `.accessory` — no dock icon, no main window).
@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let modelLabel: NSMenuItem
    private let stateLabel: NSMenuItem
    private var modelID: String

    init(modelID: String) {
        self.modelID = modelID
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let menu = NSMenu()
        menu.autoenablesItems = false

        stateLabel = NSMenuItem(title: "idle · hold fn to dictate", action: nil, keyEquivalent: "")
        stateLabel.isEnabled = false
        menu.addItem(stateLabel)

        modelLabel = NSMenuItem(title: "model: \(modelID)", action: nil, keyEquivalent: "")
        modelLabel.isEnabled = false
        menu.addItem(modelLabel)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit quill",
            action: #selector(quitClicked),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        configureButton(recording: false)
    }

    func setRecording(_ recording: Bool) {
        stateLabel.title = recording ? "● recording" : "idle · hold fn to dictate"
    }

    func setTranscribing() {
        stateLabel.title = "transcribing…"
    }

    /// Called once onboarding picks a model (the initial `modelID` may just
    /// be a placeholder like "not set" if the menu bar had to appear before
    /// a choice was made).
    func updateModel(_ id: String) {
        modelID = id
        modelLabel.title = "model: \(id)"
    }

    private func configureButton(recording: Bool) {
        guard let button = statusItem.button else { return }
        let image = Self.featherImage()
        image?.isTemplate = true
        button.image = image
    }

    // Inlined Feather-icons "feather" SVG (quill/pen theme, matches the
    // project name). Keeping it in source means the executable has no
    // separate resource bundle to install alongside it — true single-binary.
    private static let featherSVG = """
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" \
    viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" \
    stroke-linecap="round" stroke-linejoin="round">\
    <path d="M20.24 12.24a6 6 0 0 0-8.49-8.49L5 10.5V19h8.5z"/>\
    <line x1="16" y1="8" x2="2" y2="22"/>\
    <line x1="17.5" y1="15" x2="9" y2="15"/>\
    </svg>
    """

    private static func featherImage() -> NSImage? {
        guard let data = featherSVG.data(using: .utf8),
              let image = NSImage(data: data)
        else { return nil }
        // Menu-bar status icons are nominally 18pt tall; size the SVG to match.
        image.size = NSSize(width: 16, height: 16)
        return image
    }

    @objc private func quitClicked() {
        NSApp.terminate(nil)
    }
}

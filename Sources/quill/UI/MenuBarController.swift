import AppKit

/// Status bar item in the top-right of the menu bar. Shows recording state at
/// a glance and provides the only persistent control surface for the daemon
/// (since we run as `.accessory` — no dock icon, no main window).
@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let menu: NSMenu
    private let modelLabel: NSMenuItem
    private let stateLabel: NSMenuItem
    private let modelSubmenu: NSMenu
    private var modelID: String
    private var box: TranscriberBox?

    /// Called when the user picks a model that isn't downloaded yet and
    /// confirms — Quill.swift owns opening the app window / showing progress
    /// from here, this class only handles the menu itself.
    var onModelNeedsDownload: ((TranscriptionModel) -> Void)?

    init(modelID: String) {
        self.modelID = modelID
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        menu = NSMenu()
        menu.autoenablesItems = false

        stateLabel = NSMenuItem(title: "idle · hold fn to dictate", action: nil, keyEquivalent: "")
        stateLabel.isEnabled = false
        menu.addItem(stateLabel)

        modelLabel = NSMenuItem(title: "model: \(modelID)", action: nil, keyEquivalent: "")
        modelLabel.isEnabled = false
        menu.addItem(modelLabel)

        modelSubmenu = NSMenu()
        let modelItem = NSMenuItem(title: "Switch Model", action: nil, keyEquivalent: "")
        modelItem.submenu = modelSubmenu
        menu.addItem(modelItem)

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

    /// Wires the "Switch Model" submenu to a live TranscriberBox. Call once
    /// the daemon has an actual running transcriber to swap.
    func attachModelSwitcher(box: TranscriberBox) {
        self.box = box
        rebuildModelSubmenu()
    }

    private func rebuildModelSubmenu() {
        modelSubmenu.removeAllItems()
        for model in ModelRegistry.shared {
            let item = NSMenuItem(
                title: model.displayName,
                action: #selector(modelSelected(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = model.id
            item.state = (model.id == modelID) ? .on : .off
            modelSubmenu.addItem(item)
        }
    }

    @objc private func modelSelected(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let model = ModelRegistry.find(id),
              id != modelID
        else { return }

        if ModelAvailability.isDownloaded(model) {
            switchToModel(model)
            return
        }

        let alert = NSAlert()
        alert.messageText = "Download \(model.displayName)?"
        alert.informativeText = "\(model.sizeMB) MB — not on this Mac yet. Download and switch to it?"
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            onModelNeedsDownload?(model)
        }
    }

    /// Switches a model already confirmed present on disk — fast (just
    /// loads into memory), so no progress UI needed.
    func switchToModel(_ model: TranscriptionModel) {
        guard let box else { return }
        let transcriber = TranscriberFactory.make(for: model)
        Task {
            do {
                try await transcriber.warmUp()
                box.switchTo(transcriber, modelID: model.id)
                updateModel(model.id)
            } catch {
                FileHandle.standardError.write(Data("model switch failed: \(error)\n".utf8))
            }
        }
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
        rebuildModelSubmenu()
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

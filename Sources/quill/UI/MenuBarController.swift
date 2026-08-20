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
    private(set) var modelID: String
    private var box: TranscriberBox?
    private var isSwitching = false

    /// Called when the user picks a model that isn't downloaded yet and
    /// confirms — Quill.swift owns opening the app window / showing progress
    /// from here, this class only handles the menu itself.
    var onModelNeedsDownload: ((TranscriptionModel) -> Void)?

    /// "Open Quill" — shows the full Dictation/Insights/Style/Settings
    /// window. Quill.swift owns the actual window; this class just fires
    /// the request.
    var onOpenMain: (() -> Void)?

    /// "Settings…" — same main window, opened straight to the Settings
    /// sheet. Quill.swift owns the actual window.
    var onOpenSettings: (() -> Void)?

    /// "Check for Updates…" — Quill.swift owns the actual window.
    var onCheckForUpdates: (() -> Void)?

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

        let copyLastTranscript = NSMenuItem(
            title: "Copy Last Transcript",
            action: #selector(copyLastTranscriptClicked),
            keyEquivalent: ""
        )
        copyLastTranscript.target = self
        menu.addItem(copyLastTranscript)

        menu.addItem(.separator())

        let openMain = NSMenuItem(
            title: "Open Quill",
            action: #selector(openMainClicked),
            keyEquivalent: ""
        )
        openMain.target = self
        menu.addItem(openMain)

        let settings = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettingsClicked),
            keyEquivalent: ","
        )
        settings.target = self
        menu.addItem(settings)

        let checkForUpdates = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdatesClicked),
            keyEquivalent: ""
        )
        checkForUpdates.target = self
        menu.addItem(checkForUpdates)

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
              let model = ModelRegistry.find(id)
        else { return }
        selectModel(model)
    }

    /// Shared entry point for "the user picked a model" — used by both the
    /// menu's own submenu and Settings > General > Models, so the
    /// already-downloaded-vs-needs-confirm-and-download logic lives in
    /// exactly one place.
    func selectModel(_ model: TranscriptionModel) {
        guard model.id != modelID else { return }

        if ModelAvailability.isDownloaded(model) {
            switchToModel(model)
            return
        }

        let alert = NSAlert()
        alert.messageText = "Download \(model.displayName)?"
        alert.informativeText = "\(model.sizeMB) MB, not on this Mac yet. Download and switch to it?"
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            onModelNeedsDownload?(model)
        }
    }

    /// Switches a model already confirmed present on disk. Still takes a
    /// couple seconds to load the CoreML model into memory, so show
    /// "switching…" in the meantime instead of looking like nothing
    /// happened — this was confusing enough in practice to be worth fixing.
    func switchToModel(_ model: TranscriptionModel) {
        guard let box, !isSwitching else { return }
        isSwitching = true
        let previousState = stateLabel.title
        stateLabel.title = "switching model…"
        let transcriber = TranscriberFactory.make(for: model)
        Task {
            do {
                try await transcriber.warmUp()
                box.switchTo(transcriber, modelID: model.id)
                updateModel(model.id)
                stateLabel.title = previousState
            } catch {
                FileHandle.standardError.write(Data("model switch failed: \(error)\n".utf8))
                stateLabel.title = previousState
            }
            isSwitching = false
        }
    }

    func setRecording(_ recording: Bool) {
        stateLabel.title = recording ? "● recording" : "idle · hold fn to dictate"
    }

    func setTranscribing() {
        stateLabel.title = "transcribing…"
    }

    func setPolishing() {
        stateLabel.title = "polishing…"
    }

    /// Called once onboarding picks a model (the initial `modelID` may just
    /// be a placeholder like "not set" if the menu bar had to appear before
    /// a choice was made).
    func updateModel(_ id: String) {
        modelID = id
        modelLabel.title = "model: \(id)"
        rebuildModelSubmenu()
        NotificationCenter.default.post(name: .quillModelChanged, object: nil)
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

    @objc private func openMainClicked() {
        onOpenMain?()
    }

    @objc private func openSettingsClicked() {
        onOpenSettings?()
    }

    @objc private func checkForUpdatesClicked() {
        onCheckForUpdates?()
    }

    /// Self-contained — unlike Open Quill/Settings/Check for Updates,
    /// this never needs a window, so it doesn't go through a callback
    /// Quill.swift has to wire up. Newest entry first per
    /// `DictationHistory.loadAll()`'s own ordering.
    @objc private func copyLastTranscriptClicked() {
        guard let latest = DictationHistory.loadAll().first else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(latest.text, forType: .string)
    }

    @objc private func quitClicked() {
        NSApp.terminate(nil)
    }
}

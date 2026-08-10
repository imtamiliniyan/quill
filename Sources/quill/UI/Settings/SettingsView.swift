import SwiftUI

private enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case system = "System"
    case privacy = "Data & Privacy"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .general: return "person"
        case .system: return "gearshape"
        case .privacy: return "lock.shield"
        }
    }
}

struct SettingsView: View {
    let menuBar: MenuBarController
    @Environment(\.dismiss) private var dismiss
    @State private var tab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .help("Close (Esc)")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            Picker("", selection: $tab) {
                ForEach(SettingsTab.allCases) { t in
                    Label(t.rawValue, systemImage: t.icon).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(16)

            Divider().opacity(0.2)

            Group {
                switch tab {
                case .general: GeneralSettingsView(menuBar: menuBar)
                case .system: SystemSettingsView()
                case .privacy: PrivacySettingsView()
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 460, height: 380)
        .background(Theme.background)
        .foregroundColor(Theme.textPrimary)
    }
}

private struct GeneralSettingsView: View {
    let menuBar: MenuBarController
    @State private var firstName = QuillProfile.firstName
    @State private var lastName = QuillProfile.lastName

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Your name").font(.system(size: 13, weight: .semibold))
                    HStack(spacing: 10) {
                        TextField("First name", text: $firstName)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: firstName) { _, new in QuillProfile.firstName = new }
                        TextField("Last name", text: $lastName)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: lastName) { _, new in QuillProfile.lastName = new }
                    }
                    Text("Shown only inside Quill on this Mac. There's no account or sign-in.")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }

                Divider().opacity(0.15)

                ModelsSettingsView(menuBar: menuBar)
            }
        }
    }
}

/// Radio-button model picker plus a per-model delete (trash icon), so
/// switching or freeing up disk space never requires the terminal —
/// mirrors exactly what the menu bar's "Switch Model" submenu already does,
/// through the same `MenuBarController.selectModel` entry point.
private struct ModelsSettingsView: View {
    let menuBar: MenuBarController
    @State private var currentModelID: String
    @State private var confirmingDelete: TranscriptionModel?
    @State private var deleteError: String?

    init(menuBar: MenuBarController) {
        self.menuBar = menuBar
        _currentModelID = State(initialValue: menuBar.modelID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Models").font(.system(size: 13, weight: .semibold))
            Text("Choose which model transcribes your dictation. Downloaded models can be removed here to free up space.")
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)

            VStack(spacing: 8) {
                ForEach(ModelRegistry.shared, id: \.id) { model in
                    modelRow(model)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .quillModelChanged)) { _ in
            currentModelID = menuBar.modelID
        }
        .confirmationDialog(
            "Delete \(confirmingDelete?.displayName ?? "")? You'll need to download it again to use it.",
            isPresented: Binding(
                get: { confirmingDelete != nil },
                set: { if !$0 { confirmingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Model", role: .destructive) {
                if let model = confirmingDelete { delete(model) }
                confirmingDelete = nil
            }
            Button("Cancel", role: .cancel) { confirmingDelete = nil }
        }
        .alert(
            "Couldn't delete model",
            isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )
        ) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    private func modelRow(_ model: TranscriptionModel) -> some View {
        let selected = model.id == currentModelID
        let downloaded = ModelAvailability.isDownloaded(model)
        return HStack(spacing: 10) {
            Button {
                guard !selected else { return }
                menuBar.selectModel(model)
                currentModelID = menuBar.modelID
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                        .foregroundColor(selected ? Theme.accent : Theme.textTertiary)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(model.displayName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Theme.textPrimary)
                            if model.recommended {
                                Text("RECOMMENDED")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(Theme.accent)
                            }
                        }
                        Text(downloaded ? "\(model.sizeMB) MB · downloaded" : "\(model.sizeMB) MB · not downloaded")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textTertiary)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if downloaded && !selected {
                Button {
                    confirmingDelete = model
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Delete downloaded model")
            }
        }
        .padding(10)
        .background(selected ? Theme.fillHover : Theme.textQuaternary)
        .cornerRadius(8)
    }

    private func delete(_ model: TranscriptionModel) {
        do {
            try ModelAvailability.deleteFiles(for: model)
        } catch {
            deleteError = error.localizedDescription
        }
    }
}

private struct SystemSettingsView: View {
    @State private var launchAtLogin = LaunchAtLoginManager.isEnabled
    @State private var darkModeEnabled = QuillSettings.darkModeEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Launch Quill at login", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .tint(Theme.accent)
                .onChange(of: launchAtLogin) { _, wantsOn in
                    let ok = LaunchAtLoginManager.setEnabled(wantsOn)
                    if !ok { launchAtLogin = LaunchAtLoginManager.isEnabled }
                }
            Text("Runs quietly in the menu bar as soon as you log in. No dock icon until you open this window.")
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)

            Divider().opacity(0.15)

            Toggle("Enable Dark Mode", isOn: $darkModeEnabled)
                .toggleStyle(.switch)
                .tint(Theme.accent)
                .onChange(of: darkModeEnabled) { _, wantsOn in
                    QuillSettings.darkModeEnabled = wantsOn
                }
            Text("Overrides System Settings > Appearance for Quill specifically. Takes effect immediately.")
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
        }
    }
}

private struct PrivacySettingsView: View {
    @State private var confirmingClear = false
    @State private var historyCount = DictationHistory.loadAll().count
    @State private var autoCleanupLevel = QuillSettings.autoCleanupLevel
    private var apiKeyConnected: Bool {
        StyleProvider.allCases.contains { APIKeyStore.hasKey(for: $0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Everything stays on this Mac", systemImage: "lock.shield.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.accent)

            Text("""
            Quill transcribes with an on-device model. Your dictation history, \
            transcripts, and settings never leave this Mac and are never sent \
            to a cloud service, including Anthropic, OpenAI, or Quill's own \
            developer.
            """)
            .font(.system(size: 12))
            .foregroundColor(Theme.textPrimary)

            Text("""
            The one exception: Style's cloud rewriting, using your own OpenAI or \
            Anthropic key. That happens either when you press Rewrite in Style, \
            or automatically on every dictation if Auto Cleanup is set to \
            Medium. In that case, every dictation is sent to your chosen \
            provider before it's typed. Auto Cleanup's Light level, and Style's \
            "Clean Up" tone, never touch the network at all.
            """)
            .font(.system(size: 12))
            .foregroundColor(Theme.textSecondary)

            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 11))
                    .foregroundColor(autoCleanupLevel == .medium ? Theme.accent : Theme.textTertiary)
                Text("Auto Cleanup is set to \(autoCleanupLevel.rawValue).")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }

            HStack(spacing: 6) {
                Image(systemName: apiKeyConnected ? "key.fill" : "key")
                    .font(.system(size: 11))
                    .foregroundColor(apiKeyConnected ? Theme.accent : Theme.textTertiary)
                Text(apiKeyConnected ? "A Style API key is connected." : "No Style API key connected.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }

            Divider().opacity(0.15)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dictation history")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                    Text("\(historyCount) \(historyCount == 1 ? "entry" : "entries") stored locally")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
                Button(role: .destructive) {
                    confirmingClear = true
                } label: {
                    Text("Clear history")
                }
                .disabled(historyCount == 0)
            }
            .confirmationDialog(
                "Delete all \(historyCount) dictation history entries? This can't be undone.",
                isPresented: $confirmingClear,
                titleVisibility: .visible
            ) {
                Button("Delete History", role: .destructive) {
                    DictationHistory.clear()
                    historyCount = 0
                }
                Button("Cancel", role: .cancel) {}
            }

            Spacer()
        }
        .onReceive(NotificationCenter.default.publisher(for: .quillHistoryUpdated)) { _ in
            historyCount = DictationHistory.loadAll().count
        }
    }
}

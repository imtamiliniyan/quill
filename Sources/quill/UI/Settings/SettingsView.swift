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
    @State private var activationMode = QuillSettings.activationMode
    @State private var lowercaseFirstLetter = QuillSettings.lowercaseFirstLetter
    @State private var spaceBetweenDictations = QuillSettings.spaceBetweenDictations
    @State private var smartCapitalization = QuillSettings.smartCapitalization

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

                VStack(alignment: .leading, spacing: 10) {
                    Text("Primary Dictation Shortcut").font(.system(size: 13, weight: .semibold))
                    HStack {
                        Text("fn (Globe key)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        Text("Fixed for now")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(Theme.textTertiary)
                    }
                    .padding(10)
                    .background(Theme.textQuaternary)
                    .cornerRadius(8)
                    Text("Custom key remapping isn't available yet. Every install listens on fn.")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)

                    Picker("", selection: $activationMode) {
                        ForEach(ActivationMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.top, 4)
                    .onChange(of: activationMode) { _, new in
                        QuillSettings.activationMode = new
                    }
                    Text(activationMode.detail)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }

                Divider().opacity(0.15)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Text Formatting").font(.system(size: 13, weight: .semibold))

                    VStack(alignment: .leading, spacing: 2) {
                        Toggle("Lowercase First Letter", isOn: $lowercaseFirstLetter)
                            .toggleStyle(.switch)
                            .tint(Theme.accent)
                            .font(.system(size: 12, weight: .medium))
                            .onChange(of: lowercaseFirstLetter) { _, new in
                                QuillSettings.lowercaseFirstLetter = new
                            }
                        Text("Start each transcription with a lowercase letter.")
                            .font(.system(size: 10.5))
                            .foregroundColor(Theme.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Toggle("Space Between Dictations", isOn: $spaceBetweenDictations)
                            .toggleStyle(.switch)
                            .tint(Theme.accent)
                            .font(.system(size: 12, weight: .medium))
                            .onChange(of: spaceBetweenDictations) { _, new in
                                QuillSettings.spaceBetweenDictations = new
                            }
                        Text("Add a leading space when the cursor isn't already after whitespace.")
                            .font(.system(size: 10.5))
                            .foregroundColor(Theme.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Toggle("Smart Capitalization", isOn: $smartCapitalization)
                            .toggleStyle(.switch)
                            .tint(Theme.accent)
                            .font(.system(size: 12, weight: .medium))
                            .onChange(of: smartCapitalization) { _, new in
                                QuillSettings.smartCapitalization = new
                            }
                        Text("Use text before the cursor to choose uppercase or lowercase.")
                            .font(.system(size: 10.5))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
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
    @State private var debugLoggingEnabled = QuillSettings.debugLoggingEnabled
    @State private var debugLogByteCount = 0
    @State private var confirmingClearLog = false
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
            provider before it's typed. Auto Cleanup's None and Local AI levels, \
            and Style's "Clean Up" tone, never touch the network at all.
            """)
            .font(.system(size: 12))
            .foregroundColor(Theme.textSecondary)

            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 11))
                    .foregroundColor(autoCleanupLevel == .medium ? Theme.accent : Theme.textTertiary)
                Text("Auto Cleanup is set to \(autoCleanupLevel.displayName).")
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

            Divider().opacity(0.15)

            debugLoggingSection

            Spacer()
        }
        .onReceive(NotificationCenter.default.publisher(for: .quillHistoryUpdated)) { _ in
            historyCount = DictationHistory.loadAll().count
        }
        .task {
            debugLogByteCount = await QuillLog.shared.approximateByteCount()
        }
    }

    // MARK: - Debug logging

    /// On by default (`QuillSettings.debugLoggingEnabled`) so a real log
    /// already exists the moment a bug is worth reporting. Captures app
    /// errors and status messages only — model loads, hotkey failures,
    /// Auto Cleanup fallbacks — via `QuillLog`'s stderr redirect, never
    /// dictated text. Stays purely local either way: the toggle here
    /// controls whether anything is *retained* at all, not whether
    /// anything is sent anywhere — that only ever happens if the user
    /// attaches it themselves in Send Feedback.
    private var debugLoggingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Debug logging")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                    Text("App errors and status only, never dictated text. Attach it yourself in Send Feedback if you want to.")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Toggle("", isOn: $debugLoggingEnabled)
                    .toggleStyle(.switch)
                    .tint(Theme.accent)
                    .labelsHidden()
                    .onChange(of: debugLoggingEnabled) { _, wantsOn in
                        QuillSettings.debugLoggingEnabled = wantsOn
                        if !wantsOn { debugLogByteCount = 0 }
                    }
            }

            if debugLoggingEnabled {
                HStack {
                    Text(debugLogByteCount > 0 ? "\(formattedByteCount(debugLogByteCount)) captured" : "Nothing captured yet")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                    Spacer()
                    Button(role: .destructive) {
                        confirmingClearLog = true
                    } label: {
                        Text("Clear log")
                    }
                    .disabled(debugLogByteCount == 0)
                }
            }
        }
        .confirmationDialog(
            "Clear the captured debug log?",
            isPresented: $confirmingClearLog,
            titleVisibility: .visible
        ) {
            Button("Clear Log", role: .destructive) {
                Task {
                    await QuillLog.shared.clear()
                    debugLogByteCount = 0
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func formattedByteCount(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        return String(format: "%.0f KB", Double(bytes) / 1024)
    }
}

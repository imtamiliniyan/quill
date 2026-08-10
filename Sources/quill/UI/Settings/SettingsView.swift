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
    @State private var tab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
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
                case .general: GeneralSettingsView()
                case .system: SystemSettingsView()
                case .privacy: PrivacySettingsView()
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 460, height: 380)
        .background(Theme.background)
        .foregroundColor(.white)
    }
}

private struct GeneralSettingsView: View {
    @State private var firstName = QuillProfile.firstName
    @State private var lastName = QuillProfile.lastName

    var body: some View {
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
            Text("Shown only inside Quill on this Mac — there's no account or sign-in.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
        }
    }
}

private struct SystemSettingsView: View {
    @State private var launchAtLogin = LaunchAtLoginManager.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Launch Quill at login", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .tint(Theme.accent)
                .onChange(of: launchAtLogin) { _, wantsOn in
                    let ok = LaunchAtLoginManager.setEnabled(wantsOn)
                    if !ok { launchAtLogin = LaunchAtLoginManager.isEnabled }
                }
            Text("Runs quietly in the menu bar as soon as you log in — no dock icon until you open this window.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
        }
    }
}

private struct PrivacySettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Everything stays on this Mac", systemImage: "lock.shield.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.accent)

            Text("""
            Quill transcribes with an on-device model. Your dictation history, \
            transcripts, and settings never leave this Mac and are never sent \
            to a cloud service — including Anthropic, OpenAI, or Quill's own \
            developer.
            """)
            .font(.system(size: 12))
            .foregroundColor(.white.opacity(0.75))

            Text("""
            The one exception: if you add your own OpenAI or Anthropic API key \
            in Style (coming soon) to rewrite tone, the text you choose to \
            rewrite is sent directly to that provider using your key. Nothing \
            else is ever transmitted, and rewriting is off unless you turn it on.
            """)
            .font(.system(size: 12))
            .foregroundColor(.white.opacity(0.55))

            Spacer()
        }
    }
}

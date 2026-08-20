import AppKit
import SwiftUI

/// "Check for Updates…" from the menu bar. Compares the running app's
/// `CFBundleShortVersionString` against the newest real GitHub Release
/// (`GitHubReleases.latest()`) — the same live source the Change Log tab
/// reads from, so this can never disagree with what that tab shows.
///
/// Update-available state deliberately doesn't dump the full changelog
/// here — just the first couple of bullets plus a "More" link that jumps
/// to the Change Log tab for the rest, so this stays a quick glance, not
/// a second copy of that tab's UI.
struct UpdateCheckView: View {
    enum CheckState {
        case loading
        case upToDate
        case updateAvailable(version: String, changes: [String], releaseURL: URL)
        case error(String)
    }

    @State private var state: CheckState = .loading
    let onDismiss: () -> Void
    let onShowFullChangeLog: () -> Void

    private var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
    }

    var body: some View {
        VStack(spacing: 18) {
            icon
                .font(.system(size: 40))
                .foregroundColor(iconColor)

            switch state {
            case .loading:
                ProgressView()
                Text("Checking for updates…")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)

            case .upToDate:
                VStack(spacing: 6) {
                    Text("You're Up to Date")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text("You're already running the latest version of Quill (\(currentVersion)).")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                Button("OK", action: onDismiss)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)

            case .updateAvailable(let version, let changes, let releaseURL):
                VStack(spacing: 6) {
                    Text("Update Available")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text("Quill \(version) is ready to download.")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                }

                if !changes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(changes.prefix(2), id: \.self) { change in
                            HStack(alignment: .top, spacing: 6) {
                                Circle()
                                    .fill(Theme.accent)
                                    .frame(width: 4, height: 4)
                                    .padding(.top, 6)
                                Text(LocalizedStringKey(change))
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        if changes.count > 2 {
                            Button("More… (\(changes.count - 2) more \(changes.count - 2 == 1 ? "change" : "changes"))") {
                                onShowFullChangeLog()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Theme.accent)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Theme.textQuaternary)
                    .cornerRadius(8)
                }

                HStack(spacing: 10) {
                    Button("Later", action: onDismiss)
                        .buttonStyle(.bordered)
                    Button("Download") {
                        NSWorkspace.shared.open(releaseURL)
                        onDismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                }

            case .error(let message):
                VStack(spacing: 6) {
                    Text("Couldn't Check for Updates")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                Button("OK", action: onDismiss)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
            }
        }
        .padding(28)
        .frame(width: 320)
        .background(Theme.background)
        .task { await check() }
    }

    private var icon: Image {
        switch state {
        case .loading: return Image(systemName: "arrow.triangle.2.circlepath")
        case .upToDate: return Image(systemName: "checkmark.seal.fill")
        case .updateAvailable: return Image(systemName: "arrow.down.circle.fill")
        case .error: return Image(systemName: "exclamationmark.triangle.fill")
        }
    }

    private var iconColor: Color {
        switch state {
        case .loading: return Theme.textTertiary
        case .upToDate: return Theme.accent
        case .updateAvailable: return Theme.accent
        case .error: return .orange
        }
    }

    private func check() async {
        do {
            guard let latest = try await GitHubReleases.latest() else {
                await MainActor.run { state = .upToDate }
                return
            }
            let tag = latest.id
            if GitHubReleases.isNewer(tag: tag, than: currentVersion) {
                let releaseURL = URL(string: "https://github.com/imtamiliniyan/quill/releases/tag/\(tag)")!
                await MainActor.run {
                    state = .updateAvailable(version: tag, changes: latest.changes, releaseURL: releaseURL)
                }
            } else {
                await MainActor.run { state = .upToDate }
            }
        } catch {
            await MainActor.run {
                state = .error("Couldn't reach GitHub to check. Try again in a moment.")
            }
        }
    }
}

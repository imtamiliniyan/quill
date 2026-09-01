import AppKit
import SwiftUI

/// A real sidebar tab (peer to Dictation/Insights/.../Feedback) — the
/// fuller "support the project" surface. Distinct from Feedback's own
/// compact "Support Quill" card (`FeedbackView.lovingQuillCard`), which
/// stays exactly as it is on earlier explicit instruction (scoped down
/// to one button, no separate GitHub-star ask) — this tab is the richer
/// one, not a replacement for that.
///
/// Layout reference: a similar section in another indie macOS app,
/// adapted to Quill's own real support channels (GitHub Sponsors, not
/// Buy Me a Coffee — that's what Quill actually has set up per
/// `FeedbackView`'s own `githubURL`) and real contact info. No code or
/// branding borrowed, same standing rule as every other layout reference
/// in this codebase.
struct SupportView: View {
    private static let sponsorsURL = URL(string: "https://github.com/sponsors/imtamiliniyan")!
    private static let repoURL = URL(string: "https://github.com/imtamiliniyan/quill")!
    private static let xURL = URL(string: "https://x.com/iniyanai")!
    // Same address Feedback already sends to — one real inbox, not two.
    private static let contactEmail = "tamil@iniyan.pro"

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Support")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, Theme.pagePadding)
                .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 16) {
                    growCard
                    starCard
                    aboutCard
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Help Quill keep growing

    private var growCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: "heart.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Theme.accent)
            }
            Text("Help Quill keep growing")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            Text("Quill is free, open source, and built in my spare time. If you'd like to contribute financially, GitHub Sponsors directly helps me keep development moving forward.")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                NSWorkspace.shared.open(Self.sponsorsURL)
            } label: {
                Label("Support on GitHub Sponsors", systemImage: "heart.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .quillCard()
    }

    // MARK: - Star on GitHub

    private var starCard: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: "star.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.yellow)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Financial support is never expected. A star on GitHub helps more people discover Quill and makes a real difference to its development.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                Button {
                    NSWorkspace.shared.open(Self.repoURL)
                } label: {
                    Label("Star Quill on GitHub", systemImage: "star")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .quillCard()
    }

    // MARK: - About

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textTertiary)

            HStack {
                Text("Built by Tamil Iniyan")
                    .font(.system(size: 12.5))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                HStack(spacing: 8) {
                    Button("@iniyanai") {
                        NSWorkspace.shared.open(Self.xURL)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Button("Email") {
                        openEmail()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Divider().opacity(0.15)

            HStack {
                Text("Version \(version)")
                    .font(.system(size: 12.5))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Button("Check for updates") {
                    AppUpdater.shared.checkForUpdates()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(18)
        .quillCard()
    }

    /// A plain `mailto:`, deliberately not Feedback's structured flow —
    /// this is "get in touch," not "report a bug with a debug-log
    /// attachment." That heavier form stays exactly where it is, in
    /// Feedback, per explicit instruction.
    private func openEmail() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Self.contactEmail
        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }
}

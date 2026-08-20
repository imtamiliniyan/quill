import AppKit
import SwiftUI

/// A real sidebar tab (peer to Dictation/Insights/Style/Voice Engine/
/// Enhancement Engine/Change Log/Getting Started). FluidVoice's own
/// Feedback tab is the layout reference (structure only, no code/branding
/// borrowed, same standing rule as elsewhere) — but scoped down on
/// explicit instruction: one "Support Quill" button instead of their two
/// (Star on GitHub + Support), and no fake "Send" button pretending to
/// hit a backend Quill doesn't have. The form below is genuinely
/// functional with zero new infrastructure: it opens a pre-filled
/// `mailto:` draft in the user's own mail client, addressed to Quill's
/// real, already-public contact address (same one already used on the
/// landing site's privacy/terms pages).
struct FeedbackView: View {
    @State private var emailField: String = ""
    @State private var feedbackText: String = ""
    @State private var includeDebugInfo = false

    private static let contactEmail = "tamil@iniyan.pro"
    // Sponsors enrollment is approved and live — points here now instead
    // of the bare repo URL.
    private static let githubURL = URL(string: "https://github.com/sponsors/imtamiliniyan")!

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "envelope")
                    .font(.system(size: 17))
                    .foregroundColor(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Send Feedback")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text("Help us improve Quill")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, Theme.pagePadding)
            .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 16) {
                    lovingQuillCard
                    feedbackFormCard
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Loving Quill?

    private var lovingQuillCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "star.fill")
                .font(.system(size: 16))
                .foregroundColor(.yellow)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text("Loving Quill?")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text("Support continued development to help make local dictation even better.")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Button("Support Quill") {
                NSWorkspace.shared.open(Self.githubURL)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
        }
        .padding(16)
        .quillCard()
    }

    // MARK: - Feedback form

    private var feedbackFormCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Email (optional)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                TextField("your.email@example.com", text: $emailField)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Feedback")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $feedbackText)
                        .font(.system(size: 13))
                        .scrollContentBackground(.hidden)
                        .frame(height: 110)
                        .padding(6)
                        .background(Theme.textQuaternary)
                        .cornerRadius(8)

                    if feedbackText.isEmpty {
                        Text("Share your thoughts, report bugs, or suggest features…")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.textTertiary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 14)
                            .allowsHitTesting(false)
                    }
                }
            }

            Toggle(isOn: $includeDebugInfo) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Include debug info")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                    Text("macOS version and current model/provider, no dictation content.")
                        .font(.system(size: 10.5))
                        .foregroundColor(Theme.textTertiary)
                }
            }
            .toggleStyle(.switch)

            HStack {
                Spacer()
                Button {
                    sendFeedback()
                } label: {
                    Label("Send Feedback", systemImage: "paperplane.fill")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(feedbackText.isEmpty)
            }

            Text("Opens a pre-filled email to \(Self.contactEmail) in your Mac's default mail app. Quill has no server of its own to send this to.")
                .font(.system(size: 10.5))
                .foregroundColor(Theme.textTertiary)
        }
        .padding(18)
        .quillCard()
    }

    private func sendFeedback() {
        var body = feedbackText
        if !emailField.isEmpty {
            body += "\n\nReply to: \(emailField)"
        }
        if includeDebugInfo {
            body += "\n\n---\nQuill debug info\nmacOS: \(ProcessInfo.processInfo.operatingSystemVersionString)\nModel: \(QuillSettings.selectedModelID ?? "none")\nStyle provider: \(QuillSettings.styleProvider.rawValue)"
        }

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Self.contactEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Quill Feedback"),
            URLQueryItem(name: "body", value: body),
        ]
        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }
}

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
    // What "Include debug info" actually attaches now — QuillLog's real
    // captured output (model loads, hotkey failures, Auto Cleanup
    // fallbacks), not just the static macOS/model line this toggle used
    // to add. Loaded lazily (only once the toggle is actually turned on)
    // so opening this tab never pays for it unasked.
    @State private var debugLogPreview: String = ""
    @State private var debugLoggingEnabled = QuillSettings.debugLoggingEnabled
    // "Send Feedback" is fire-and-forget — `NSWorkspace.shared.open` on a
    // mailto: URL can hand off to whatever's registered for that scheme
    // and report success even when nothing usable happens next (e.g. the
    // scheme is registered to a browser with no mailto handler, a real
    // case hit during testing — LSHandlers had mailto: pointed at Chrome).
    // Rather than trying to detect that unreliably, always offer this as
    // a working fallback: copy the same message as plain text so it can
    // be pasted into an email by hand.
    @State private var copiedFallback = false

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
                    Text(
                        debugLoggingEnabled
                            ? "macOS version, current model/provider, and recent app log — never dictation content."
                            : "Debug logging is off in Settings, so only macOS version and current model/provider are included."
                    )
                    .font(.system(size: 10.5))
                    .foregroundColor(Theme.textTertiary)
                }
            }
            .toggleStyle(.switch)
            .onChange(of: includeDebugInfo) { _, isOn in
                guard isOn, debugLoggingEnabled else { return }
                Task { debugLogPreview = await QuillLog.shared.recentText() }
            }

            // Shows exactly what would get attached, before it's ever
            // sent — same "never blind trust" reasoning as everywhere
            // else in Quill that touches an outside destination.
            if includeDebugInfo && debugLoggingEnabled && !debugLogPreview.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Attached log preview")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                    ScrollView {
                        Text(debugLogPreview)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(height: 90)
                    .padding(8)
                    .background(Theme.textQuaternary)
                    .cornerRadius(8)
                }
            }

            HStack {
                Spacer()
                Button {
                    copyFeedback()
                } label: {
                    Label(copiedFallback ? "Copied" : "Copy Instead", systemImage: copiedFallback ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .disabled(feedbackText.isEmpty)
                .help("Copy this as plain text — useful if Send Feedback doesn't open a mail app.")

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

            Text(
                "Opens a pre-filled email to \(Self.contactEmail) in your Mac's default mail app. "
                    + "Quill has no server of its own to send this to. If nothing opens, use \"Copy Instead\" "
                    + "and paste it into an email yourself."
            )
            .font(.system(size: 10.5))
            .foregroundColor(Theme.textTertiary)
        }
        .padding(18)
        .quillCard()
    }

    /// The message body, shared by the real `mailto:` send and the plain-text
    /// copy fallback — one place building it instead of two copies drifting
    /// apart.
    private func feedbackBody() -> String {
        var body = feedbackText
        if !emailField.isEmpty {
            body += "\n\nReply to: \(emailField)"
        }
        if includeDebugInfo {
            body += "\n\n---\nQuill debug info\nmacOS: \(ProcessInfo.processInfo.operatingSystemVersionString)\nModel: \(QuillSettings.selectedModelID ?? "none")\nStyle provider: \(QuillSettings.styleProvider.rawValue)"
            if debugLoggingEnabled && !debugLogPreview.isEmpty {
                body += "\n\nRecent log:\n\(debugLogPreview)"
            }
        }
        return body
    }

    private func sendFeedback() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Self.contactEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Quill Feedback"),
            URLQueryItem(name: "body", value: feedbackBody()),
        ]
        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }

    private func copyFeedback() {
        let text = "To: \(Self.contactEmail)\nSubject: Quill Feedback\n\n\(feedbackBody())"
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        copiedFallback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copiedFallback = false }
    }
}

import SwiftUI

/// Floating pill hosted in the window's real title bar (via
/// `NSTitlebarAccessoryViewController`, wired up in MainWindow.swift) —
/// a rounded capsule with its own fill/stroke, deliberately distinct from
/// the bare titlebar chrome around it. Always visible next to the traffic
/// lights regardless of which sidebar tab is showing, since a titlebar
/// accessory sits outside MainView's content tree entirely.
///
/// A one-tap light/dark toggle (the same `QuillSettings.darkModeEnabled`
/// Settings already exposes, just reachable without a trip there) and a
/// bug icon that jumps straight into the real Feedback tab — no new
/// reporting mechanism, just a shortcut into FeedbackView's existing
/// working `mailto:` flow. Word count / time saved were tried here too
/// (see git history) but didn't fit the titlebar's width without
/// truncating, so they stay full-size on Insights instead.
struct TitleBarStatsView: View {
    let state: AppViewState

    @State private var darkModeEnabled = QuillSettings.darkModeEnabled

    var body: some View {
        HStack(spacing: 10) {
            Button {
                darkModeEnabled.toggle()
                QuillSettings.darkModeEnabled = darkModeEnabled
            } label: {
                Image(systemName: darkModeEnabled ? "moon.fill" : "sun.max.fill")
                    .font(.system(size: 13))
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(darkModeEnabled ? "Switch to Light Mode" : "Switch to Dark Mode")

            Button {
                state.selection = .feedback
            } label: {
                Image(systemName: "ladybug.fill")
                    .font(.system(size: 13))
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Report a bug or send feedback")
        }
        .foregroundColor(Theme.textPrimary)
        .padding(.horizontal, 12)
    }
}

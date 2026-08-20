import Sparkle

/// The single source of truth for "is there a new Quill build" — owns
/// both the automatic background poll (once a day, `SUScheduledCheckInterval`
/// in Info.plist) and the manual "Check for Updates…" menu click, through
/// the same `SPUStandardUpdaterController`. Sparkle shows its own native
/// alert either way (found or not), downloads the signed update, verifies
/// it against `SUPublicEDKey` in Info.plist, and installs it.
///
/// Replaces the earlier hand-rolled pair (`UpdateCheckView` +
/// `GitHubReleases.latest()`/`isNewer()`) — that was a second, separate
/// "is this newer" check reading the GitHub API directly, which could in
/// principle disagree with what Sparkle's own appcast says. One checker
/// now, not two.
@MainActor
final class AppUpdater {
    static let shared = AppUpdater()

    private let controller: SPUStandardUpdaterController

    private init() {
        // `startingUpdater: true` begins the scheduled background check
        // immediately on first access — call `AppUpdater.shared` once at
        // launch (Quill.swift) purely to trigger this, even before the
        // user ever opens the menu.
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    /// "Check for Updates…" — same entry point the automatic background
    /// check uses internally, just user-initiated.
    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }
}

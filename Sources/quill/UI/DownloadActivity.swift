import Foundation

/// Global "something is downloading right now" signal (Phase 5a) — lets a
/// persistent bar at the top of the main window show progress no matter
/// which sidebar tab is in front, instead of progress living only in
/// whichever view happened to start the download.
///
/// Concretely fixes two real gaps: (1) the menu bar's model-switch download
/// runs in a separate, user-closable window (`ModelDownloadView` in
/// `MainWindow.swift`) whose Task keeps running even after that window is
/// closed, with nothing left visible anywhere; (2) Style's Local AI row
/// stores its progress in view-local `@State`, which SwiftUI discards the
/// moment the sidebar switches away from Style and back, even though
/// `LocalEnhancer`'s actual download keeps going the whole time.
@MainActor
final class DownloadActivity: ObservableObject {
    static let shared = DownloadActivity()
    private init() {}

    struct Item {
        let label: String
        var progress: Double?
    }

    @Published private(set) var current: Item?

    func begin(label: String) {
        current = Item(label: label, progress: 0)
    }

    func update(progress: Double) {
        guard current != nil else { return }
        current?.progress = progress
    }

    func finish() {
        current = nil
    }
}

import Foundation

/// Holds the transcriber actually in use, so it can be swapped live (menu
/// bar model switcher) without tearing down the hotkey monitor or restarting
/// the daemon. Everything that transcribes reads `current` at call time
/// instead of closing over a fixed `Transcriber`.
@MainActor
final class TranscriberBox {
    private(set) var current: Transcriber
    private(set) var modelID: String

    init(transcriber: Transcriber, modelID: String) {
        self.current = transcriber
        self.modelID = modelID
    }

    func switchTo(_ transcriber: Transcriber, modelID: String) {
        current = transcriber
        self.modelID = modelID
    }
}

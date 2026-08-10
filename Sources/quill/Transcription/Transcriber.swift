import Foundation

protocol Transcriber {
    var modelID: String { get }
    /// Loads the model into memory; downloads first if not already on disk.
    /// `progress` (0...1) is called on an arbitrary thread when download
    /// progress is available; implementations without real progress
    /// reporting simply never call it.
    func warmUp(progress: ((Double) -> Void)?) async throws
    func transcribe(_ audio: [Float]) async throws -> String
}

extension Transcriber {
    /// Convenience for call sites that don't care about progress.
    func warmUp() async throws {
        try await warmUp(progress: nil)
    }
}

enum TranscriberFactory {
    /// Picks the right engine implementation for the given model.
    static func make(for model: TranscriptionModel) -> Transcriber {
        switch model.engine {
        case .whisperKit:
            return WhisperKitTranscriber(model: model)
        case .parakeet:
            return ParakeetTranscriber(model: model)
        }
    }
}

import Foundation

protocol Transcriber {
    var modelID: String { get }
    /// Loads the model into memory; downloads first if not already on disk.
    func warmUp() async throws
    func transcribe(_ audio: [Float]) async throws -> String
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

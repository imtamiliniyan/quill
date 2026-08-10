import Foundation
import WhisperKit

actor WhisperKitTranscriber: Transcriber {
    let modelID: String
    private let model: TranscriptionModel
    private var pipeline: WhisperKit?

    init(model: TranscriptionModel) {
        self.modelID = model.id
        self.model = model
    }

    /// Loads the model into memory; downloads first if not already on disk.
    /// Call once at startup so the first hotkey press isn't blocked on model
    /// download/load. Downloading is a separate step (rather than letting
    /// `WhisperKit(config:)` do it implicitly) so real progress is available
    /// to callers — `WhisperKit.download` reports `Progress`, which nothing
    /// upstream in this file exposed before.
    func warmUp(progress: ((Double) -> Void)?) async throws {
        if pipeline != nil { return }
        guard let whisperKitID = model.whisperKitID else {
            throw TranscriberError.missingEngineID
        }
        FileHandle.standardError.write(Data("loading \(model.id)...\n".utf8))
        let modelFolder = try await WhisperKit.download(
            variant: whisperKitID,
            progressCallback: { p in progress?(p.fractionCompleted) }
        )
        let config = WhisperKitConfig(
            model: whisperKitID, modelFolder: modelFolder.path,
            verbose: false, prewarm: true, load: true
        )
        pipeline = try await WhisperKit(config)
        FileHandle.standardError.write(Data("✓ \(model.id) ready\n".utf8))
    }

    func transcribe(_ audio: [Float]) async throws -> String {
        if pipeline == nil { try await warmUp() }
        guard let pipeline else { throw TranscriberError.notLoaded }

        let results = try await pipeline.transcribe(audioArray: audio)
        let raw = results.map(\.text).joined(separator: " ")
        return TranscriptSanitizer.sanitize(raw)
    }
}

enum TranscriberError: Error {
    case missingEngineID
    case notLoaded
}

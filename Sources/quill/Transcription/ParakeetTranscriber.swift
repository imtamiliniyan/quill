import FluidAudio
import Foundation

/// Transcriber backed by NVIDIA's Parakeet TDT model, run on-device via
/// FluidAudio's CoreML port. Same 16kHz mono Float32 input contract as
/// WhisperKitTranscriber — AudioCapture already produces that.
actor ParakeetTranscriber: Transcriber {
    let modelID: String
    private let model: TranscriptionModel
    private var manager: AsrManager?

    init(model: TranscriptionModel) {
        self.modelID = model.id
        self.model = model
    }

    /// Loads the model into memory; downloads first if not already on disk.
    func warmUp(progress: ((Double) -> Void)?) async throws {
        if manager != nil { return }
        FileHandle.standardError.write(Data("loading \(model.id)...\n".utf8))
        let models = try await AsrModels.downloadAndLoad(
            version: .v3,
            progressHandler: progress.map { cb in { @Sendable p in cb(p.fractionCompleted) } }
        )
        manager = AsrManager(config: .default, models: models)
        FileHandle.standardError.write(Data("✓ \(model.id) ready\n".utf8))
    }

    func transcribe(_ audio: [Float]) async throws -> String {
        if manager == nil { try await warmUp() }
        guard let manager else { throw TranscriberError.notLoaded }
        // Fresh decoder state per utterance — each push-to-talk clip is
        // independent, same as WhisperKitTranscriber's stateless calls.
        var decoderState = TdtDecoderState.make()
        let result = try await manager.transcribe(audio, decoderState: &decoderState)
        return TranscriptSanitizer.sanitize(result.text)
    }
}

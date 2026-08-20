import Foundation

/// Built-in transcription model registry.
///
/// The model list lives directly in source rather than as a JSON resource so
/// the binary stays self-contained — no `Bundle.module` lookup, no per-target
/// resource bundle to ship alongside the executable.
///
/// Every `sizeMB` below is a real, computed number, not a guess — summed
/// from each model's actual required files (matching exactly what
/// `WhisperKitTranscriber`/`ParakeetTranscriber` download, not every file
/// in the source HuggingFace repo, which also carries redundant
/// `.mlpackage` source alongside the compiled `.mlmodelc` WhisperKit
/// actually fetches) via the HuggingFace tree API, same "don't overclaim"
/// posture as the speed/accuracy dot ratings below.
///
/// Deliberately scoped to what Quill's two existing engines
/// (WhisperKit, FluidAudio/Parakeet) can actually run — not the full
/// breadth of open-source ASR models FluidVoice's own model picker shows.
/// Its list includes SenseVoice/Paraformer (different architectures,
/// Mandarin-focused, no engine in Quill to run them), Parakeet EOU
/// (real-time streaming with end-of-utterance detection, not the batch
/// push-to-talk shape this app is built around), and cloud/local-network
/// options — none of those are "add a registry entry," each would be a
/// new Transcriber implementation and its own scoping pass. What's below
/// is everything both engines already support that a registry entry
/// alone can turn on.
enum ModelRegistry {
    static let shared: [TranscriptionModel] = [
        TranscriptionModel(
            id: "whisper-tiny.en",
            displayName: "Whisper Tiny (English)",
            engine: .whisperKit,
            whisperKitID: "openai_whisper-tiny.en",
            parakeetVersion: nil,
            sizeMB: 73,
            languages: ["en"],
            recommended: false,
            speed: 5,
            accuracy: 1
        ),
        TranscriptionModel(
            id: "whisper-base.en",
            displayName: "Whisper Base (English)",
            engine: .whisperKit,
            whisperKitID: "openai_whisper-base.en",
            parakeetVersion: nil,
            sizeMB: 145,
            languages: ["en"],
            recommended: false,
            speed: 4,
            accuracy: 2
        ),
        TranscriptionModel(
            id: "whisper-small.en",
            displayName: "Whisper Small (English)",
            engine: .whisperKit,
            whisperKitID: "openai_whisper-small.en",
            parakeetVersion: nil,
            sizeMB: 488,
            languages: ["en"],
            recommended: false,
            speed: 3,
            accuracy: 3
        ),
        TranscriptionModel(
            id: "whisper-medium.en",
            displayName: "Whisper Medium (English)",
            engine: .whisperKit,
            whisperKitID: "openai_whisper-medium.en",
            parakeetVersion: nil,
            sizeMB: 1459,
            languages: ["en"],
            recommended: false,
            speed: 2,
            accuracy: 4
        ),
        TranscriptionModel(
            id: "whisper-large-v3-turbo",
            displayName: "Whisper Large v3 Turbo",
            engine: .whisperKit,
            whisperKitID: "openai_whisper-large-v3-v20240930_turbo",
            parakeetVersion: nil,
            sizeMB: 1620,
            languages: ["multi"],
            recommended: false,
            speed: 3,
            accuracy: 5
        ),
        TranscriptionModel(
            id: "whisper-large-v3",
            displayName: "Whisper Large v3",
            engine: .whisperKit,
            whisperKitID: "openai_whisper-large-v3",
            parakeetVersion: nil,
            sizeMB: 2947,
            languages: ["multi"],
            recommended: false,
            speed: 1,
            accuracy: 5
        ),
        TranscriptionModel(
            id: "parakeet-tdt-0.6b-v2",
            displayName: "Parakeet TDT 0.6B v2 (English)",
            engine: .parakeet,
            whisperKitID: nil,
            parakeetVersion: "v2",
            sizeMB: 443,
            languages: ["en"],
            recommended: false,
            speed: 5,
            accuracy: 5
        ),
        TranscriptionModel(
            id: "parakeet-tdt-0.6b-v3",
            displayName: "Parakeet TDT 0.6B v3",
            engine: .parakeet,
            whisperKitID: nil,
            parakeetVersion: "v3",
            sizeMB: 480,
            languages: ["multi"],
            recommended: true,
            speed: 5,
            accuracy: 4
        ),
        // FluidAudio's `.tdtCtc110m` — a 110M-param hybrid TDT-CTC model
        // with a fused preprocessor+encoder, English-only. The closest
        // thing FluidAudio (the SDK this app's Parakeet engine actually
        // wraps) has to FluidVoice's "Parakeet Flash (Beta)" — much
        // smaller/faster than the 0.6B Parakeet checkpoints above, same
        // "smaller = faster, less accurate" tradeoff as the Whisper tiers.
        // Labeled by what it actually is rather than reused as
        // FluidVoice's own product name, since there's no way to confirm
        // from here that it's the identical underlying NeMo checkpoint.
        TranscriptionModel(
            id: "parakeet-tdt-ctc-110m",
            displayName: "Parakeet TDT-CTC 110M (Fast)",
            engine: .parakeet,
            whisperKitID: nil,
            parakeetVersion: "tdtCtc110m",
            sizeMB: 217,
            languages: ["en"],
            recommended: false,
            speed: 5,
            accuracy: 2
        ),
    ]

    static func find(_ id: String) -> TranscriptionModel? {
        shared.first { $0.id == id }
    }

    static func recommended() -> TranscriptionModel? {
        shared.first { $0.recommended } ?? shared.first
    }
}

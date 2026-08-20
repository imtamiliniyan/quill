import Foundation

enum Engine: String, Codable {
    case whisperKit
    case parakeet
}

struct TranscriptionModel: Codable {
    let id: String
    let displayName: String
    let engine: Engine
    /// Engine-specific identifier (e.g. "openai_whisper-base.en" for WhisperKit).
    let whisperKitID: String?
    /// Which FluidAudio Parakeet checkpoint this is ("v2" or "v3") — nil
    /// for WhisperKit models. Kept as a plain string, not FluidAudio's own
    /// `AsrModelVersion` enum, so this file (and every other place
    /// `TranscriptionModel` gets passed around) stays free of a FluidAudio
    /// import — the same reason `whisperKitID` is a bare string instead of
    /// a WhisperKit type. Resolved to the real enum only where FluidAudio
    /// is already a dependency — see `ParakeetModelVersion.swift`.
    let parakeetVersion: String?
    let sizeMB: Int
    let languages: [String]
    let recommended: Bool
    /// 1–5 relative ratings (Phase 5a), not measured percentages — there's
    /// no real benchmark suite behind these, just each architecture's
    /// well-documented general characteristics (smaller Whisper checkpoints
    /// trade accuracy for speed; Turbo keeps near-Large accuracy while
    /// being much faster than plain Large; Parakeet's streaming-oriented
    /// TDT architecture is built for very low latency). A dot rating reads
    /// as "roughly how it compares," not a precise claim — the honest
    /// version of what a fabricated "96% accuracy" caption would overstate.
    let speed: Int
    let accuracy: Int
}

struct ModelsManifest: Codable {
    let models: [TranscriptionModel]
}

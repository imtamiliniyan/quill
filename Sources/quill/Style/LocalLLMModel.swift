import Foundation

/// Describes one on-device model `LocalEnhancer` can load — the Local AI
/// equivalent of how ASR models are described for Voice Engine, kept as
/// its own small type rather than reusing that one since the two don't
/// share fields (no language/size-tier axis here, just id/name/size).
struct LocalLLMModel: Identifiable, Equatable {
    /// The Hugging Face repo id `ModelConfiguration`/`LLMModelFactory`
    /// resolve against — also this model's stable identity everywhere
    /// else (persisted settings, per-model download state).
    let id: String

    /// Human-friendly name shown in Enhancement Engine.
    let displayName: String

    /// Rounded download size, for the same "tell the user before they
    /// commit to a multi-GB fetch" reasoning the existing confirmation
    /// dialog already applies.
    let approxSizeGB: Double

    /// True for Superwhisper's S1-mini: a fixed-prompt speech-to-text
    /// normalizer, not a general instruction model, so `LocalEnhancer`
    /// drives it with its own system prompt and control line instead of
    /// `DictationCleanupPrompt`.
    var isS1Normalizer = false

    var sizeLabel: String { "~\(approxSizeGB.formatted(.number.precision(.fractionLength(1)))) GB" }
}

extension LocalLLMModel {
    /// mlx-community's 4-bit quantized Llama 3.2 3B Instruct: small enough
    /// for a background download on Apple Silicon, capable enough to
    /// follow a tone instruction reliably. Quill's original, still the
    /// default for anyone who's never touched this setting.
    static let llama32_3B = LocalLLMModel(
        id: "mlx-community/Llama-3.2-3B-Instruct-4bit",
        displayName: "Llama 3.2 3B Instruct (4-bit)",
        approxSizeGB: 1.8
    )

    /// mlx-community's 4-bit quantized Qwen2.5 3B Instruct — a second,
    /// similarly-sized option (verified real repo, verified real weight
    /// size via Hugging Face's own file listing) for a different model
    /// family's take on the same tone-rewrite task. Runs through the same
    /// `MLXLLM`/`LLMModelFactory` path as Llama; `mlx-swift-examples`
    /// already implements the Qwen2 architecture, so no new dependency.
    static let qwen25_3B = LocalLLMModel(
        id: "mlx-community/Qwen2.5-3B-Instruct-4bit",
        displayName: "Qwen2.5 3B Instruct (4-bit)",
        approxSizeGB: 1.75
    )

    /// Superwhisper's S1-mini (Qwen3-0.6B fine-tune, Apache 2.0 plus a
    /// naming clause: it must be shown as "S1-mini by Superwhisper"), 6-bit
    /// MLX conversion (`mlx_lm convert -q --q-bits 6`; 4-bit dropped punctuation). Needs fixed prompt
    /// wording and thinking off (see `LocalEnhancer.s1Messages`).
    static let s1Mini = LocalLLMModel(
        id: "iniyanai/s1-mini-6bit-mlx",
        displayName: "S1-mini by Superwhisper (6-bit)",
        approxSizeGB: 0.47,
        isS1Normalizer: true
    )

    /// Suggested in onboarding and badged in Enhancement Engine: purpose-
    /// built for dictation cleanup, a quarter of Llama's download, and
    /// about 0.2s per cleanup.
    static let recommended = s1Mini

    /// Every model Enhancement Engine's Local AI card can offer, in
    /// display order, recommended first.
    static let all: [LocalLLMModel] = [.s1Mini, .llama32_3B, .qwen25_3B]

    static func model(for id: String) -> LocalLLMModel {
        all.first { $0.id == id } ?? recommended
    }
}

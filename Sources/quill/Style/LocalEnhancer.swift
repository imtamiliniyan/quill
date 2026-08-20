import Foundation
import MLXLLM
import MLXLMCommon

/// A no-key, no-cloud tone/grammar rewrite path — the direct answer to what
/// FluidVoice calls "Fluid Intelligence": a small on-device language model
/// runs the exact same tone rewrite Medium/BYOK does, entirely on this Mac,
/// with zero network call and no API key required. Sits between Light
/// (rules-only `TranscriptSanitizer`, instant) and Medium (BYOK, highest
/// quality) as `AutoCleanupLevel.localAI`.
///
/// Backed by Apple's MLX (https://github.com/ml-explore/mlx-swift-examples) —
/// the same on-device inference approach Apple's own tooling uses, distinct
/// from FluidVoice's private "Fluid Intelligence" runtime. This is Quill's
/// own integration against a model Hugging Face already hosts publicly, not
/// borrowed code.
actor LocalEnhancer {
    static let shared = LocalEnhancer()

    /// mlx-community's 4-bit quantized Llama 3.2 3B Instruct: small enough
    /// for a background download (~1.8 GB) on Apple Silicon, capable enough
    /// to follow a tone instruction reliably. Swappable later without
    /// touching call sites if a smaller/better option turns up.
    static let modelID = "mlx-community/Llama-3.2-3B-Instruct-4bit"

    private var container: ModelContainer?
    private var loadTask: Task<ModelContainer, Error>?

    /// Rewrites `text` per `tone`, entirely on-device. First call for a
    /// fresh process pays the model-load cost (and, the very first time
    /// ever, the download); subsequent calls reuse the loaded container.
    func rewrite(_ text: String, tone: StyleTone) async throws -> String {
        let container = try await loadedContainer()

        let messages: [[String: String]] = [
            [
                "role": "system",
                "content": "You rewrite dictated text. \(tone.instruction) Reply with only the rewritten text, nothing else — no preamble, no quotes.",
            ],
            ["role": "user", "content": text],
        ]
        let input = UserInput(messages: messages)

        let result = try await container.perform { context in
            let lmInput = try await context.processor.prepare(input: input)
            return try generate(
                input: lmInput,
                parameters: GenerateParameters(temperature: 0.3),
                context: context
            ) { tokens in
                // A rewritten dictation is never anywhere near this long —
                // this is just a hard backstop against a runaway generation.
                tokens.count >= 512 ? .stop : .more
            }
        }
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True once the model files are on disk, without triggering a load —
    /// lets Settings/onboarding show download state without paying the
    /// (slow) model-load cost just to check.
    static func isDownloaded() -> Bool {
        let configuration = ModelConfiguration(id: modelID)
        let dir = configuration.modelDirectory()
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else {
            return false
        }
        // Hub downloads land as .safetensors + config/tokenizer json — a
        // non-empty directory is as good a signal as WhisperKit/Parakeet's
        // own "is this downloaded" checks elsewhere in the app.
        return !contents.isEmpty
    }

    static func deleteFiles() throws {
        let configuration = ModelConfiguration(id: modelID)
        let dir = configuration.modelDirectory()
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
    }

    /// Downloads (if needed) and loads the model, reporting progress via
    /// `onProgress` (0...1) — mirrors `ModelDownloadState`'s existing shape
    /// so the same download UI can drive this without a parallel design.
    func download(onProgress: @escaping @Sendable (Double) -> Void) async throws {
        _ = try await loadedContainer(onProgress: onProgress)
    }

    private func loadedContainer(
        onProgress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws -> ModelContainer {
        if let container { return container }
        if let loadTask {
            return try await loadTask.value
        }
        let task = Task<ModelContainer, Error> {
            let configuration = ModelConfiguration(id: Self.modelID)
            return try await LLMModelFactory.shared.loadContainer(configuration: configuration) { progress in
                onProgress(progress.fractionCompleted)
            }
        }
        loadTask = task
        do {
            let loaded = try await task.value
            container = loaded
            loadTask = nil
            return loaded
        } catch {
            loadTask = nil
            throw error
        }
    }
}

import Foundation
import MLXLLM
import MLXLMCommon

/// A no-key, no-cloud tone/grammar rewrite path — the direct answer to what
/// FluidVoice calls "Fluid Intelligence": a small on-device language model
/// runs the exact same tone rewrite Medium/BYOK does, entirely on this Mac,
/// with zero network call and no API key required. Sits next to Medium
/// (BYOK, highest quality) as `AutoCleanupLevel.localAI` — the offline
/// option for real tone/grammar rewrites, versus `AutoCleanupLevel.none`'s
/// verbatim typing on the other end.
///
/// Backed by Apple's MLX (https://github.com/ml-explore/mlx-swift-examples) —
/// the same on-device inference approach Apple's own tooling uses, distinct
/// from FluidVoice's private "Fluid Intelligence" runtime. This is Quill's
/// own integration against models Hugging Face already hosts publicly, not
/// borrowed code.
///
/// Supports more than one model (`LocalLLMModel.all`) rather than a single
/// hardcoded one — every entry point below takes a `modelID`, defaulting to
/// whichever one `QuillSettings.localAIModelID` currently selects, and each
/// model gets its own cached `ModelContainer` so switching between two
/// already-downloaded models doesn't discard either one's loaded state.
actor LocalEnhancer {
    static let shared = LocalEnhancer()

    private var containers: [String: ModelContainer] = [:]
    private var loadTasks: [String: Task<ModelContainer, Error>] = [:]

    /// Rewrites `text` per `tone`, entirely on-device, using `modelID`
    /// (default: the user's currently-selected model). First call for a
    /// fresh process/model pays the model-load cost (and, the very first
    /// time ever, the download); subsequent calls reuse the loaded
    /// container.
    func rewrite(
        _ text: String,
        tone: StyleTone,
        modelID: String = QuillSettings.localAIModelID
    ) async throws -> String {
        let container = try await loadedContainer(modelID: modelID)

        let messages: [[String: String]] = [
            [
                "role": "system",
                "content": DictationCleanupPrompt.full(tone: tone),
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

    /// True once `modelID`'s files are on disk, without triggering a load —
    /// lets Settings/onboarding show download state per model without
    /// paying the (slow) model-load cost just to check.
    static func isDownloaded(modelID: String = QuillSettings.localAIModelID) -> Bool {
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

    static func deleteFiles(modelID: String = QuillSettings.localAIModelID) throws {
        let configuration = ModelConfiguration(id: modelID)
        let dir = configuration.modelDirectory()
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
    }

    /// Downloads (if needed) and loads `modelID`, reporting progress via
    /// `onProgress` (0...1) — mirrors `ModelDownloadState`'s existing shape
    /// so the same download UI can drive this without a parallel design.
    func download(
        modelID: String = QuillSettings.localAIModelID,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws {
        _ = try await loadedContainer(modelID: modelID, onProgress: onProgress)
    }

    /// Drops `modelID`'s in-memory container (if any) — called after
    /// deleting its files so a stale loaded container can't keep serving
    /// rewrites against weights that no longer exist on disk.
    func unload(modelID: String) {
        containers[modelID] = nil
        loadTasks[modelID] = nil
    }

    private func loadedContainer(
        modelID: String,
        onProgress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws -> ModelContainer {
        if let container = containers[modelID] { return container }
        if let existingTask = loadTasks[modelID] {
            return try await existingTask.value
        }
        let task = Task<ModelContainer, Error> {
            let configuration = ModelConfiguration(id: modelID)
            return try await LLMModelFactory.shared.loadContainer(configuration: configuration) { progress in
                onProgress(progress.fractionCompleted)
            }
        }
        loadTasks[modelID] = task
        do {
            let loaded = try await task.value
            containers[modelID] = loaded
            loadTasks[modelID] = nil
            return loaded
        } catch {
            loadTasks[modelID] = nil
            throw error
        }
    }
}

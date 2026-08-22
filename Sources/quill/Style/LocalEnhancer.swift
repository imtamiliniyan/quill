import Foundation
import HuggingFace
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
// The `#huggingFaceTokenizerLoader()`/`#huggingFaceLoadModelContainer(...)`
// macros expand to code that references `Tokenizers.AutoTokenizer` by name —
// needs to be in scope at this call site even though nothing in this file
// spells `Tokenizers` directly.
import Tokenizers

/// A no-key, no-cloud tone/grammar rewrite path — the direct answer to what
/// FluidVoice calls "Fluid Intelligence": a small on-device language model
/// runs the exact same tone rewrite Medium/BYOK does, entirely on this Mac,
/// with zero network call and no API key required. Sits next to Medium
/// (BYOK, highest quality) as `AutoCleanupLevel.localAI` — the offline
/// option for real tone/grammar rewrites, versus `AutoCleanupLevel.none`'s
/// verbatim typing on the other end.
///
/// Backed by Apple's MLX (https://github.com/ml-explore/mlx-swift-lm) — the
/// same on-device inference approach Apple's own tooling uses, distinct
/// from FluidVoice's private "Fluid Intelligence" runtime. This is Quill's
/// own integration against models Hugging Face already hosts publicly, not
/// borrowed code.
///
/// On mlx-swift-lm, not the older mlx-swift-examples — switched after a
/// real crash report (SIGABRT inside MLX's own Metal scheduler init) traced
/// to mlx-swift-examples' pinned MLX version predating Apple's M5 GPU
/// entirely. mlx-swift-lm's `loadContainer` no longer bundles a default
/// downloader (that's how it dropped the swift-transformers dependency that
/// forced the old pin), so model loads go through `MLXHuggingFace`'s
/// `#huggingFaceLoadModelContainer` macro instead of
/// `LLMModelFactory.shared.loadContainer` directly, and on-disk presence
/// checks go through `HuggingFace.HubCache` instead of the old (now
/// package-private) `ModelConfiguration.modelDirectory`.
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
        if let lineBreak = DictationCleanupPrompt.standaloneLineBreak(text) { return lineBreak }

        let container = try await loadedContainer(modelID: modelID)

        let messages: [[String: String]] = [
            [
                "role": "system",
                "content": DictationCleanupPrompt.full(tone: tone),
            ],
            ["role": "user", "content": DictationCleanupPrompt.userMessage(for: text)],
        ]
        let input = UserInput(messages: messages)

        let result = try await container.perform { context in
            let lmInput = try await context.processor.prepare(input: input)
            if ProcessInfo.processInfo.environment["QUILL_DEBUG_PROMPT"] != nil {
                let decoded = context.tokenizer.decode(tokenIds: lmInput.text.tokens.asArray(Int.self), skipSpecialTokens: false)
                FileHandle.standardError.write(Data("=== RENDERED PROMPT ===\n\(decoded)\n=== END ===\n".utf8))
            }
            return try generate(
                input: lmInput,
                parameters: GenerateParameters(temperature: 0.2),
                context: context
            ) { tokens in
                // A rewritten dictation is never anywhere near this long —
                // this is just a hard backstop against a runaway generation.
                tokens.count >= 512 ? .stop : .more
            }
        }
        let cleaned = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if ProcessInfo.processInfo.environment["QUILL_DEBUG_RAW"] != nil {
            FileHandle.standardError.write(Data("=== RAW OUTPUT ===\n\(cleaned)\n=== END RAW ===\n".utf8))
        }
        return DictationCleanupPrompt.sanitizeOutput(cleaned, originalInput: text)
    }

    /// `HubCache`'s own repo-directory naming convention
    /// (`models--<namespace>--<name>`) for `modelID` — the top-level folder
    /// holding that repo's `blobs/`, `refs/`, and `snapshots/` (not the
    /// resolved snapshot itself, which needs an actual commit hash to find;
    /// existence/non-emptiness of the top-level folder is a sufficient
    /// "has this ever been downloaded" signal without needing one). `nil`
    /// only if `modelID` isn't in "namespace/name" form, which none of
    /// `LocalLLMModel.all`'s hardcoded ids ever are.
    private static func repoDirectory(modelID: String) -> URL? {
        guard let repo = Repo.ID(rawValue: modelID) else { return nil }
        return HubCache.default.repoDirectory(repo: repo, kind: .model)
    }

    /// True once `modelID`'s files are on disk, without triggering a load —
    /// lets Settings/onboarding show download state per model without
    /// paying the (slow) model-load cost just to check.
    static func isDownloaded(modelID: String = QuillSettings.localAIModelID) -> Bool {
        guard let dir = repoDirectory(modelID: modelID) else { return false }
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else {
            return false
        }
        // Non-empty means at least blobs/refs/snapshots exist under it — as
        // good a signal as WhisperKit/Parakeet's own "is this downloaded"
        // checks elsewhere in the app.
        return !contents.isEmpty
    }

    static func deleteFiles(modelID: String = QuillSettings.localAIModelID) throws {
        guard let dir = repoDirectory(modelID: modelID) else { return }
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
            // The macro-generated default hub client/tokenizer loader —
            // see this file's header doc for why loading goes through this
            // instead of `LLMModelFactory.shared.loadContainer` directly.
            return try await #huggingFaceLoadModelContainer(configuration: configuration) { progress in
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

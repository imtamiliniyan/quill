import Foundation

enum AutoCleanupLevel: String, CaseIterable, Identifiable {
    case none = "None"
    case localAI = "Local AI"
    case medium = "Medium"

    var id: String { rawValue }

    /// User-facing label — kept separate from `rawValue` on purpose.
    /// `rawValue` is what's persisted to `UserDefaults`
    /// (`QuillSettings.autoCleanupLevel`), so renaming it would silently
    /// reset anyone with this level already selected back to `.none` on
    /// their next launch (`AutoCleanupLevel(rawValue:)` failing to match
    /// falls back to `.none`). `displayName` can change freely; `rawValue`
    /// never should once shipped. "Medium" itself is a leftover from a
    /// retired Light/Medium/Full latency ladder (Light was cut, Full
    /// became "Local AI") and never got renamed alongside it — it doesn't
    /// tell anyone this tier is the cloud/BYOK one, which is the whole
    /// reason it has a delay and needs a key.
    var displayName: String {
        switch self {
        case .none, .localAI:
            return rawValue
        case .medium:
            return "Cloud Model"
        }
    }

    var summary: String {
        switch self {
        case .none:
            return "Types exactly what you said, including filler words."
        case .localAI:
            return "Full tone rewrite using a small on-device AI model: no key, no cloud, nothing leaves your Mac. First use downloads the model (~1.8 GB)."
        case .medium:
            return "Rewrites using your chosen tone and Style API key. Adds a short delay while it processes."
        }
    }
}

/// Applied automatically to every dictation, before it's typed — this is
/// the actual answer to "clean up my speech while I dictate," as opposed
/// to Style's manual paste-in box (still there separately, for rewriting
/// arbitrary text on demand rather than live dictation).
enum AutoCleanup {
    static func apply(_ text: String, level: AutoCleanupLevel) async -> String {
        switch level {
        case .none:
            return text

        case .localAI:
            guard LocalEnhancer.isDownloaded() else {
                // Not downloaded yet and this is the hot dictation path —
                // never block typing on a multi-GB fetch. Settings/onboarding
                // own prompting the user to download it ahead of time.
                return TranscriptSanitizer.cleanUpFillers(text)
            }
            do {
                return try await LocalEnhancer.shared.rewrite(
                    text,
                    tone: QuillSettings.autoCleanupTone,
                    modelID: QuillSettings.localAIModelID
                )
            } catch {
                FileHandle.standardError.write(Data(
                    "auto cleanup (local AI) failed, falling back to local cleanup: \(error)\n".utf8
                ))
                return TranscriptSanitizer.cleanUpFillers(text)
            }

        case .medium:
            let provider = QuillSettings.styleProvider
            guard APIKeyStore.hasKey(for: provider) else {
                // No key set — fall back to the local tier instead of
                // silently doing nothing or blocking the dictation.
                return TranscriptSanitizer.cleanUpFillers(text)
            }
            do {
                return try await StyleRewriter.rewrite(text, tone: QuillSettings.autoCleanupTone, provider: provider)
            } catch {
                FileHandle.standardError.write(Data(
                    "auto cleanup (medium) failed, falling back to local cleanup: \(error)\n".utf8
                ))
                return TranscriptSanitizer.cleanUpFillers(text)
            }
        }
    }

    /// The local-only pass: filler-word/punctuation cleanup, nothing more.
    /// No longer a selectable Auto Cleanup tier on its own (that was
    /// "Light" — retired: it never did real formatting like "five thirty
    /// pm" → "5:30 PM" or spoken listicles → a numbered list, which needs
    /// an actual model, so as a top-level choice it was a dead end next to
    /// None). Still very much alive as what Local AI/Medium silently fall
    /// back to when their backend isn't ready yet, and as Style's manual
    /// "Clean Up" tone — same function both places, so those two never
    /// drift into different behavior for what the UI presents as the same
    /// thing.
    ///
    /// Deliberately NOT running real grammar correction here. Tried
    /// NSSpellChecker's local grammar engine (the one behind Mail/Notes'
    /// inline corrections) — verified empirically it returns zero results
    /// even on clearly broken grammar ("he dont know what he doing"),
    /// with or without a running NSApplication context. Even if that had
    /// worked, this function sits directly in the dictation path with an
    /// explicit no-added-latency requirement, and an unverified local
    /// check isn't worth that risk. Real grammar correction stays a
    /// Medium/BYOK capability, where the latency is already an accepted,
    /// clearly-surfaced tradeoff — not snuck into the instant default.
    static func localCleanup(_ text: String) -> String {
        TranscriptSanitizer.cleanUpFillers(text)
    }
}

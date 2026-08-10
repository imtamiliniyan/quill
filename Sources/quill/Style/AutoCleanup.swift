import Foundation

enum AutoCleanupLevel: String, CaseIterable, Identifiable {
    case none = "None"
    case light = "Light"
    case medium = "Medium"

    var id: String { rawValue }

    var summary: String {
        switch self {
        case .none:
            return "Types exactly what you said, including filler words."
        case .light:
            return "Removes filler words and fixes basic punctuation — local, instant, no key needed."
        case .medium:
            return "Rewrites for clarity and conciseness using your Style API key — adds a short delay while it processes."
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

        case .light:
            return TranscriptSanitizer.cleanUpFillers(text)

        case .medium:
            let provider = QuillSettings.styleProvider
            guard APIKeyStore.hasKey(for: provider) else {
                // No key set — fall back to the local tier instead of
                // silently doing nothing or blocking the dictation.
                return TranscriptSanitizer.cleanUpFillers(text)
            }
            do {
                return try await StyleRewriter.rewrite(text, tone: .concise, provider: provider)
            } catch {
                FileHandle.standardError.write(Data(
                    "auto cleanup (medium) failed, falling back to local cleanup: \(error)\n".utf8
                ))
                return TranscriptSanitizer.cleanUpFillers(text)
            }
        }
    }
}

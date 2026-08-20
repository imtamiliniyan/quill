import Foundation

/// Shared post-processing for raw transcriber output, regardless of which
/// engine produced it.
enum TranscriptSanitizer {
    /// Strip non-speech bracket tokens ([BLANK_AUDIO], [MUSIC], (silence),
    /// <|nospeech|>, etc.) and collapse whitespace. When a model hears
    /// silence it can emit these literally; we don't want to paste them.
    static func sanitize(_ text: String) -> String {
        let patterns = [
            #"\[[^\]]*\]"#,        // [BLANK_AUDIO], [MUSIC], [Applause]
            #"\([^)]*\)"#,          // (silence), (music playing)
            #"<\|[^|]*\|>"#,        // <|nospeech|>, <|endoftext|>
            #"\*[^*]*\*"#,          // *background noise*
        ]
        var out = text
        for p in patterns {
            out = out.replacingOccurrences(of: p, with: " ", options: .regularExpression)
        }
        out = out.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Multi-word filler phrases — always covered when `removeFillerWords`
    /// is on, not exposed as editable chips in Voice Engine (FluidVoice's
    /// own reference list is single-word interjections only; these need
    /// actual phrase matching, not chip-editing, to stay correct).
    private static let phraseFillers = [
        #"\byou know\b"#, #"\blike,\s"#, #"\bi mean,?\s"#, #"\bsort of\b"#, #"\bkind of\b"#,
    ]

    /// Rule-based filler-word cleanup — no network, no model call, no API
    /// key required. This is Style's "Clean Up" tone; every other tone
    /// (Formal/Casual/Concise) goes through StyleRewriter's BYOK cloud
    /// path instead. Kept deliberately simple (a word list, not an NLP
    /// pass) so it's obviously safe to run on anything, always.
    ///
    /// The single-word half of the list is `QuillSettings.fillerWords`
    /// (Voice Engine, user-editable); the master `removeFillerWords`
    /// toggle gates the whole pass, phrases included.
    static func cleanUpFillers(_ text: String) -> String {
        guard QuillSettings.removeFillerWords else { return text }
        var out = text
        for word in QuillSettings.fillerWords {
            let escaped = NSRegularExpression.escapedPattern(for: word)
            out = out.replacingOccurrences(
                of: "\\b\(escaped)+\\b", with: "", options: [.regularExpression, .caseInsensitive]
            )
        }
        for pattern in phraseFillers {
            out = out.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }
        out = out.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        out = out.replacingOccurrences(of: #"\s+([,.!?])"#, with: "$1", options: .regularExpression)
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

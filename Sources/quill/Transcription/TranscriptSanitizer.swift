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

    /// Rule-based filler-word cleanup — no network, no model call, no API
    /// key required. This is Style's "Clean Up" tone; every other tone
    /// (Formal/Casual/Concise) goes through StyleRewriter's BYOK cloud
    /// path instead. Kept deliberately simple (a fixed word list, not an
    /// NLP pass) so it's obviously safe to run on anything, always.
    static func cleanUpFillers(_ text: String) -> String {
        let fillers = [
            #"\bum+\b"#, #"\buh+\b"#, #"\byou know\b"#,
            #"\blike,\s"#, #"\bi mean,?\s"#, #"\bsort of\b"#, #"\bkind of\b"#,
        ]
        var out = text
        for pattern in fillers {
            out = out.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }
        out = out.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        out = out.replacingOccurrences(of: #"\s+([,.!?])"#, with: "$1", options: .regularExpression)
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

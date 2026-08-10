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
}

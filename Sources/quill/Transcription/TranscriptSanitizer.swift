import Foundation

/// Shared post-processing for raw transcriber output, regardless of which
/// engine produced it.
enum TranscriptSanitizer {
    /// Strip non-speech bracket tokens ([BLANK_AUDIO], [MUSIC], (silence),
    /// <|nospeech|>, etc.) and collapse whitespace. When a model hears
    /// silence it can emit these literally; we don't want to paste them.
    /// Also applies the "literal" trigger-word commands (see
    /// `applyLiteralCommands`) — this runs before Auto Cleanup ever sees
    /// the text, so it's the same regardless of Auto Cleanup level
    /// (None, Light, Local AI, or Cloud Model).
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
        out = out.trimmingCharacters(in: .whitespacesAndNewlines)
        return applyLiteralCommands(out)
    }

    /// Line-break commands: consume one trailing space too, since a real
    /// break already separates what follows (unlike the punctuation
    /// commands below, which need normal English spacing preserved after
    /// them).
    private static let literalLineBreaks: [(pattern: String, replacement: String)] = [
        (#"new\s+line"#, "\n"),
        (#"next\s+line"#, "\n"),
        (#"new\s+paragraph"#, "\n\n"),
    ]

    /// Punctuation commands: deliberately do NOT consume a trailing
    /// space — "wait literal comma really" needs to read "wait, really",
    /// not "wait,really".
    private static let literalPunctuation: [(pattern: String, replacement: String)] = [
        (#"exclamation\s+(?:mark|point)"#, "!"),
        (#"question\s+mark"#, "?"),
        (#"period"#, "."),
        (#"comma"#, ","),
    ]

    /// Saying "literal <command>" forces that exact word/phrase into its
    /// punctuation/formatting result, deterministically — zero
    /// dependency on a model correctly inferring intent from context.
    /// The explicit, always-reliable alternative to Auto Cleanup's
    /// LLM-based tiers guessing at spoken commands, which degrades on
    /// longer/more complex dictation: confirmed directly, "new line"
    /// reliably becomes a real break in a short utterance but gets left
    /// as the literal words "new line" in a long, multi-sentence one.
    ///
    /// Scoped to the unambiguous 1:1 substitutions only (not "bold
    /// [text]"/"header [text]"/etc., which need a real clause boundary a
    /// regex can't safely determine on its own — those stay LLM-only).
    /// Strict `\bliteral\b` word-boundary match, not `literal\w*`, so
    /// this never fires on the ordinary word "literally" ("I literally
    /// can't believe it" passes through untouched). Requiring the
    /// trigger word at all means ordinary content that happens to
    /// contain these exact words ("add a new line to the config file")
    /// is never touched either — the whole point of an explicit trigger
    /// over a blind pattern match.
    static func applyLiteralCommands(_ text: String) -> String {
        var out = text
        for (pattern, replacement) in literalLineBreaks {
            let full = "\\s*\\bliteral\\s+(?:\(pattern))\\b[,.!?]*\\s?"
            out = out.replacingOccurrences(of: full, with: replacement, options: [.regularExpression, .caseInsensitive])
        }
        for (pattern, replacement) in literalPunctuation {
            let full = "\\s*\\bliteral\\s+(?:\(pattern))\\b[,.!?]*"
            out = out.replacingOccurrences(of: full, with: replacement, options: [.regularExpression, .caseInsensitive])
        }
        return out
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

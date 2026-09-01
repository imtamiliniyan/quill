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
        return applyVocabularyReplacements(applyLiteralCommands(out))
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
        // A removed phrase right before punctuation ("again. You know, let's"
        // → "again. , let's" → "again., let's") leaves two adjacent
        // punctuation marks behind — confirmed via real use, that artifact
        // was enough to make Local AI's small model truncate its
        // generation mid-sentence instead of cleaning past it. Collapsing
        // a run of punctuation down to the first mark is what a human
        // editor would do here anyway.
        out = out.replacingOccurrences(of: #"([,.!?])[,.!?]+"#, with: "$1", options: .regularExpression)
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Applies every saved "when Quill hears X, type Y instead" rule
    /// (Voice Engine's Custom Vocabulary editor) — explicit pairs, not a
    /// fuzzy guess, so there's no ambiguity risk against ordinary words.
    /// Runs on every dictation regardless of Auto Cleanup level, same as
    /// the bracket stripping above; empty list is a no-op. Neither ASR
    /// engine exposes real vocabulary boosting (Parakeet is a transducer
    /// model — that trick only works for prompt-conditioned ones like
    /// Whisper), so this corrects after the fact instead.
    static func applyVocabularyReplacements(_ text: String) -> String {
        let rules = QuillSettings.vocabularyReplacements
        guard !rules.isEmpty else { return text }
        var out = text
        for rule in rules {
            let replacement = rule.replacement.trimmingCharacters(in: .whitespaces)
            guard !replacement.isEmpty else { continue }
            for variant in rule.heard {
                let trimmed = variant.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                let escaped = NSRegularExpression.escapedPattern(for: trimmed)
                out = out.replacingOccurrences(
                    of: "\\b\(escaped)\\b", with: replacement,
                    options: [.regularExpression, .caseInsensitive]
                )
            }
        }
        return correctSimpleTypos(out, targets: rules.map { $0.replacement })
    }

    /// A second, much narrower pass on top of the explicit rules above —
    /// catches a plain single-letter typo drift against one of the
    /// user's own correct spellings ("Claud" → "Claude", a dropped
    /// trailing letter) without needing every such variant listed by
    /// hand. Deliberately not the wider fuzzy match an earlier version of
    /// this feature used: confirmed via real use, a bound loose enough to
    /// catch a genuine phonetic mishearing ("Claudia" is a real distance
    /// of 2 from "Claude") also risks mangling an unrelated real word or
    /// name. Edit distance 1, same first letter, is tight enough that a
    /// battery of ordinary English words tested against it produced zero
    /// false matches, so this stays purely a same-first-letter,
    /// one-edit-away check — nothing looser.
    private static func correctSimpleTypos(_ text: String, targets: [String]) -> String {
        let targets = Array(Set(targets.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }))
        guard !targets.isEmpty else { return text }

        let wordPattern = try! NSRegularExpression(pattern: #"[A-Za-z]+"#)
        let nsText = text as NSString
        var out = ""
        var lastEnd = 0
        for match in wordPattern.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
            let word = nsText.substring(with: match.range)
            out += nsText.substring(with: NSRange(location: lastEnd, length: match.range.location - lastEnd))
            out += closeTypoTarget(word, targets: targets) ?? word
            lastEnd = match.range.location + match.range.length
        }
        out += nsText.substring(from: lastEnd)
        return out
    }

    private static func closeTypoTarget(_ word: String, targets: [String]) -> String? {
        guard word.count >= 3 else { return nil }
        let wordLower = word.lowercased()
        var best: String?
        for target in targets {
            let targetLower = target.lowercased()
            guard wordLower != targetLower, wordLower.first == targetLower.first else { continue }
            guard levenshteinDistance(wordLower, targetLower) == 1 else { continue }
            guard best == nil else { return nil } // ambiguous between two targets — don't guess
            best = target
        }
        return best
    }

    /// Standard single-row DP Levenshtein distance — targets and
    /// individual words are both short, so this never needs to be fast,
    /// just correct.
    private static func levenshteinDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        var previous = Array(0...b.count)
        var current = Array(repeating: 0, count: b.count + 1)
        for i in 1...max(a.count, 1) where a.count > 0 {
            current[0] = i
            for j in 1...max(b.count, 1) where b.count > 0 {
                current[j] = a[i - 1] == b[j - 1]
                    ? previous[j - 1]
                    : 1 + min(previous[j - 1], previous[j], current[j - 1])
            }
            previous = current
        }
        return b.isEmpty ? a.count : previous[b.count]
    }
}

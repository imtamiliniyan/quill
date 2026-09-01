import Foundation

/// Wraps the bundled `harper-cli` binary (github.com/Automattic/harper) —
/// a fully offline, rule-based English grammar/spelling checker. The
/// opposite design from Local AI/Cloud Model: deterministic, zero
/// hallucination risk, no multi-GB model to download or keep resident in
/// RAM/GPU, ~55MB bundled binary instead. Explicit ask: kept as its own
/// separate Auto Cleanup level (`AutoCleanupLevel.harper`), never mixed
/// into the Local AI/Cloud Model pipeline, so it can't interfere with
/// either.
///
/// Scope, confirmed via real testing against the actual binary (not
/// assumed from docs): Harper fixes real grammar/spelling/capitalization
/// errors ("i" → "I", "has went" → "have gone", "stor" → "store"-ish
/// suggestions, subject-verb agreement) but does not do tone rewriting or
/// restructure a genuine run-on sentence from scratch — a linter, not a
/// generative rewriter. Complements Local AI/Cloud Model; for a lot of
/// dictation this may be enough on its own, since the ASR itself already
/// handles basic punctuation/capitalization (confirmed from this
/// session's own debug logs) — Harper's job is just catching what's
/// actually wrong in that output.
enum HarperGrammarChecker {
    struct HarperError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private static var binaryURL: URL? {
        Bundle.main.url(forResource: "harper-cli", withExtension: nil)
    }

    static var isAvailable: Bool { binaryURL != nil }

    /// Runs `harper-cli lint --format json` on `text` and applies every
    /// fix it suggests. Default overlap handling (no
    /// `--keep-overlapping-lints`) keeps at most one lint per span, which
    /// is what makes blind auto-apply safe here — nothing to reconcile
    /// between competing suggestions for the same text.
    static func check(_ text: String) throws -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return text }
        guard let binaryURL else {
            throw HarperError(message: "harper-cli not bundled with this build")
        }

        let process = Process()
        process.executableURL = binaryURL
        process.arguments = ["lint", "--format", "json", "--quiet"]

        let stdin = Pipe()
        let stdout = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = Pipe() // discard — informational notices only, confirmed via real run

        try process.run()
        stdin.fileHandleForWriting.write(Data(text.utf8))
        try stdin.fileHandleForWriting.close()

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        // Exit code 1 means "lints were found" here, not failure —
        // confirmed via real run: valid JSON is still on stdout either
        // way. Only a genuinely unparseable response is a real error.
        guard let reports = try? JSONDecoder().decode([FileReport].self, from: outputData) else {
            throw HarperError(message: "unexpected harper-cli output")
        }

        return applyFixes(to: text, lints: reports.first?.lints ?? [])
    }

    private struct FileReport: Decodable {
        let lints: [Lint]
    }

    private struct Lint: Decodable {
        let span: Span
        let suggestions: [String]
    }

    private struct Span: Decodable {
        let charStart: Int
        let charEnd: Int
        enum CodingKeys: String, CodingKey {
            case charStart = "char_start"
            case charEnd = "char_end"
        }
    }

    /// Harper's CLI serializes each suggestion as a human-readable label
    /// ("Replace with: "have"", "Remove error") rather than a structured
    /// replacement field — confirmed via real run against the actual
    /// binary, not assumed. `harper-cli` itself is documented as "a
    /// debugging tool", not a stable machine API, so this parses the one
    /// format actually observed rather than a guessed schema; a future
    /// Harper release changing this format degrades to "that lint gets
    /// skipped," not a crash (see the `guard` in `applyFixes`).
    private static func replacementText(for suggestion: String) -> String? {
        if suggestion == "Remove error" { return "" }
        guard suggestion.hasPrefix("Replace with: ") else { return nil }
        let quoted = suggestion.dropFirst("Replace with: ".count)
        let quoteChars: Set<Character> = ["\"", "\u{201C}", "\u{201D}"]
        guard let first = quoted.firstIndex(where: { quoteChars.contains($0) }) else { return nil }
        let afterFirst = quoted.index(after: first)
        guard let last = quoted[afterFirst...].lastIndex(where: { quoteChars.contains($0) }) else { return nil }
        return String(quoted[afterFirst..<last])
    }

    /// Applies each lint's first suggestion, back-to-front by span so an
    /// earlier edit never shifts a later span's character offsets out
    /// from under it.
    private static func applyFixes(to text: String, lints: [Lint]) -> String {
        var chars = Array(text)
        let sorted = lints.sorted { $0.span.charStart > $1.span.charStart }
        for lint in sorted {
            guard let first = lint.suggestions.first, let replacement = replacementText(for: first) else { continue }
            guard lint.span.charStart >= 0, lint.span.charEnd <= chars.count,
                  lint.span.charStart <= lint.span.charEnd else { continue }
            chars.replaceSubrange(lint.span.charStart..<lint.span.charEnd, with: Array(replacement))
        }
        return String(chars)
    }
}

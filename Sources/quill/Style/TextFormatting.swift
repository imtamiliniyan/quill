import Foundation

/// The three Text Formatting toggles (Phase 5g, FluidVoice-inspired) —
/// literal, user-controlled adjustments applied last, right before
/// injection, after Auto Cleanup has already done any tone/grammar
/// rewriting. Independent of Auto Cleanup's level, including `.none`: a
/// user who wants their filler words untouched can still want a leading
/// space between back-to-back dictations.
enum TextFormatting {
    static func apply(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        var result = text

        // Only pay for the Accessibility lookup if a toggle that actually
        // needs cursor context is on.
        let needsContext = QuillSettings.spaceBetweenDictations || QuillSettings.smartCapitalization
        let contextBefore = needsContext ? CursorContext.textBeforeCursor() : nil

        if QuillSettings.spaceBetweenDictations {
            result = addLeadingSpaceIfNeeded(result, contextBefore: contextBefore)
        }

        if QuillSettings.smartCapitalization {
            // Takes priority over the blanket "Lowercase First Letter"
            // toggle when both are on — it's the more specific rule and
            // uses actual context, where lowercase-first-letter doesn't.
            result = smartCapitalizeFirstLetter(result, contextBefore: contextBefore)
        } else if QuillSettings.lowercaseFirstLetter {
            result = lowercaseFirstLetter(result)
        }

        return result
    }

    /// Prepends a space when the cursor isn't already sitting after
    /// whitespace — the case that matters is two dictations landing
    /// back-to-back with no natural gap between them. Leaves text alone
    /// when context couldn't be read (`nil` means "unknown," not "start of
    /// line") — the alternative is a wrong guess that inserts a stray
    /// space silently.
    private static func addLeadingSpaceIfNeeded(_ text: String, contextBefore: String?) -> String {
        guard let contextBefore, let lastChar = contextBefore.last else { return text }
        return lastChar.isWhitespace || lastChar.isNewline ? text : " " + text
    }

    /// Force-lowercases the first letter, unconditionally — the blunt
    /// version of `smartCapitalizeFirstLetter` below, used when Smart
    /// Capitalization is off.
    private static func lowercaseFirstLetter(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.lowercased() + text.dropFirst()
    }

    /// Capitalizes the first letter only when the text before the cursor
    /// looks like the start of a new sentence (nothing there yet, or the
    /// nearest non-space character ends one: `.`/`!`/`?`); lowercases it
    /// otherwise, on the theory that mid-sentence dictation should read as
    /// a continuation, not a new sentence. Unreadable context defaults to
    /// capitalized, same as starting a fresh line.
    private static func smartCapitalizeFirstLetter(_ text: String, contextBefore: String?) -> String {
        guard let first = text.first else { return text }
        let shouldCapitalize: Bool
        if let lastNonSpace = contextBefore?.reversed().first(where: { !$0.isWhitespace }) {
            shouldCapitalize = ".!?".contains(lastNonSpace)
        } else {
            shouldCapitalize = true
        }
        let adjustedFirst = shouldCapitalize ? first.uppercased() : first.lowercased()
        return adjustedFirst + text.dropFirst()
    }
}

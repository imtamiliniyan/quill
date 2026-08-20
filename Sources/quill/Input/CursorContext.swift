import ApplicationServices
import Foundation

/// Best-effort read of the text immediately before the cursor in whatever
/// app is currently focused, via the Accessibility API — the same
/// permission `HotkeyMonitor` already requires, so nothing new to grant.
///
/// Only used by `TextFormatting`'s "Space Between Dictations" and "Smart
/// Capitalization" toggles, both of which need to know what's already
/// there before deciding what to inject. Not every app exposes a
/// standards-compliant `AXValue`/`AXSelectedTextRange` (several
/// Electron/Chromium editors don't), so every step here fails to `nil`
/// rather than guessing — callers must treat `nil` as "unknown," not
/// "empty," and fall back to their default behavior.
enum CursorContext {
    static func textBeforeCursor(maxLength: Int = 40) -> String? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef
        ) == .success, let focusedRef else { return nil }
        // Safe by construction: kAXFocusedUIElementAttribute always yields
        // an AXUIElement on success — this is the standard system-wide
        // focus lookup, not user-controlled data.
        let element = focusedRef as! AXUIElement

        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element, kAXValueAttribute as CFString, &valueRef
        ) == .success, let fullText = valueRef as? String else { return nil }

        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element, kAXSelectedTextRangeAttribute as CFString, &rangeRef
        ) == .success, let rangeRef else { return nil }

        var cfRange = CFRange()
        guard AXValueGetValue(rangeRef as! AXValue, .cfRange, &cfRange) else { return nil }

        let nsText = fullText as NSString
        let cursor = min(max(cfRange.location, 0), nsText.length)
        let start = max(0, cursor - maxLength)
        guard start <= cursor else { return nil }
        return nsText.substring(with: NSRange(location: start, length: cursor - start))
    }
}

import AppKit
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

    /// Best-effort on-screen rect to anchor `DiffReviewOverlay` near,
    /// tied to wherever the user is actually dictating rather than a
    /// fixed screen position — a URL bar at the top of the screen should
    /// get the popup near the top, a Slack message box at the bottom
    /// should get it near the bottom, whatever app it is.
    ///
    /// Tries the precise caret/selection bounds first (right at the
    /// cursor, inside the text), then falls back to the whole focused
    /// element's own frame — the *entire text box*, not the exact cursor
    /// position within it. That second tier matters: `kAXBoundsForRange`
    /// is a fairly advanced API plenty of controls skip (confirmed via
    /// real use — Chrome's own address bar doesn't support it), but
    /// `kAXPosition`/`kAXSize` on the focused element itself is baseline
    /// accessibility nearly everything reports, screen readers need it to
    /// find the control at all. `nil` only when neither is available or
    /// plausible — callers must still fall back to a fixed position then,
    /// never treat `nil` as an error.
    static func dictationAnchorRect() -> CGRect? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef
        ) == .success, let focusedRef else { return nil }
        let element = focusedRef as! AXUIElement

        return caretBounds(element) ?? elementFrame(element)
    }

    /// Tier 1: the precise caret/selection rect within the text.
    private static func caretBounds(_ element: AXUIElement) -> CGRect? {
        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element, kAXSelectedTextRangeAttribute as CFString, &rangeRef
        ) == .success, let rangeRef else { return nil }

        var boundsRef: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element, kAXBoundsForRangeParameterizedAttribute as CFString, rangeRef, &boundsRef
        ) == .success, let boundsRef else { return nil }

        var rect = CGRect.zero
        guard AXValueGetValue(boundsRef as! AXValue, .cgRect, &rect) else { return nil }

        // A real caret/selection line is roughly font-sized, not a few
        // thousand points tall and not negative — reject anything outside
        // a generous plausible range rather than trusting any "success".
        // This is the failure mode that actually bit this the first
        // time: a bad-but-not-literally-invalid reading placed the popup
        // off-screen instead of falling back.
        return validated(rect, maxHeight: 300)
    }

    /// Tier 2: the whole focused control's own frame — less precise
    /// about exactly where the cursor sits inside it, but tied to the
    /// right text box, which is the actual requirement.
    private static func elementFrame(_ element: AXUIElement) -> CGRect? {
        var positionRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element, kAXPositionAttribute as CFString, &positionRef
        ) == .success, let positionRef else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(positionRef as! AXValue, .cgPoint, &point) else { return nil }

        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element, kAXSizeAttribute as CFString, &sizeRef
        ) == .success, let sizeRef else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) else { return nil }

        // A whole control can legitimately be much bigger than a caret
        // line (a Slack message box, a big textarea) — just guard against
        // the same "reports success with garbage" failure mode.
        return validated(CGRect(origin: point, size: size), maxHeight: 2000)
    }

    /// Shared flip (Quartz top-left origin → AppKit bottom-left) +
    /// plausibility check for both tiers above.
    private static func validated(_ rect: CGRect, maxHeight: CGFloat) -> CGRect? {
        guard rect.origin.x.isFinite, rect.origin.y.isFinite,
              rect.width.isFinite, rect.height.isFinite,
              rect.height > 2, rect.height < maxHeight,
              rect.width >= 0, rect.width < 6000
        else { return nil }

        // AX bounds come back in top-left-origin (Quartz) screen
        // coordinates; AppKit's NSScreen/NSPanel space is bottom-left
        // origin. Flipping against the primary screen's height is the
        // standard conversion — correct for the primary display and any
        // screen arranged purely left/right of it. ponytail: a display
        // arranged above/below (not beside) the primary one can throw
        // this off — acceptable given the on-screen check below and the
        // fixed-position fallback both still catch the result being
        // garbage.
        guard let primaryHeight = NSScreen.screens.first?.frame.height else { return nil }
        let flipped = CGRect(
            x: rect.origin.x, y: primaryHeight - rect.origin.y - rect.height,
            width: rect.width, height: rect.height
        )

        let onAnyScreen = NSScreen.screens.contains {
            $0.frame.insetBy(dx: -50, dy: -50).contains(CGPoint(x: flipped.midX, y: flipped.midY))
        }
        guard onAnyScreen else { return nil }

        return flipped
    }
}

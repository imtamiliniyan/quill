import AppKit
import SwiftUI

/// Grammarly-style "here's what changed" popup — shown after every
/// dictation Auto Cleanup runs on (any level but `.none`) and before it's
/// typed, so the user can see the raw-vs-cleaned diff and either Accept
/// it or type exactly what they said instead — whether or not Auto
/// Cleanup actually changed anything, an explicit "always confirm" ask.
/// Gated by `QuillSettings.reviewBeforeTyping` (see `Quill.swift`'s
/// `finishRecording`).
///
/// Unlike `RecordingOverlay` (a click-through HUD), this panel needs real
/// keyboard/mouse input — Accept, "Type as dictated", and Escape all have
/// to reach it — so it can't be `ignoresMouseEvents`, and needs
/// `canBecomeKey` (see `KeyCapturePanel` below) to receive Escape at all.
@MainActor
final class DiffReviewOverlay {
    /// One dictation's still-undecided popup — `ops` to show, and the
    /// `review()` call that's suspended waiting for this one's outcome.
    private struct Pending {
        let ops: [DiffOp]
        let continuation: CheckedContinuation<Bool, Never>
    }

    /// FIFO — dictating again while a popup is still up used to silently
    /// auto-accept and kill that popup the moment the new one finished
    /// processing (confirmed via real use: rapid back-to-back dictations
    /// made popups vanish before they could ever be read, looking like
    /// "it only works once or twice"). Queueing instead means every
    /// dictation gets its own popup, shown one after another if you're
    /// dictating faster than you can review them — none get skipped.
    ///
    /// No auto-accept timeout — explicit ask: a popup waits for a real
    /// Accept/"Type as dictated"/Escape indefinitely, never types
    /// anything on its own. A dictation just queues up behind however
    /// many popups are still waiting for you.
    private var queue: [Pending] = []
    private var panel: NSPanel?

    /// Shows the diff between `raw` and `cleaned` once its turn in the
    /// queue comes up, then suspends until Accept, reject, or Escape
    /// resolves it. Returns `true` to type `cleaned`, `false` to type
    /// `raw` instead.
    func review(raw: String, cleaned: String) async -> Bool {
        let ops = TextDiff.diff(before: raw, after: cleaned)
        return await withCheckedContinuation { continuation in
            queue.append(Pending(ops: ops, continuation: continuation))
            presentNextIfIdle()
        }
    }

    private func presentNextIfIdle() {
        guard panel == nil, let next = queue.first else { return }

        let panel = makePanel(ops: next.ops)
        self.panel = panel
        position(panel)
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    /// Resolves whichever popup is currently on screen (the front of the
    /// queue) and immediately presents the next one, if any.
    private func resolveFront(accept: Bool) {
        guard !queue.isEmpty else { return }
        panel?.orderOut(nil)
        panel = nil
        let current = queue.removeFirst()
        current.continuation.resume(returning: accept)
        presentNextIfIdle()
    }

    /// Fixed, not measured from content — the diff area scrolls internally
    /// (see `DiffReviewView`) instead of the panel growing with it. A
    /// dynamically-measured `NSHostingView.fittingSize` read immediately
    /// after assigning `contentView` is a real, confirmed source of
    /// flakiness: for longer diffs it doesn't always reflect a completed
    /// SwiftUI layout pass yet, which is exactly why the popup used to
    /// sometimes render too small to see. A constant size sidesteps that
    /// whole class of bug.
    private static let panelSize = NSSize(width: 440, height: 280)

    private func makePanel(ops: [DiffOp]) -> NSPanel {
        let panel = KeyCapturePanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.onEscape = { [weak self] in self?.resolveFront(accept: false) }
        panel.onReturn = { [weak self] in self?.resolveFront(accept: true) }

        let view = DiffReviewView(
            ops: ops,
            onAccept: { [weak self] in self?.resolveFront(accept: true) },
            onReject: { [weak self] in self?.resolveFront(accept: false) }
        )
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: Self.panelSize)
        panel.contentView = host
        return panel
    }

    /// Anchors just below wherever the user is actually dictating —
    /// the precise caret when the focused app exposes one, the whole
    /// text box's own frame otherwise (see
    /// `CursorContext.dictationAnchorRect`'s doc comment: a URL bar or
    /// other control that skips the precise-caret API still reports its
    /// own position/size, which keeps the popup tied to the right part
    /// of the screen instead of a fixed spot unrelated to where you're
    /// typing). Only actually falls back to fixed bottom-center when
    /// neither is available or plausible, so a bad reading is never an
    /// invisible popup.
    private func position(_ panel: NSPanel) {
        guard
            let caret = CursorContext.dictationAnchorRect(),
            let screen = NSScreen.screens.first(where: { $0.frame.contains(CGPoint(x: caret.midX, y: caret.midY)) })
        else {
            positionAtBottomCenter(panel)
            return
        }

        let visible = screen.visibleFrame
        var origin = NSPoint(x: caret.minX, y: caret.minY - panel.frame.height - 10)

        // Clamp fully into the visible frame on BOTH axes. The earlier
        // version only handled X fully and Y's lower edge (flipping above
        // the caret line instead of going negative) — never clamped Y's
        // upper edge, so a plausible-looking but still-off reading could
        // push the popup above the screen with nothing catching it.
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - panel.frame.width - 8)
        if origin.y < visible.minY + 8 {
            origin.y = caret.maxY + 10
        }
        origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - panel.frame.height - 8)

        panel.setFrameOrigin(origin)
    }

    private func positionAtBottomCenter(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let frame = panel.frame
        let visible = screen.visibleFrame
        let x = visible.midX - frame.width / 2
        let y = visible.minY + 90
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

/// A plain borderless `.nonactivatingPanel` never receives `keyDown` —
/// `canBecomeKey` is what lets Escape actually reach it, without stealing
/// "active app" status from whatever app the user was dictating into
/// (confirmed: this is the standard HUD-panel pattern, not a workaround).
private final class KeyCapturePanel: NSPanel {
    var onEscape: (() -> Void)?
    var onReturn: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: onEscape?()
        case 36, 76: onReturn?() // Return, numpad Enter
        default: super.keyDown(with: event)
        }
    }
}

private struct DiffReviewView: View {
    let ops: [DiffOp]
    let onAccept: () -> Void
    let onReject: () -> Void

    /// Shown unconditionally now (not just when something changed) —
    /// explicit ask: confirm every dictation, not just the ones Auto
    /// Cleanup actually touched. An all-`.equal` diff means nothing to
    /// highlight, so the header says so instead of claiming a rewrite
    /// that didn't happen.
    private var hasChanges: Bool {
        ops.contains { if case .equal = $0 { return false } else { return true } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: hasChanges ? "sparkles" : "checkmark.circle")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.accent)
                Text(hasChanges ? "Auto Cleanup rewrote this" : "No changes, looks good")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(Theme.accent)
                Spacer()
                Text("Enter to accept · Esc for as-dictated")
                    .font(.system(size: 9.5))
                    .foregroundColor(.white.opacity(0.35))
            }

            // Scrolls internally (built into `DiffTextView` itself, an
            // NSScrollView) rather than growing the panel — keeps the
            // popup a constant, predictable size regardless of dictation
            // length (see `DiffReviewOverlay.panelSize`'s doc comment).
            DiffTextView(ops: ops)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 8) {
                Button("Accept", action: onAccept)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .controlSize(.small)
                Button("Type as dictated", action: onReject)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Spacer()
            }
        }
        .padding(16)
        .frame(width: 440, height: 280, alignment: .leading)
        .background(Color(red: 22/255, green: 22/255, blue: 22/255))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

}

/// Renders the diff as one flowing, wrapping block of rich text — kept
/// text plain, changed/inserted text with an inline highlight
/// *background*, removed text gray and struck through, same run
/// grouping Grammarly's own popup uses (the reference screenshot) rather
/// than discrete per-word chips with gaps between them.
///
/// Bridges to `NSTextView` instead of SwiftUI's `Text(AttributedString)`
/// for one specific, confirmed reason: SwiftUI's `Text` renders
/// `AttributedString`'s `.foregroundColor` and `.strikethroughStyle`
/// attributes fine, but silently drops `.backgroundColor` — there's no
/// supported way to get a per-run highlight background out of it.
/// Deletions showed correctly (gray + struck through) while insertions
/// rendered as plain text with no visible highlight at all, which is
/// exactly the bug this fixes. `NSAttributedString`/`NSTextView` supports
/// background color per run natively (it's a first-class attribute
/// there, wraps correctly across lines same as any rich text editor),
/// so this is the actual fix, not a workaround.
private struct DiffTextView: NSViewRepresentable {
    let ops: [DiffOp]

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 2)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        textView.textStorage?.setAttributedString(Self.attributedDiff(ops))
    }

    private static func attributedDiff(_ ops: [DiffOp]) -> NSAttributedString {
        enum Kind: Equatable { case equal, insert, delete }
        func kind(_ op: DiffOp) -> Kind {
            switch op {
            case .equal: return .equal
            case .insert: return .insert
            case .delete: return .delete
            }
        }
        func word(_ op: DiffOp) -> String {
            switch op {
            case .equal(let w), .insert(let w), .delete(let w): return w
            }
        }

        // Consecutive same-kind ops joined into one run first so a
        // highlight/strikethrough spans cleanly across a multi-word edit
        // instead of restarting (with a visible seam) at every word.
        var runs: [(kind: Kind, text: String)] = []
        for op in ops {
            let k = kind(op)
            if let last = runs.last, last.kind == k {
                runs[runs.count - 1].text += " " + word(op)
            } else {
                runs.append((k, word(op)))
            }
        }

        let font = NSFont.systemFont(ofSize: 12.5)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 5

        let result = NSMutableAttributedString()
        for (index, run) in runs.enumerated() {
            var attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .paragraphStyle: paragraphStyle,
            ]
            switch run.kind {
            case .equal:
                attributes[.foregroundColor] = NSColor.white.withAlphaComponent(0.88)
            case .insert:
                attributes[.foregroundColor] = NSColor.white
                attributes[.backgroundColor] = NSColor(Theme.accent).withAlphaComponent(0.4)
            case .delete:
                attributes[.foregroundColor] = NSColor.white.withAlphaComponent(0.35)
                attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                attributes[.strikethroughColor] = NSColor.white.withAlphaComponent(0.35)
            }
            result.append(NSAttributedString(string: run.text, attributes: attributes))
            if index < runs.count - 1 {
                result.append(NSAttributedString(string: " ", attributes: [.font: font]))
            }
        }
        return result
    }
}

import AppKit
import SwiftUI

/// Shared colors across every Quill window — onboarding, model download
/// progress, and the main app window. Keeps the look consistent without
/// every view redeclaring its own palette.
///
/// Every color below is appearance-aware via `dynamic(dark:light:)`:
/// light mode mirrors the landing page's warm palette
/// (landing/styles-v2.css), dark mode keeps Quill's original look.
/// Nothing outside this file needs to know which mode is active —
/// `Theme.textPrimary` etc. just resolves to the right color per-draw,
/// following System Settings > Appearance (or the manual override in
/// Settings > System, see QuillSettings.darkModeEnabled).
enum Theme {
    // Same hue as the landing page's --quill-accent (#B5D1FF) in dark
    // mode, kept as the deliberate continuity thread — but that light
    // pastel blue has poor contrast used as text/highlight on a *light*
    // background (light-on-light), confirmed by the actual light-mode
    // screenshots once this shipped. Light mode uses a darker, more
    // saturated shade of the same hue instead, for legibility.
    static let accent = dynamic(
        dark: NSColor(red: 181 / 255, green: 209 / 255, blue: 255 / 255, alpha: 1),
        light: NSColor(red: 38 / 255, green: 113 / 255, blue: 217 / 255, alpha: 1) // #2671D9
    )

    static let background = dynamic(
        dark: NSColor(red: 0.075, green: 0.078, blue: 0.086, alpha: 1),
        light: NSColor(red: 1.0, green: 0.965, blue: 0.949, alpha: 1) // #FFF6F2 — flat blend of the landing gradient's two stops
    )

    // Text tiers — appearance-aware, four buckets instead of the dozen
    // near-duplicate one-off opacity values previously scattered across
    // views (0.4 vs 0.45 vs 0.5 doing the same job in different files).
    static let textPrimary = dynamic(dark: .white, light: NSColor(red: 0.102, green: 0.102, blue: 0.102, alpha: 1))
    static let textSecondary = dynamic(dark: NSColor.white.withAlphaComponent(0.6), light: NSColor(red: 0.102, green: 0.102, blue: 0.102, alpha: 0.6))
    static let textTertiary = dynamic(dark: NSColor.white.withAlphaComponent(0.42), light: NSColor(red: 0.102, green: 0.102, blue: 0.102, alpha: 0.4))

    // Faint fills/dividers/strokes — not text. Two tiers: a base level for
    // resting-state card backgrounds (~0.02–0.05), and a stronger one for
    // hover/selected highlights (~0.06–0.08) that needs to visibly read as
    // "more" than the base level it's usually paired with in a ternary.
    static let textQuaternary = dynamic(dark: NSColor.white.withAlphaComponent(0.05), light: NSColor.black.withAlphaComponent(0.05))
    static let fillHover = dynamic(dark: NSColor.white.withAlphaComponent(0.08), light: NSColor.black.withAlphaComponent(0.08))

    // Card treatment shared by every stat/list card (Dictation, Insights,
    // stats sidebar) — one radius/fill/border so cards read as one system
    // instead of each view inventing its own.
    static let cardRadius: CGFloat = 12
    static let cardFill = dynamic(dark: NSColor.white.withAlphaComponent(0.035), light: NSColor.black.withAlphaComponent(0.035))
    static let cardStroke = dynamic(dark: NSColor.white.withAlphaComponent(0.06), light: NSColor.black.withAlphaComponent(0.06))
    static let pagePadding: CGFloat = 24

    /// Resolves to `dark` or `light` per the current effective NSAppearance
    /// at draw time — the standard AppKit dynamic-color pattern, bridged
    /// into SwiftUI. Every `Theme.*` token built on this needs zero
    /// `@Environment(\.colorScheme)` plumbing in the views that use it.
    private static func dynamic(dark: NSColor, light: NSColor) -> Color {
        Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }
}

extension View {
    /// Consistent card chrome: subtle fill + hairline border + shared
    /// corner radius, instead of every card view redeclaring its own.
    func quillCard() -> some View {
        self
            .background(Theme.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .strokeBorder(Theme.cardStroke, lineWidth: 1)
            )
    }
}

import SwiftUI

/// Shared colors across every Quill window — onboarding, model download
/// progress, and (Phase 2) the main app window. Keeps the look consistent
/// without every view redeclaring its own palette.
enum Theme {
    static let accent = Color(red: 181 / 255, green: 209 / 255, blue: 255 / 255)
    static let background = Color(red: 0.075, green: 0.078, blue: 0.086)

    // Card treatment shared by every stat/list card (Dictation, Insights,
    // stats sidebar) — one radius/fill/border so cards read as one system
    // instead of each view inventing its own.
    static let cardRadius: CGFloat = 12
    static let cardFill = Color.white.opacity(0.035)
    static let cardStroke = Color.white.opacity(0.06)
    static let pagePadding: CGFloat = 24
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

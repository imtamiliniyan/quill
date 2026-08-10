import SwiftUI

/// Shared colors across every Quill window — onboarding, model download
/// progress, and (Phase 2) the main app window. Keeps the look consistent
/// without every view redeclaring its own palette.
enum Theme {
    static let accent = Color(red: 181 / 255, green: 209 / 255, blue: 255 / 255)
    static let background = Color(red: 0.075, green: 0.078, blue: 0.086)
}

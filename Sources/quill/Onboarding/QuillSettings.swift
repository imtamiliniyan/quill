import AppKit
import Foundation

/// Persisted app settings.
///
/// Only ever read/written by the onboarding path (Quill.app / a bare
/// `quill` with no flags) — the CLI/LaunchAgent path (`--model` +
/// `--skip-doctor`) never touches this, so cross-context consistency
/// isn't a concern here.
///
/// Deliberately plain `.standard`, not a named suite: passing the app's
/// *own* bundle identifier as `UserDefaults(suiteName:)` is explicitly
/// rejected by Foundation at runtime ("does not make sense and will not
/// work" — confirmed via a real launch, not just docs) since that's
/// already what `.standard` resolves to for a bundled app.
enum QuillSettings {
    private static let defaults = UserDefaults.standard

    private enum Key {
        static let selectedModelID = "selectedModelID"
        static let onboardingCompleted = "onboardingCompleted"
        static let styleProvider = "styleProvider"
        static let autoCleanupLevel = "autoCleanupLevel"
        static let autoCleanupTone = "autoCleanupTone"
        static let darkModeEnabled = "darkModeEnabled"
    }

    static var selectedModelID: String? {
        get { defaults.string(forKey: Key.selectedModelID) }
        set { defaults.set(newValue, forKey: Key.selectedModelID) }
    }

    static var onboardingCompleted: Bool {
        get { defaults.bool(forKey: Key.onboardingCompleted) }
        set { defaults.set(newValue, forKey: Key.onboardingCompleted) }
    }

    /// Which provider Style targets — not sensitive (just a picker
    /// choice), unlike the actual API key which lives in APIKeyStore
    /// (Keychain), never here.
    static var styleProvider: StyleProvider {
        get { StyleProvider(rawValue: defaults.string(forKey: Key.styleProvider) ?? "") ?? .openAI }
        set { defaults.set(newValue.rawValue, forKey: Key.styleProvider) }
    }

    /// Off (.none) by default — same "opt in, not silently on" posture as
    /// everything else in Quill. Once set, though, it applies to every
    /// dictation automatically with no further interaction, which is the
    /// whole point: a one-time setting, not a per-dictation decision.
    static var autoCleanupLevel: AutoCleanupLevel {
        get { AutoCleanupLevel(rawValue: defaults.string(forKey: Key.autoCleanupLevel) ?? "") ?? .none }
        set { defaults.set(newValue.rawValue, forKey: Key.autoCleanupLevel) }
    }

    /// Which tone Medium rewrites into, chosen once here rather than
    /// per-dictation — set it and forget it, same posture as
    /// `autoCleanupLevel` itself. Auto Cleanup only ever offers
    /// Formal/Casual/Very Casual (Clean Up and Concise are Rewrite-on-
    /// demand-only); anything else stored — including a stale `.concise`
    /// from before this option set changed — falls back to `.casual`.
    static var autoCleanupTone: StyleTone {
        get {
            let allowed: [StyleTone] = [.formal, .casual, .veryCasual]
            let stored = StyleTone(rawValue: defaults.string(forKey: Key.autoCleanupTone) ?? "")
            guard let stored, allowed.contains(stored) else { return .casual }
            return stored
        }
        set { defaults.set(newValue.rawValue, forKey: Key.autoCleanupTone) }
    }

    /// Manual override, not "follow system": Theme.swift's dynamic colors
    /// resolve off `NSApp.appearance` (not the raw system setting), and
    /// setting that explicitly is exactly how a manual light/dark toggle
    /// is meant to work in AppKit — it takes effect immediately on every
    /// open window, no restart needed. Defaults to false (light) since
    /// light is the primary palette now, matching the landing page.
    static var darkModeEnabled: Bool {
        get { defaults.bool(forKey: Key.darkModeEnabled) }
        set {
            defaults.set(newValue, forKey: Key.darkModeEnabled)
            applyAppearance()
        }
    }

    /// Pushes `darkModeEnabled` onto NSApp — call once at each app-launch
    /// entry point (before any window is shown) and again whenever the
    /// Settings toggle changes it.
    static func applyAppearance() {
        NSApp.appearance = NSAppearance(named: darkModeEnabled ? .darkAqua : .aqua)
    }
}

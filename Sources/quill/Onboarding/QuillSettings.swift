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
    }

    static var selectedModelID: String? {
        get { defaults.string(forKey: Key.selectedModelID) }
        set { defaults.set(newValue, forKey: Key.selectedModelID) }
    }

    static var onboardingCompleted: Bool {
        get { defaults.bool(forKey: Key.onboardingCompleted) }
        set { defaults.set(newValue, forKey: Key.onboardingCompleted) }
    }
}

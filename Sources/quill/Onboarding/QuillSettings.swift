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
        static let assumedTypingWPM = "assumedTypingWPM"
        static let activationMode = "activationMode"
        static let lowercaseFirstLetter = "lowercaseFirstLetter"
        static let spaceBetweenDictations = "spaceBetweenDictations"
        static let smartCapitalization = "smartCapitalization"
        static let removeFillerWords = "removeFillerWords"
        static let fillerWords = "fillerWords"
        static let openRouterModel = "openRouterModel"
        static let localAIModelID = "localAIModelID"
        static let debugLoggingEnabled = "debugLoggingEnabled"
    }

    /// The single-word interjections `TranscriptSanitizer.cleanUpFillers`
    /// strips by default — the common list of English filler sounds, not
    /// specific to any one app (any dictation tool's default list looks
    /// close to this). User-editable in Voice Engine; this is only the
    /// starting point `fillerWords` falls back to before it's ever been
    /// customized or after a Reset to Default.
    static let defaultFillerWords = [
        "um", "uh", "er", "ah", "eh", "umm", "uhh", "err",
        "ahh", "ehh", "hmm", "hm", "mm", "mmm", "erm", "urm", "ugh",
    ]

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

    /// Which on-device model `LocalEnhancer` loads for Local AI — defaults
    /// to `LocalLLMModel.llama32_3B` (Quill's original, still the only
    /// model anyone had before this setting existed), so adding a second
    /// choice here changes nothing for a user who's never opened
    /// Enhancement Engine's Local AI card.
    static var localAIModelID: String {
        get { defaults.string(forKey: Key.localAIModelID) ?? LocalLLMModel.llama32_3B.id }
        set { defaults.set(newValue, forKey: Key.localAIModelID) }
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

    /// Assumed typing speed for Insights' "Time Saved" stat — editable so
    /// the number reflects the user's own typing, not a guess. Defaults
    /// to 40 (same default FluidVoice uses), shown next to the number
    /// itself in Insights so the assumption is never hidden.
    /// `UserDefaults.integer` returns 0 for an unset key, which is what
    /// tells first-run apart from "the user actually set it to 0."
    static var assumedTypingWPM: Int {
        get {
            let stored = defaults.integer(forKey: Key.assumedTypingWPM)
            return stored > 0 ? stored : 40
        }
        set { defaults.set(newValue, forKey: Key.assumedTypingWPM) }
    }

    /// Hold-to-record (default) vs. click-to-toggle — read directly by
    /// `attachDictationHandlers` in `Quill.swift` on every hotkey press,
    /// same pattern already used there for `autoCleanupLevel`.
    static var activationMode: ActivationMode {
        get { ActivationMode(rawValue: defaults.string(forKey: Key.activationMode) ?? "") ?? .hold }
        set { defaults.set(newValue.rawValue, forKey: Key.activationMode) }
    }

    /// Text Formatting toggles (Phase 5g, FluidVoice-inspired) — off by
    /// default, same "opt in" posture as Auto Cleanup. Read by
    /// `TextFormatting.apply` right before injection, after Auto Cleanup
    /// has already run. `smartCapitalization` takes priority over
    /// `lowercaseFirstLetter` when both are on, since it's the more
    /// specific of the two — see `TextFormatting.swift`.
    static var lowercaseFirstLetter: Bool {
        get { defaults.bool(forKey: Key.lowercaseFirstLetter) }
        set { defaults.set(newValue, forKey: Key.lowercaseFirstLetter) }
    }

    static var spaceBetweenDictations: Bool {
        get { defaults.bool(forKey: Key.spaceBetweenDictations) }
        set { defaults.set(newValue, forKey: Key.spaceBetweenDictations) }
    }

    static var smartCapitalization: Bool {
        get { defaults.bool(forKey: Key.smartCapitalization) }
        set { defaults.set(newValue, forKey: Key.smartCapitalization) }
    }

    /// Master on/off for `TranscriptSanitizer.cleanUpFillers` — defaults
    /// true, matching the behavior every existing user already has today
    /// (that pass has always run unconditionally as the Local AI/Medium
    /// fallback, and formerly also Auto Cleanup's selectable "Light" tier
    /// before that was retired for never doing real formatting; this
    /// setting just makes the pass switchable rather than always-on).
    static var removeFillerWords: Bool {
        get { defaults.object(forKey: Key.removeFillerWords) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.removeFillerWords) }
    }

    /// User-editable filler word list (Voice Engine). `UserDefaults`
    /// returns nil, not an empty array, for a key that was never set —
    /// that's what tells "never customized, use the default list" apart
    /// from "customized down to zero words," which stays a legitimate
    /// (if unusual) choice once made.
    static var fillerWords: [String] {
        get { defaults.array(forKey: Key.fillerWords) as? [String] ?? defaultFillerWords }
        set { defaults.set(newValue, forKey: Key.fillerWords) }
    }

    /// OpenRouter's chosen model (Enhancement Engine) — the one provider
    /// with a real picker, since it fronts hundreds of models through one
    /// key. Defaults to the same "openai/gpt-4o-mini" the other providers'
    /// fixed choices lean on, so an unconfigured OpenRouter key still
    /// calls something sane.
    static var openRouterModel: String {
        get { defaults.string(forKey: Key.openRouterModel) ?? "openai/gpt-4o-mini" }
        set { defaults.set(newValue, forKey: Key.openRouterModel) }
    }

    /// Local-only debug log capture (`QuillLog`) — on by default so a
    /// real log actually exists the moment someone hits a bug worth
    /// reporting, rather than only after they've dug through Settings
    /// first. Never includes dictated text, never sent anywhere on its
    /// own — the only way any of it leaves this Mac is a user explicitly
    /// attaching it via Send Feedback. Turning this off also wipes
    /// whatever's already captured, so "off" means there is no log, not
    /// that an old one just lingers.
    static var debugLoggingEnabled: Bool {
        get { defaults.object(forKey: Key.debugLoggingEnabled) as? Bool ?? true }
        set {
            defaults.set(newValue, forKey: Key.debugLoggingEnabled)
            if !newValue {
                Task { await QuillLog.shared.clear() }
            }
        }
    }

    /// Pushes `darkModeEnabled` onto NSApp — call once at each app-launch
    /// entry point (before any window is shown) and again whenever the
    /// Settings toggle changes it.
    static func applyAppearance() {
        NSApp.appearance = NSAppearance(named: darkModeEnabled ? .darkAqua : .aqua)
    }
}

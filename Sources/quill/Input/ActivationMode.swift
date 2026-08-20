import Foundation

/// How dictation starts and stops (Phase 5f, inspired by FluidVoice's
/// Global Hotkey settings). `.hold` is Quill's original behavior — hold
/// the hotkey, speak, release to finish. `.toggle` only needs a tap to
/// start and a second tap to stop, so a longer thought doesn't mean
/// physically holding a key down the whole time. `.automatic` accepts
/// either gesture on the same press, decided by how long it was held.
///
/// Defaults to `.hold` — existing users' muscle memory shouldn't change
/// underneath them without a deliberate choice.
enum ActivationMode: String, CaseIterable, Identifiable {
    case hold = "Hold"
    case toggle = "Click to toggle"
    case automatic = "Automatic (Both)"

    var id: String { rawValue }

    /// How long a press has to be held before it's treated as a hold
    /// gesture rather than a tap, in `.automatic` mode. Below this, a
    /// quick press-and-release reads as "start a toggle recording," not
    /// "the whole recording was that short."
    static let automaticHoldThreshold: TimeInterval = 0.35

    var detail: String {
        switch self {
        case .hold:
            return "Hold the hotkey, speak, release to finish."
        case .toggle:
            return "Press once to start, press again to stop. Nothing to hold down."
        case .automatic:
            return "Tap to toggle, or hold and release like a walkie-talkie. Both work."
        }
    }
}

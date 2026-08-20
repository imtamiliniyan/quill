import SwiftUI

/// Live mic input level meter (Phase 5b) — shown in onboarding's Microphone
/// permission row once granted, so seeing the permission turn green and
/// seeing the mic actually pick up sound happen in the same glance. The
/// moving bars are the actual proof; a checkmark alone only asserts it.
///
/// Reuses `RecordingOverlay`'s existing `LevelBars` shaping and `Waveform`
/// rendering — same visual language wherever a level meter shows up in
/// Quill, not a second implementation of the same idea.
///
/// Drives its own short-lived `AudioCapture` instance, entirely separate
/// from the real dictation pipeline's (which doesn't even start listening
/// until onboarding finishes — see `Quill.swift`'s `box == nil` guard on
/// `attachDictationHandlers`). Captured samples are never read, only their
/// RMS level; `stop()`'s returned buffer is discarded on every path here.
struct MicLevelMeter: View {
    @StateObject private var model = MicLevelModel()

    var body: some View {
        Waveform(levels: model.levels)
            .frame(width: 72, height: 20)
            .onAppear { model.start() }
            .onDisappear { model.stop() }
    }
}

@MainActor
private final class MicLevelModel: ObservableObject {
    @Published var levels: [Float] = Array(repeating: 0, count: LevelBars.count)
    private let capture = AudioCapture()

    func start() {
        capture.onLevel = { [weak self] level in
            Task { @MainActor in self?.levels = LevelBars.shape(level) }
        }
        // Onboarding only ever shows this once Microphone is already
        // granted, so a start failure here would mean something changed
        // out from under the permission (revoked mid-flow, device
        // unplugged) — nothing actionable to do but leave the bars flat.
        try? capture.start()
    }

    func stop() {
        capture.onLevel = nil
        _ = capture.stop()
        levels = Array(repeating: 0, count: LevelBars.count)
    }
}

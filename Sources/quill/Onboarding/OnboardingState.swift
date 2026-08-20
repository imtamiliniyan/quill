import AVFoundation
import AppKit
import ApplicationServices
import Foundation

enum OnboardingStep {
    case permissions
    case modelPicker
    case downloading
    /// Local AI (Phase 5e): offered once, right after the transcription
    /// model finishes downloading — mirrors FluidVoice's "one more thing"
    /// placement, but for Quill's own MLX-backed AutoCleanupLevel.localAI
    /// rather than their Fluid Intelligence. First-run only for now; a
    /// returning user who already completed onboarding before this step
    /// existed won't see it here — that's what Phase 5c's "Run Onboarding
    /// Again" is for, not yet built.
    case localAI
    case done
}

/// Drives the first-run (and "something regressed") experience. Polls
/// permission state while visible; the actual permission *requests* only
/// fire from explicit user button taps, never automatically.
@MainActor
final class OnboardingState: ObservableObject {
    @Published private(set) var micGranted = false
    @Published private(set) var accessibilityGranted = false
    @Published var step: OnboardingStep
    @Published var selectedModel: TranscriptionModel?
    @Published var downloadProgress: Double?
    @Published var downloadError: String?
    @Published var localAIDownloadProgress: Double?
    @Published var localAIDownloadError: String?

    /// Set once `beginDownload` finishes — Run.run() reuses this instead of
    /// constructing (and re-warming) a second transcriber for the same model.
    private(set) var warmedTranscriber: Transcriber?

    private var pollTimer: Timer?

    init() {
        let mic = Self.checkMic()
        let accessibility = AXIsProcessTrusted()
        let model = QuillSettings.selectedModelID.flatMap(ModelRegistry.find)

        micGranted = mic
        accessibilityGranted = accessibility
        selectedModel = model

        if !mic || !accessibility {
            step = .permissions
        } else if model == nil || !QuillSettings.onboardingCompleted {
            step = .modelPicker
        } else {
            step = .done
        }
    }

    var isReady: Bool {
        micGranted && accessibilityGranted && selectedModel != nil && QuillSettings.onboardingCompleted
    }

    /// "Run Onboarding Again" (Phase 5c) — a deliberate, user-requested
    /// replay of the whole flow from the top, regardless of current
    /// permission/model state. Distinct from `init()`'s own recovery
    /// logic, which only jumps back to `.permissions` if something's
    /// actually missing; this always starts there, even when everything
    /// is already granted and set up, because the point is reviewing the
    /// flow again, not fixing something broken.
    func restart() {
        step = .permissions
    }

    func startPolling() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func tick() {
        micGranted = Self.checkMic()
        accessibilityGranted = AXIsProcessTrusted()
        if step == .permissions, micGranted, accessibilityGranted {
            step = .modelPicker
        }
    }

    private static func checkMic() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    func requestMicrophone() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            Task { @MainActor in self?.micGranted = granted }
        }
    }

    /// Accessibility can't be granted programmatically — this both
    /// registers Quill in the Accessibility list (so there's something to
    /// toggle at all) and sends the user straight to the right pane.
    func openAccessibilitySettings() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func chooseModel(_ model: TranscriptionModel) {
        selectedModel = model
        QuillSettings.selectedModelID = model.id
    }

    func beginDownload() {
        guard let model = selectedModel else { return }
        step = .downloading
        downloadProgress = 0
        downloadError = nil
        let transcriber = TranscriberFactory.make(for: model)
        Task {
            do {
                try await transcriber.warmUp(progress: { [weak self] fraction in
                    Task { @MainActor in self?.downloadProgress = fraction }
                })
                warmedTranscriber = transcriber
                downloadProgress = 1
                QuillSettings.onboardingCompleted = true
                step = .localAI
            } catch {
                downloadError = "\(error)"
            }
        }
    }

    /// Downloads the Local AI model (~1.8 GB) and turns Auto Cleanup on
    /// at the `.localAI` level once it lands — the "Download & Enable"
    /// path on the Local AI onboarding step.
    func beginLocalAIDownload() {
        localAIDownloadProgress = 0
        localAIDownloadError = nil
        Task {
            do {
                try await LocalEnhancer.shared.download { [weak self] fraction in
                    Task { @MainActor in self?.localAIDownloadProgress = fraction }
                }
                QuillSettings.autoCleanupLevel = .localAI
                step = .done
            } catch {
                localAIDownloadError = "\(error)"
            }
        }
    }

    /// "I'll use my own AI key instead" — sets Auto Cleanup to the BYOK
    /// tier without downloading anything here; the actual key still gets
    /// entered later in Settings > Style, same as anyone who turns Medium
    /// on manually. No local model download triggered.
    func useOwnAIKeyInstead() {
        QuillSettings.autoCleanupLevel = .medium
        step = .done
    }

    /// Neither now — Auto Cleanup stays at its `.none` default. Nothing
    /// downloaded, nothing enabled; can be turned on later from Settings.
    func skipLocalAI() {
        step = .done
    }
}

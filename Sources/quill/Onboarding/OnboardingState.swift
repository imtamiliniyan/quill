import AVFoundation
import AppKit
import ApplicationServices
import Foundation

enum OnboardingStep {
    case permissions
    case modelPicker
    case downloading
    /// Offers the recommended Local AI model (S1-mini) for cleanup. Small
    /// enough now (~0.5 GB) to suggest up front, unlike the 1.8 GB Llama
    /// that got the old Local AI step retired. Optional: "Not now" keeps
    /// Harper.
    case cleanup
    /// A quick, lightweight pick — Casual or Formal — for whichever tone
    /// Local AI/Cloud Model rewrite into if the user ever switches to
    /// one of those later (Harper, Auto Cleanup's zero-setup default,
    /// doesn't use tone at all). Not Concise: confirmed via real testing
    /// against the actual model, Concise doesn't reliably do its one job
    /// (cutting words) on the 3B on-device model, so it stays out of
    /// this quick first-run pick — still available in full in Style's
    /// own Tone section for anyone on Cloud Model, where a larger model
    /// follows it far more reliably.
    case tone
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
                step = .cleanup
            } catch {
                downloadError = "\(error)"
            }
        }
    }

    /// Downloads S1-mini in the background and only switches Auto Cleanup
    /// to Local AI once it's on disk, so Harper keeps cleaning up in the
    /// meantime (and stays, if the download fails or Quill quits mid-way).
    func chooseCleanup(useLocalAI: Bool) {
        if useLocalAI {
            let model = LocalLLMModel.recommended
            QuillSettings.localAIModelID = model.id
            Task.detached {
                do {
                    try await LocalEnhancer.shared.download(modelID: model.id) { _ in }
                    QuillSettings.autoCleanupLevel = .localAI
                } catch {
                    FileHandle.standardError.write(Data("onboarding S1-mini download failed, staying on Harper: \(error)\n".utf8))
                }
            }
        }
        step = .tone
    }

    /// Onboarding's quick tone pick — Casual or Formal only, see
    /// `OnboardingStep.tone`'s doc comment for why Concise isn't offered
    /// here. Always completes onboarding regardless of which is picked;
    /// this is a preference, not a requirement to satisfy.
    func chooseTone(_ tone: StyleTone) {
        QuillSettings.autoCleanupTone = tone
        step = .done
    }
}

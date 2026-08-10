import AVFoundation
import AppKit
import ApplicationServices
import Foundation

enum OnboardingStep {
    case permissions
    case modelPicker
    case downloading
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
                step = .done
            } catch {
                downloadError = "\(error)"
            }
        }
    }
}

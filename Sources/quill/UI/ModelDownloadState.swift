import Foundation

/// Drives the download-progress view shown when the menu bar model switcher
/// needs to fetch a model that isn't on disk yet. Separate from
/// OnboardingState — this is a post-setup "switch models" flow, not first run.
@MainActor
final class ModelDownloadState: ObservableObject {
    @Published var model: TranscriptionModel?
    @Published var progress: Double?
    @Published var error: String?
    @Published var done = false

    private var box: TranscriberBox?
    private var onSwitched: (() -> Void)?

    func start(model: TranscriptionModel, box: TranscriberBox, onSwitched: @escaping () -> Void) {
        self.model = model
        self.box = box
        self.onSwitched = onSwitched
        retry()
    }

    func retry() {
        guard let model, let box else { return }
        progress = 0
        error = nil
        done = false

        let transcriber = TranscriberFactory.make(for: model)
        Task {
            do {
                try await transcriber.warmUp(progress: { [weak self] fraction in
                    Task { @MainActor in self?.progress = fraction }
                })
                box.switchTo(transcriber, modelID: model.id)
                progress = 1
                done = true
                onSwitched?()
            } catch {
                self.error = "\(error)"
            }
        }
    }
}

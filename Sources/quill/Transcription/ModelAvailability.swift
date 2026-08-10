import FluidAudio
import Foundation

/// Best-effort "is this model already on disk" check, so the menu bar
/// switcher can skip the confirm-and-download prompt for models that are
/// already available and switch instantly.
enum ModelAvailability {
    static func isDownloaded(_ model: TranscriptionModel) -> Bool {
        switch model.engine {
        case .parakeet:
            return AsrModels.modelsExist(at: AsrModels.defaultCacheDirectory(for: .v3))
        case .whisperKit:
            guard let whisperKitID = model.whisperKitID else { return false }
            // Empirically observed WhisperKit/Hub cache layout — there's no
            // public "is this downloaded" API, so this mirrors where
            // WhisperKit.download(variant:) actually puts files.
            let home = FileManager.default.homeDirectoryForCurrentUser
            let dir = home
                .appendingPathComponent("Documents/huggingface/models/argmaxinc/whisperkit-coreml")
                .appendingPathComponent(whisperKitID)
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else {
                return false
            }
            return !contents.isEmpty
        }
    }
}

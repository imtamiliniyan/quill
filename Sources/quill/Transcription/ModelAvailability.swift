import FluidAudio
import Foundation

/// Best-effort "is this model already on disk" check, so the menu bar
/// switcher can skip the confirm-and-download prompt for models that are
/// already available and switch instantly.
enum ModelAvailability {
    static func isDownloaded(_ model: TranscriptionModel) -> Bool {
        switch model.engine {
        case .parakeet:
            return AsrModels.modelsExist(at: AsrModels.defaultCacheDirectory(for: model.asrModelVersion))
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

    /// Deletes a downloaded model's on-disk cache directly, so Settings >
    /// General > Models can offer a trash icon with no terminal use
    /// required. Mirrors the exact paths `isDownloaded` above checks — see
    /// there for why these paths aren't discoverable through any public
    /// API.
    static func deleteFiles(for model: TranscriptionModel) throws {
        let fm = FileManager.default
        switch model.engine {
        case .parakeet:
            let dir = AsrModels.defaultCacheDirectory(for: model.asrModelVersion)
            if fm.fileExists(atPath: dir.path) {
                try fm.removeItem(at: dir)
            }
        case .whisperKit:
            guard let whisperKitID = model.whisperKitID else { return }
            let home = fm.homeDirectoryForCurrentUser
            let dir = home
                .appendingPathComponent("Documents/huggingface/models/argmaxinc/whisperkit-coreml")
                .appendingPathComponent(whisperKitID)
            if fm.fileExists(atPath: dir.path) {
                try fm.removeItem(at: dir)
            }
        }
    }
}

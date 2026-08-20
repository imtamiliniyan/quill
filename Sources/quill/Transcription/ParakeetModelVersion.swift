import FluidAudio

extension TranscriptionModel {
    /// Resolves this model's plain-string `parakeetVersion` to FluidAudio's
    /// own `AsrModelVersion` enum. Only meaningful when `engine == .parakeet`;
    /// defaults to `.v3` for anything unrecognized (matches the pre-multi-model
    /// behavior, when every Parakeet entry was implicitly v3).
    var asrModelVersion: AsrModelVersion {
        switch parakeetVersion {
        case "v2": return .v2
        case "tdtCtc110m": return .tdtCtc110m
        default: return .v3
        }
    }
}

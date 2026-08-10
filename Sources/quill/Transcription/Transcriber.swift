import Foundation

protocol Transcriber {
    var modelID: String { get }
    func transcribe(_ audio: [Float]) async throws -> String
}

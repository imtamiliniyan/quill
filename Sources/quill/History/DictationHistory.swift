import AppKit
import Foundation

/// One completed dictation. Persisted locally only — see DictationHistory.
struct DictationEntry: Codable, Identifiable {
    var id: Date { timestamp }
    let timestamp: Date
    let text: String
    let wordCount: Int
    let model: String
    let durationSeconds: Double
    /// Name of the app that was frontmost while dictating into it (e.g.
    /// "Claude", "Notes"). Purely local, used for the Insights "where you
    /// dictate" breakdown — never transmitted anywhere.
    let appName: String?
}

extension Notification.Name {
    static let quillHistoryUpdated = Notification.Name("com.tamiliniyan.quill.historyUpdated")
}

/// Append-only local history of dictations, one JSON object per line at
/// `~/Library/Application Support/Quill/history.jsonl`. Never uploaded,
/// never leaves this Mac — read directly by the Dictation and Insights
/// tabs, nothing else touches it.
enum DictationHistory {
    private static var fileURL: URL {
        let dir = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Quill", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.jsonl")
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static func append(text: String, model: String, durationSeconds: Double) {
        guard !text.isEmpty else { return }
        let wordCount = text.split(whereSeparator: { $0.isWhitespace }).count
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName
        let entry = DictationEntry(
            timestamp: Date(), text: text, wordCount: wordCount,
            model: model, durationSeconds: durationSeconds, appName: appName
        )
        guard let line = try? encoder.encode(entry), let json = String(data: line, encoding: .utf8) else { return }

        let url = fileURL
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write(Data((json + "\n").utf8))
        } else {
            try? (json + "\n").write(to: url, atomically: true, encoding: .utf8)
        }
        NotificationCenter.default.post(name: .quillHistoryUpdated, object: nil)
    }

    /// Newest first.
    static func loadAll() -> [DictationEntry] {
        guard let data = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
        let entries = data.split(separator: "\n").compactMap { line -> DictationEntry? in
            try? decoder.decode(DictationEntry.self, from: Data(line.utf8))
        }
        return entries.sorted { $0.timestamp > $1.timestamp }
    }

    static func clear() {
        try? "".write(to: fileURL, atomically: true, encoding: .utf8)
        NotificationCenter.default.post(name: .quillHistoryUpdated, object: nil)
    }
}

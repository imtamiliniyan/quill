import Foundation

/// Total words / speaking speed / streak — shared between the Insights tab
/// and the compact stats panel on the Dictation tab, so both stay in sync
/// off one calculation instead of two copies drifting apart.
struct DictationStats {
    let totalWords: Int
    let wordsPerMinute: Int
    let streak: Int

    init(entries: [DictationEntry]) {
        totalWords = entries.reduce(0) { $0 + $1.wordCount }

        let totalSeconds = entries.reduce(0.0) { $0 + $1.durationSeconds }
        wordsPerMinute = totalSeconds > 0 ? Int((Double(totalWords) / totalSeconds) * 60) : 0

        let cal = Calendar.current
        let days = Set(entries.map { cal.startOfDay(for: $0.timestamp) })
        if days.isEmpty {
            streak = 0
        } else {
            var count = 0
            var day = cal.startOfDay(for: Date())
            if !days.contains(day) {
                day = cal.date(byAdding: .day, value: -1, to: day) ?? day
            }
            while days.contains(day) {
                count += 1
                day = cal.date(byAdding: .day, value: -1, to: day) ?? day
            }
            streak = count
        }
    }
}

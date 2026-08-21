import Foundation

/// Total words / speaking speed / streak — shared between the Insights tab
/// and the compact stats panel on the Dictation tab, so both stay in sync
/// off one calculation instead of two copies drifting apart.
struct DictationStats {
    let totalWords: Int
    let wordsPerMinute: Int
    let streak: Int
    /// Longest run of consecutive dictation days ever, not just the
    /// current one — same calculation StreakCalendarView used to keep
    /// privately as `longestStreak`; consolidated here so Milestones
    /// (Phase 7) doesn't need a second copy of it.
    let bestStreak: Int
    /// Count of entries where Auto Cleanup actually changed something —
    /// `rawText` is only ever stored when it differs from the final typed
    /// text (see DictationHistory.append), so `rawText != nil` is exactly
    /// "this dictation was modified." Covers Local AI and Medium fixes.
    let fixesCount: Int

    // Phase 7 Tier 1 — all pure reductions over `entries`, nothing new
    // persisted. Personal records, not analytics: this is for the user
    // to see their own usage, computed fresh from history.jsonl every
    // time, same as everything else on this struct.
    let transcriptionsCount: Int
    let avgWords: Int
    let longestTranscriptionWords: Int
    let mostWordsInADay: Int
    let mostTranscriptionsInADay: Int

    // Phase 7 Tier 2/3 — same "pure reduction over entries" shape as
    // Tier 1 above.
    /// Total seconds actually spent dictating, across every entry — the
    /// "time you actually spent" half of Time Saved's subtraction; the
    /// "time typing would've taken" half depends on a user-set WPM, so
    /// that math stays in the view, not here.
    let totalDictationSeconds: Double
    /// Hour of day (0–23, local time) with the most dictations, or nil
    /// with no history yet. A simple mode over `Calendar.component(.hour:)`
    /// — ties resolve to whichever hour sorts first, which is fine for a
    /// "roughly when do you talk to this thing" stat, not a precise one.
    let peakHour: Int?

    init(entries: [DictationEntry]) {
        totalWords = entries.reduce(0) { $0 + $1.wordCount }
        fixesCount = entries.filter { $0.rawText != nil }.count

        let totalSeconds = entries.reduce(0.0) { $0 + $1.durationSeconds }
        wordsPerMinute = totalSeconds > 0 ? Int((Double(totalWords) / totalSeconds) * 60) : 0
        totalDictationSeconds = totalSeconds

        let cal = Calendar.current
        let hourCounts = Dictionary(grouping: entries) { cal.component(.hour, from: $0.timestamp) }
            .mapValues(\.count)
        peakHour = hourCounts.max { a, b in a.value == b.value ? a.key > b.key : a.value < b.value }?.key

        transcriptionsCount = entries.count
        avgWords = transcriptionsCount > 0 ? totalWords / transcriptionsCount : 0
        longestTranscriptionWords = entries.map(\.wordCount).max() ?? 0

        let byDay = Dictionary(grouping: entries) { cal.startOfDay(for: $0.timestamp) }
        mostWordsInADay = byDay.values.map { day in day.reduce(0) { $0 + $1.wordCount } }.max() ?? 0
        mostTranscriptionsInADay = byDay.values.map(\.count).max() ?? 0

        let days = Set(byDay.keys)
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

        let sortedDays = days.sorted()
        if sortedDays.isEmpty {
            bestStreak = 0
        } else {
            var longest = 1
            var current = 1
            for i in 1..<sortedDays.count {
                if cal.dateComponents([.day], from: sortedDays[i - 1], to: sortedDays[i]).day == 1 {
                    current += 1
                    longest = max(longest, current)
                } else {
                    current = 1
                }
            }
            bestStreak = longest
        }
    }
}

extension DictationStats {
    /// Estimated minutes saved by dictating instead of typing, given a
    /// typing-speed assumption. A bare static func (not an instance method)
    /// so callers who only have a subset of entries — "today" on Insights,
    /// the compact stats pill in the sidebar — can use the same formula as
    /// the all-time figure without building a full `DictationStats` over
    /// entries they don't need. Clamped at 0: someone who dictates slower
    /// than they'd type shouldn't see a negative "saved" number.
    static func timeSavedMinutes(words: Int, dictationSeconds: Double, assumedWPM: Int) -> Double {
        let typingMinutes = Double(words) / Double(max(assumedWPM, 1))
        return max(typingMinutes - dictationSeconds / 60.0, 0)
    }

    /// "42m" under an hour, "1h 30m" at or above — shared by every surface
    /// that shows a saved-time duration.
    static func formatMinutes(_ minutes: Double) -> String {
        let m = Int(minutes.rounded())
        if m < 60 { return "\(m)m" }
        return "\(m / 60)h \(m % 60)m"
    }
}

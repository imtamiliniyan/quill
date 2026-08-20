import SwiftUI

/// Words-per-day bar chart with a 7-day/30-day toggle — a sibling to
/// StreakCalendarView's GitHub-style heatmap, not a replacement: the
/// heatmap answers "did I dictate that day," this answers "how much."
/// Same local-only computation as everything else in Insights.
struct ActivityChartView: View {
    let entries: [DictationEntry]

    @State private var range: Range = .week

    private enum Range: Int, CaseIterable, Identifiable {
        case week = 7
        case month = 30
        var id: Int { rawValue }
        var label: String { self == .week ? "7 days" : "30 days" }
    }

    private struct Day {
        let date: Date
        let words: Int
    }

    private var days: [Day] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let counts: [Date: Int] = entries.reduce(into: [:]) { dict, entry in
            let day = cal.startOfDay(for: entry.timestamp)
            dict[day, default: 0] += entry.wordCount
        }
        return (0..<range.rawValue).reversed().map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: today) ?? today
            return Day(date: date, words: counts[date] ?? 0)
        }
    }

    private var maxWords: Int { max(days.map(\.words).max() ?? 0, 1) }
    private var totalWords: Int { days.reduce(0) { $0 + $1.words } }
    private var activeDays: Int { days.filter { $0.words > 0 }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Activity")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Picker("", selection: $range) {
                    ForEach(Range.allCases) { r in
                        Text(r.label).tag(r)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 150)
            }

            GeometryReader { geo in
                let spacing: CGFloat = range == .week ? 8 : 3
                let barWidth = max((geo.size.width - spacing * CGFloat(days.count - 1)) / CGFloat(days.count), 1)
                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(days.indices, id: \.self) { i in
                        let day = days[i]
                        let fraction = Double(day.words) / Double(maxWords)
                        RoundedRectangle(cornerRadius: barWidth > 6 ? 3 : 1.5)
                            .fill(day.words > 0 ? Theme.accent.opacity(0.55 + 0.45 * fraction) : Theme.fillHover)
                            .frame(width: barWidth, height: max(CGFloat(fraction) * 110, day.words > 0 ? 4 : 2))
                            .help("\(dayLabel(day.date)): \(day.words) \(day.words == 1 ? "word" : "words")")
                    }
                }
                .frame(height: 110, alignment: .bottom)
            }
            .frame(height: 110)

            if range == .week {
                HStack(spacing: 8) {
                    ForEach(days.indices, id: \.self) { i in
                        Text(weekdayLabel(days[i].date))
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            Text("\(totalWords) words across \(activeDays) active \(activeDays == 1 ? "day" : "days")")
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
        }
    }

    private func weekdayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}

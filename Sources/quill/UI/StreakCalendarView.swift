import SwiftUI

/// GitHub-contribution-style heatmap of dictation activity over the last
/// 18 weeks. Purely local, computed from history.jsonl — unlike Wispr's
/// "Top X%" comparison (which needs cross-user telemetry we deliberately
/// don't collect), everything here is derived only from this Mac's own
/// history, so there's nothing to fake or leave blank.
struct StreakCalendarView: View {
    let entries: [DictationEntry]
    let currentStreak: Int

    private let weekCount = 18
    private let cellSize: CGFloat = 18
    private let cellSpacing: CGFloat = 4
    private let monthLabelHeight: CGFloat = 18

    private struct Day {
        let date: Date
        let count: Int
    }

    private var weeks: [[Day]] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today) // 1 = Sunday
        let thisWeekStart = cal.date(byAdding: .day, value: -(weekday - 1), to: today) ?? today
        let firstWeekStart = cal.date(byAdding: .day, value: -7 * (weekCount - 1), to: thisWeekStart) ?? thisWeekStart

        let counts: [Date: Int] = entries.reduce(into: [:]) { dict, entry in
            let day = cal.startOfDay(for: entry.timestamp)
            dict[day, default: 0] += 1
        }

        return (0..<weekCount).map { w in
            (0..<7).map { d in
                let date = cal.date(byAdding: .day, value: w * 7 + d, to: firstWeekStart) ?? firstWeekStart
                return Day(date: date, count: counts[cal.startOfDay(for: date)] ?? 0)
            }
        }
    }

    private var longestStreak: Int {
        let cal = Calendar.current
        let days = Set(entries.map { cal.startOfDay(for: $0.timestamp) }).sorted()
        guard !days.isEmpty else { return 0 }
        var longest = 1
        var current = 1
        for i in 1..<days.count {
            if cal.dateComponents([.day], from: days[i - 1], to: days[i]).day == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("\(currentStreak) \(currentStreak == 1 ? "day" : "days") streak")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("Longest: \(longestStreak) \(longestStreak == 1 ? "day" : "days")")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: cellSpacing) {
                    VStack(alignment: .leading, spacing: cellSpacing) {
                        ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { d in
                            Text(d)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.4))
                                .frame(width: 32, height: cellSize, alignment: .leading)
                        }
                    }
                    .padding(.top, monthLabelHeight)

                    VStack(alignment: .leading, spacing: 4) {
                        monthLabelsRow
                        HStack(spacing: cellSpacing) {
                            ForEach(weeks.indices, id: \.self) { w in
                                VStack(spacing: cellSpacing) {
                                    ForEach(weeks[w].indices, id: \.self) { d in
                                        let day = weeks[w][d]
                                        let isFuture = day.date > Date()
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(isFuture ? Color.clear : color(for: day.count))
                                            .frame(width: cellSize, height: cellSize)
                                            .help(isFuture ? "" : "\(day.count) \(day.count == 1 ? "dictation" : "dictations")")
                                    }
                                }
                            }
                        }
                    }
                }
            }

            HStack(spacing: 6) {
                Text("Less")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                ForEach([0, 1, 3, 6], id: \.self) { level in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color(for: level))
                        .frame(width: cellSize, height: cellSize)
                }
                Text("More")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }

    private var monthLabelsRow: some View {
        HStack(spacing: cellSpacing) {
            ForEach(weeks.indices, id: \.self) { w in
                let showLabel = w == 0 || monthLabel(for: weeks[w]) != monthLabel(for: weeks[w - 1])
                // minWidth, not a fixed narrow width — a 3-letter month
                // abbreviation ("Aug") doesn't fit in one cellSize-wide
                // column at any readable font size, and clipping it to
                // exactly that width was truncating every label to "…".
                // Letting it size naturally means it can spill slightly
                // into the next column, which is fine since labels only
                // appear a month apart.
                Text(showLabel ? monthLabel(for: weeks[w]) : "")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                    .fixedSize()
                    .frame(minWidth: cellSize, alignment: .leading)
            }
        }
        .frame(height: monthLabelHeight, alignment: .leading)
    }

    private func monthLabel(for week: [Day]) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: week.first?.date ?? Date())
    }

    private func color(for count: Int) -> Color {
        switch count {
        case 0: return Color.white.opacity(0.05)
        case 1...2: return Theme.accent.opacity(0.3)
        case 3...5: return Theme.accent.opacity(0.6)
        default: return Theme.accent
        }
    }
}

import SwiftUI

/// GitHub-contribution-style heatmap of dictation activity over the last
/// 18 weeks. Purely local, computed from history.jsonl — unlike Wispr's
/// "Top X%" comparison (which needs cross-user telemetry we deliberately
/// don't collect), everything here is derived only from this Mac's own
/// history, so there's nothing to fake or leave blank.
struct StreakCalendarView: View {
    let entries: [DictationEntry]
    let currentStreak: Int
    let longestStreak: Int

    private let weekCount = 18
    private let cellSize: CGFloat = 18
    private let cellSpacing: CGFloat = 4
    private let monthLabelHeight: CGFloat = 18

    /// Which cell the pointer is over, if any — cells are addressed by a
    /// (week, day) pair below, kept as two plain optionals rather than an
    /// optional tuple purely so equality checks stay simple. Drives the
    /// floating word-count tooltip, same pattern as `ActivityChartView`'s
    /// hover tooltip.
    @State private var hoveredWeek: Int?
    @State private var hoveredDay: Int?

    private struct Day {
        let date: Date
        let count: Int
        let words: Int
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
        let words: [Date: Int] = entries.reduce(into: [:]) { dict, entry in
            let day = cal.startOfDay(for: entry.timestamp)
            dict[day, default: 0] += entry.wordCount
        }

        return (0..<weekCount).map { w in
            (0..<7).map { d in
                let date = cal.date(byAdding: .day, value: w * 7 + d, to: firstWeekStart) ?? firstWeekStart
                let dayStart = cal.startOfDay(for: date)
                return Day(date: date, count: counts[dayStart] ?? 0, words: words[dayStart] ?? 0)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("\(currentStreak) \(currentStreak == 1 ? "day" : "days") streak")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text("Longest: \(longestStreak) \(longestStreak == 1 ? "day" : "days")")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                // Extra top room, above both columns together (not just
                // the grid) so the weekday-label column stays aligned
                // with the grid rows next to it — this is purely headroom
                // for a hovered cell's tooltip to float in without being
                // clipped by the ScrollView.
                HStack(alignment: .top, spacing: cellSpacing) {
                    VStack(alignment: .leading, spacing: cellSpacing) {
                        ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { d in
                            Text(d)
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textTertiary)
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
                                            .contentShape(Rectangle())
                                            .onHover { hovering in
                                                guard !isFuture else { return }
                                                if hovering {
                                                    hoveredWeek = w
                                                    hoveredDay = d
                                                } else if hoveredWeek == w && hoveredDay == d {
                                                    hoveredWeek = nil
                                                    hoveredDay = nil
                                                }
                                            }
                                            .overlay(alignment: tooltipAlignment(forWeek: w)) {
                                                if hoveredWeek == w, hoveredDay == d {
                                                    tooltip(for: day)
                                                        .fixedSize()
                                                        .offset(y: -32)
                                                }
                                            }
                                            .accessibilityLabel(
                                                "\(dayLabel(day.date)): \(day.words) \(day.words == 1 ? "word" : "words")"
                                            )
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.top, 32)
            }

            HStack(spacing: 6) {
                Text("Less")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
                ForEach([0, 1, 3, 6], id: \.self) { level in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color(for: level))
                        .frame(width: cellSize, height: cellSize)
                }
                Text("More")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
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
                    .foregroundColor(Theme.textTertiary)
                    .fixedSize()
                    .frame(minWidth: cellSize, alignment: .leading)
            }
        }
        .frame(height: monthLabelHeight, alignment: .leading)
    }

    /// A tooltip centered on an 18pt-wide cell needs real room (~66pt) to
    /// either side. Cells in the first/last few columns don't have that —
    /// confirmed from a real screenshot: the calendar auto-scrolls to
    /// today by default, so the rightmost columns sit flush against the
    /// visible edge, and a centered tooltip there got its trailing text
    /// clipped off. Anchoring the tooltip to whichever corner of the cell
    /// still has room (trailing edge flush for the last few columns,
    /// leading edge flush for the first few, centered everywhere else)
    /// means it only ever grows toward the side that actually has space.
    private func tooltipAlignment(forWeek w: Int) -> Alignment {
        if w <= 2 { return .topLeading }
        if w >= weekCount - 3 { return .topTrailing }
        return .top
    }

    private func monthLabel(for week: [Day]) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: week.first?.date ?? Date())
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE, d MMM"
        return f.string(from: date)
    }

    /// Word count first and boldest — that's the number that actually
    /// answers "how much am I talking to this app," which is what was
    /// missing next to the existing OS `.help(...)` tooltip (delayed,
    /// dictation-count-only). Same visual language as
    /// `ActivityChartView`'s tooltip, just a shorter card since there's no
    /// picker/segmented control above this one to visually match.
    private func tooltip(for day: Day) -> some View {
        VStack(spacing: 2) {
            Text(dayLabel(day.date))
                .font(.system(size: 9.5, weight: .medium))
                .foregroundColor(Theme.tooltipTextSecondary)
            Text("\(day.words) \(day.words == 1 ? "word" : "words")")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Theme.tooltipTextPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(minWidth: 84)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.tooltipBackground)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.tooltipBorder, lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
        .allowsHitTesting(false)
    }

    private func color(for count: Int) -> Color {
        switch count {
        case 0: return Theme.textQuaternary
        case 1...2: return Theme.accent.opacity(0.3)
        case 3...5: return Theme.accent.opacity(0.6)
        default: return Theme.accent
        }
    }
}

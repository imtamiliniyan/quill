import SwiftUI

/// Words-per-day bar chart with a 7-day/30-day toggle — a sibling to
/// StreakCalendarView's GitHub-style heatmap, not a replacement: the
/// heatmap answers "did I dictate that day," this answers "how much."
/// Same local-only computation as everything else in Insights.
struct ActivityChartView: View {
    let entries: [DictationEntry]

    @State private var range: Range = .week
    /// Which bar the pointer is currently over, if any — drives the
    /// floating date/word-count tooltip. Interaction reference only
    /// (hover-to-reveal a value bubble above the bar): FluidVoice's own
    /// activity chart does this, no code or styling borrowed, just the
    /// pattern that a bare `.help(...)` OS tooltip (delayed, plain text,
    /// no design control) doesn't really deliver.
    @State private var hoveredIndex: Int?

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
            .onChange(of: range) { hoveredIndex = nil }

            // Reserved row for the tooltip so it has somewhere to sit
            // without shifting the bars below it — empty and inert
            // whenever nothing's hovered.
            GeometryReader { geo in
                if let hoveredIndex, hoveredIndex < days.count {
                    tooltip(for: days[hoveredIndex])
                        .position(x: xCenter(hoveredIndex, width: geo.size.width), y: geo.size.height - 4)
                }
            }
            .frame(height: 34)

            GeometryReader { geo in
                let spacing = barSpacing
                let barWidth = self.barWidth(width: geo.size.width)
                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(days.indices, id: \.self) { i in
                        let day = days[i]
                        let fraction = Double(day.words) / Double(maxWords)
                        RoundedRectangle(cornerRadius: barWidth > 6 ? 3 : 1.5)
                            .fill(barColor(day: day, index: i, fraction: fraction))
                            .frame(width: barWidth, height: max(CGFloat(fraction) * 110, day.words > 0 ? 4 : 2))
                            .contentShape(Rectangle())
                            .onHover { hovering in
                                hoveredIndex = hovering ? i : (hoveredIndex == i ? nil : hoveredIndex)
                            }
                            .accessibilityLabel("\(dayLabel(day.date)): \(day.words) \(day.words == 1 ? "word" : "words")")
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

    // MARK: - Bar geometry (shared between the tooltip row and the bars
    // themselves, so a hovered bar's tooltip lines up exactly above it)

    private var barSpacing: CGFloat { range == .week ? 8 : 3 }

    private func barWidth(width: CGFloat) -> CGFloat {
        max((width - barSpacing * CGFloat(days.count - 1)) / CGFloat(days.count), 1)
    }

    private func xCenter(_ index: Int, width: CGFloat) -> CGFloat {
        let barWidth = self.barWidth(width: width)
        let raw = CGFloat(index) * (barWidth + barSpacing) + barWidth / 2
        // Keep the tooltip's own half-width from sliding off either edge
        // of the chart for the first/last bar.
        let halfTooltipWidth: CGFloat = 42
        return min(max(raw, halfTooltipWidth), max(width - halfTooltipWidth, halfTooltipWidth))
    }

    private func barColor(day: Day, index: Int, fraction: Double) -> Color {
        guard day.words > 0 else { return Theme.fillHover }
        let base = 0.55 + 0.45 * fraction
        return Theme.accent.opacity(hoveredIndex == index ? 1.0 : base)
    }

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

    private func weekdayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE, d MMM"
        return f.string(from: date)
    }
}

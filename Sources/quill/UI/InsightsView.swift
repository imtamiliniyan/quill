import SwiftUI

struct InsightsView: View {
    @State private var entries: [DictationEntry] = DictationHistory.loadAll()

    private var totalWords: Int { entries.reduce(0) { $0 + $1.wordCount } }

    private var wordsPerMinute: Int {
        let totalSeconds = entries.reduce(0.0) { $0 + $1.durationSeconds }
        guard totalSeconds > 0 else { return 0 }
        return Int((Double(totalWords) / totalSeconds) * 60)
    }

    private var streak: Int {
        let cal = Calendar.current
        let days = Set(entries.map { cal.startOfDay(for: $0.timestamp) })
        guard !days.isEmpty else { return 0 }
        var count = 0
        var day = cal.startOfDay(for: Date())
        // Today doesn't have to have an entry yet for the streak to still
        // count from yesterday backward.
        if !days.contains(day) {
            day = cal.date(byAdding: .day, value: -1, to: day) ?? day
        }
        while days.contains(day) {
            count += 1
            day = cal.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return count
    }

    /// Which apps you dictate into, by share of dictations — the local,
    /// no-AI equivalent of Wispr's app-usage breakdown. Deliberately not
    /// doing their "Voice Profile" persona card — that needs an LLM to
    /// write prose about your habits, which is out of scope for a
    /// fully-local feature.
    private var appBreakdown: [(name: String, count: Int)] {
        let named = entries.compactMap { $0.appName }
        let counts = Dictionary(grouping: named, by: { $0 }).mapValues(\.count)
        return counts.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    var body: some View {
        Group {
            if entries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            statCard(value: "\(totalWords)", label: "total words")
                            statCard(value: "\(wordsPerMinute)", label: "words / min")
                            statCard(value: "\(streak)", label: streak == 1 ? "day streak" : "day streak")
                        }

                        if !appBreakdown.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Where you dictate")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                VStack(spacing: 8) {
                                    ForEach(appBreakdown.prefix(6), id: \.name) { item in
                                        appRow(name: item.name, count: item.count)
                                    }
                                }
                            }
                            .padding(16)
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(10)
                        }

                        Text("Computed entirely from history.jsonl on this Mac — nothing here is sent anywhere.")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    .padding(20)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: .quillHistoryUpdated)) { _ in
            entries = DictationHistory.loadAll()
        }
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
    }

    private func appRow(name: String, count: Int) -> some View {
        let fraction = appBreakdown.first.map { Double(count) / Double($0.count) } ?? 0
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                Text("\(count)")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.06))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.accent.opacity(0.7))
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 5)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 28))
                .foregroundColor(Theme.accent)
            Text("No insights yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            Text("Word counts, speaking speed, and streaks will show up here once you've dictated a few times — all computed locally.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .padding(32)
    }
}

import SwiftUI

struct InsightsView: View {
    @State private var entries: [DictationEntry] = DictationHistory.loadAll()

    private var stats: DictationStats { DictationStats(entries: entries) }

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
        VStack(alignment: .leading, spacing: 0) {
            Text("Insights")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, Theme.pagePadding)
                .padding(.bottom, 16)

            if entries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 12) {
                            wpmCard
                            fixesLockedCard
                            totalWordsCard
                        }

                        if !appBreakdown.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Where you dictate")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Theme.textPrimary)
                                    Spacer()
                                    Text("\(appBreakdown.count) apps used")
                                        .font(.system(size: 11))
                                        .foregroundColor(Theme.textTertiary)
                                }
                                VStack(spacing: 10) {
                                    ForEach(appBreakdown.prefix(6), id: \.name) { item in
                                        appRow(name: item.name, count: item.count)
                                    }
                                }
                            }
                            .padding(18)
                            .quillCard()
                        }

                        StreakCalendarView(entries: entries, currentStreak: stats.streak)
                            .padding(18)
                            .quillCard()

                        Label("Computed entirely from history.jsonl on this Mac. Nothing here is sent anywhere.", systemImage: "lock.shield")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textTertiary)
                    }
                    .padding(.horizontal, Theme.pagePadding)
                    .padding(.bottom, 20)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onReceive(NotificationCenter.default.publisher(for: .quillHistoryUpdated)) { _ in
            entries = DictationHistory.loadAll()
        }
    }

    // MARK: - Top cards

    /// A gauge, not a percentile — Wispr's "Top 0.5%" needs comparing
    /// against every other user, which would mean collecting usage data
    /// from people who never agreed to that. We only ever know about this
    /// Mac, so the gauge shows the number against a fixed scale instead of
    /// a fabricated ranking.
    private var wpmCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WORDS PER MINUTE")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Theme.textTertiary)

            ZStack {
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Theme.fillHover, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(135))
                Circle()
                    .trim(from: 0, to: 0.75 * min(Double(stats.wordsPerMinute) / 220.0, 1.0))
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(135))
                Text("\(stats.wordsPerMinute)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
            }
            .frame(width: 64, height: 64)
            .frame(maxWidth: .infinity)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Self.cardHeight)
        .quillCard()
    }

    /// Shared fixed height for the three top stat cards — they hold very
    /// different content (a gauge, a locked placeholder, a number-plus-row),
    /// so nothing about their natural sizing lines up without forcing it.
    private static let cardHeight: CGFloat = 150

    /// Style/BYOK is actually built now — this used to be a permanent
    /// locked placeholder from before it shipped. Unlocks the moment
    /// either provider has a key connected (matches the card's own copy,
    /// which talks about connecting a key, not about which Auto Cleanup
    /// level is on), and shows the real count once unlocked.
    private var hasStyleKey: Bool {
        APIKeyStore.hasKey(for: .openAI) || APIKeyStore.hasKey(for: .anthropic)
    }

    private var fixesLockedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: hasStyleKey ? "checkmark.circle.fill" : "lock.fill")
                    .font(.system(size: 10))
                    .foregroundColor(hasStyleKey ? Theme.accent : Theme.textTertiary)
                Text("FIXES MADE BY QUILL")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.textTertiary)
            }
            Text(hasStyleKey ? "\(stats.fixesCount)" : "--")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(hasStyleKey ? Theme.textPrimary : Theme.textTertiary)
            Spacer(minLength: 0)
            Text(
                hasStyleKey
                    ? "Dictations cleaned up by Auto Cleanup so far, across Light and Medium."
                    : "Connect an OpenAI or Anthropic key in Style to enable grammar and tone fixes."
            )
            .font(.system(size: 11))
            .foregroundColor(Theme.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Self.cardHeight)
        .quillCard()
    }

    private var totalWordsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(stats.totalWords)")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            Text("TOTAL WORDS DICTATED")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Theme.textTertiary)
            Spacer(minLength: 8)
            Divider().opacity(0.1)
            HStack(spacing: 6) {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
                Text("Desktop")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Text("\(stats.totalWords)")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Self.cardHeight)
        .quillCard()
    }

    // MARK: - App breakdown

    private func appRow(name: String, count: Int) -> some View {
        let fraction = appBreakdown.first.map { Double(count) / Double($0.count) } ?? 0
        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(name)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.fillHover)
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
                .foregroundColor(Theme.textPrimary)
            Text("Word counts, speaking speed, and streaks will show up here once you've dictated a few times, all computed locally.")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

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
                .foregroundColor(.white)
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
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(appBreakdown.count) apps used")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.4))
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

                        Label("Computed entirely from history.jsonl on this Mac — nothing here is sent anywhere.", systemImage: "lock.shield")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.35))
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
                .foregroundColor(.white.opacity(0.4))

            ZStack {
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(135))
                Circle()
                    .trim(from: 0, to: 0.75 * min(Double(stats.wordsPerMinute) / 220.0, 1.0))
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(135))
                Text("\(stats.wordsPerMinute)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
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

    /// Preview of the Style/BYOK feature (not built yet) — shown locked
    /// rather than hidden, so it's clear what connecting an API key will
    /// unlock, per the plan: rewriting is entirely opt-in, off until a key
    /// is added, and never touches text without one.
    private var fixesLockedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.35))
                Text("FIXES MADE BY QUILL")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            Text("—")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white.opacity(0.25))
            Spacer(minLength: 0)
            Text("Connect an OpenAI or Anthropic key in Style to enable grammar and tone fixes.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))
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
                .foregroundColor(.white)
            Text("TOTAL WORDS DICTATED")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
            Spacer(minLength: 8)
            Divider().opacity(0.1)
            HStack(spacing: 6) {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                Text("Desktop")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(stats.totalWords)")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

import SwiftUI

struct InsightsView: View {
    @State private var entries: [DictationEntry] = DictationHistory.loadAll()
    @State private var assumedWPM: Int = QuillSettings.assumedTypingWPM
    @State private var confirmingResetAll = false

    private var stats: DictationStats { DictationStats(entries: entries) }

    // MARK: - Today (Phase 7 "Today" framing)

    private var todayEntries: [DictationEntry] {
        entries.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    private var todayWords: Int { todayEntries.reduce(0) { $0 + $1.wordCount } }
    private var todaySessions: Int { todayEntries.count }

    private var todaySavedMinutes: Double {
        DictationStats.timeSavedMinutes(
            words: todayWords,
            dictationSeconds: todayEntries.reduce(0.0) { $0 + $1.durationSeconds },
            assumedWPM: assumedWPM
        )
    }

    // MARK: - Quick insights grid

    /// Local AI (Phase 4a) makes real, model-driven fixes without any
    /// key — the old BYOK-only gate on "fixes made" undercounted the
    /// moment that shipped. Present-tense capability check, same
    /// convention `hasStyleKey` already used (not per-entry provenance).
    private var hasAIEnhancement: Bool {
        hasStyleKey || (QuillSettings.autoCleanupLevel == .localAI && LocalEnhancer.isDownloaded())
    }

    private var aiEnhancedPercent: Int {
        stats.transcriptionsCount > 0 ? Int((Double(stats.fixesCount) / Double(stats.transcriptionsCount)) * 100) : 0
    }

    private var topAppsSummary: String {
        appBreakdown.isEmpty ? "--" : appBreakdown.prefix(3).map(\.name).joined(separator: ", ")
    }

    private var peakTimeLabel: String {
        guard let hour = stats.peakHour else { return "--" }
        return "\(hour)-\((hour + 1) % 24)"
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
                        todayCard

                        HStack(alignment: .top, spacing: 12) {
                            wpmCard
                            fixesLockedCard
                            totalWordsCard
                        }

                        timeSavedCard

                        ActivityChartView(entries: entries)
                            .padding(18)
                            .quillCard()

                        quickInsightsGrid

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

                        StreakCalendarView(entries: entries, currentStreak: stats.streak, longestStreak: stats.bestStreak)
                            .padding(18)
                            .quillCard()

                        personalRecordsCard

                        milestonesCard

                        Label("Computed entirely from history.jsonl on this Mac. Nothing here is sent anywhere.", systemImage: "lock.shield")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textTertiary)

                        resetAllStatsLink
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

    // MARK: - Today

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text(todayWords > 0 ? "\(todayWords) words dictated so far today." : "Nothing dictated yet today.")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
                if stats.streak > 0 {
                    Label("\(stats.streak) \(stats.streak == 1 ? "day" : "days")", systemImage: "flame.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 0) {
                todayStat(icon: "text.alignleft", value: "\(todayWords)", label: "words")
                Divider().frame(height: 28).padding(.horizontal, 14)
                todayStat(icon: "clock.fill", value: DictationStats.formatMinutes(todaySavedMinutes), label: "saved")
                Divider().frame(height: 28).padding(.horizontal, 14)
                todayStat(icon: "waveform", value: "\(todaySessions)", label: "sessions")
                Spacer()
            }
        }
        .padding(18)
        .quillCard()
    }

    private func todayStat(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Theme.textTertiary)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Theme.textTertiary)
        }
    }

    // MARK: - Time Saved (Phase 7 Tier 3)

    private var timeSavedCard: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("TIME SAVED")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.textTertiary)
                Text(
                    DictationStats.formatMinutes(
                        DictationStats.timeSavedMinutes(
                            words: stats.totalWords, dictationSeconds: stats.totalDictationSeconds, assumedWPM: assumedWPM
                        )
                    )
                )
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text("All time, vs. typing it out yourself.")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("Based on your typing speed")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
                Stepper(value: $assumedWPM, in: 10...200, step: 5) {
                    Text("\(assumedWPM) WPM")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                }
                .onChange(of: assumedWPM) { _, new in
                    QuillSettings.assumedTypingWPM = new
                }
                .fixedSize()
            }
        }
        .padding(18)
        .quillCard()
    }

    // MARK: - Quick insights grid (Phase 7 Tier 2)

    private var quickInsightsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("INSIGHTS", systemImage: "lightbulb.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Theme.textTertiary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                insightTile(icon: "square.grid.2x2", label: "Top Apps", value: topAppsSummary)
                insightTile(icon: "sparkles", label: "AI Enhanced", value: hasAIEnhancement ? "\(aiEnhancedPercent)%" : "--")
                insightTile(icon: "clock", label: "Peak Time", value: peakTimeLabel)
                insightTile(icon: "text.alignleft", label: "Avg Length", value: "\(stats.avgWords) words")
            }
        }
    }

    private func insightTile(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.textTertiary)
            }
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .quillCard()
    }

    // MARK: - Reset (Phase 7 Tier 4)

    /// Same underlying `DictationHistory.clear()` Data & Privacy's "Clear
    /// history" already calls — every stat on this page is a pure
    /// function of that history, so clearing it already resets
    /// everything. This is just the same action, reachable at the bottom
    /// of Insights itself instead of a trip to Settings, matching where
    /// it's expected to be.
    private var resetAllStatsLink: some View {
        HStack {
            Spacer()
            Button(role: .destructive) {
                confirmingResetAll = true
            } label: {
                Label("Reset All Stats", systemImage: "trash")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundColor(Theme.textTertiary)
            Spacer()
        }
        .confirmationDialog(
            "Delete all dictation history? This resets every stat on this page and can't be undone.",
            isPresented: $confirmingResetAll,
            titleVisibility: .visible
        ) {
            Button("Reset All Stats", role: .destructive) {
                DictationHistory.clear()
            }
            Button("Cancel", role: .cancel) {}
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
    /// any provider has a key connected (matches the card's own copy,
    /// which talks about connecting a key, not about which Auto Cleanup
    /// level is on), and shows the real count once unlocked. Checks all
    /// `StyleProvider` cases rather than naming openAI/anthropic
    /// individually — that hardcoded pair is exactly what silently
    /// stopped counting Google/OpenRouter fixes once those providers
    /// were added (same bug class as the `StyleView.hasKey` ternary
    /// fixed earlier).
    private var hasStyleKey: Bool {
        StyleProvider.allCases.contains { APIKeyStore.hasKey(for: $0) }
    }

    private var fixesLockedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: hasAIEnhancement ? "checkmark.circle.fill" : "lock.fill")
                    .font(.system(size: 10))
                    .foregroundColor(hasAIEnhancement ? Theme.accent : Theme.textTertiary)
                Text("FIXES MADE BY QUILL")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.textTertiary)
            }
            Text(hasAIEnhancement ? "\(stats.fixesCount)" : "--")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(hasAIEnhancement ? Theme.textPrimary : Theme.textTertiary)
            Spacer(minLength: 0)
            Text(
                hasAIEnhancement
                    ? "Dictations cleaned up by Enhancement Engine."
                    : "Turn on Local AI (no key needed) or connect an OpenAI/Anthropic key in Style to enable AI fixes."
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

    // MARK: - Personal records (Phase 7 Tier 1)

    private var personalRecordsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Personal records")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                recordTile(value: "\(stats.transcriptionsCount)", label: "TRANSCRIPTIONS")
                recordTile(value: "\(stats.avgWords)", label: "AVG WORDS EACH")
                recordTile(value: "\(stats.longestTranscriptionWords)", label: "LONGEST TRANSCRIPTION")
                recordTile(value: "\(stats.mostWordsInADay)", label: "MOST WORDS IN A DAY")
                recordTile(value: "\(stats.mostTranscriptionsInADay)", label: "MOST IN A DAY")
            }
        }
        .padding(18)
        .quillCard()
    }

    private func recordTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            Text(label)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundColor(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.textQuaternary)
        .cornerRadius(8)
    }

    // MARK: - Milestones (Phase 7 Tier 1)

    private var wordMilestones: [(label: String, value: Int)] {
        [
            ("1K", 1_000), ("10K", 10_000), ("50K", 50_000), ("100K", 100_000), ("200K", 200_000),
            ("300K", 300_000), ("400K", 400_000), ("500K", 500_000), ("1M", 1_000_000),
        ]
    }

    private var transcriptionMilestones: [(label: String, value: Int)] {
        [("50", 50), ("100", 100), ("500", 500), ("1K", 1_000), ("5K", 5_000), ("10K", 10_000)]
    }

    private var streakMilestones: [(label: String, value: Int)] {
        [
            ("7d", 7), ("15d", 15), ("30d", 30), ("60d", 60), ("90d", 90),
            ("120d", 120), ("180d", 180), ("1y", 365),
        ]
    }

    private var milestonesReached: Int {
        wordMilestones.filter { stats.totalWords >= $0.value }.count
            + transcriptionMilestones.filter { stats.transcriptionsCount >= $0.value }.count
            + streakMilestones.filter { stats.bestStreak >= $0.value }.count
    }

    private var milestonesTotal: Int {
        wordMilestones.count + transcriptionMilestones.count + streakMilestones.count
    }

    private var milestonesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Milestones")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text("\(milestonesReached)/\(milestonesTotal)")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
            }
            milestoneRow(title: "Words", items: wordMilestones, current: stats.totalWords)
            milestoneRow(title: "Transcriptions", items: transcriptionMilestones, current: stats.transcriptionsCount)
            // Best streak ever, not the currently-active one — breaking a
            // streak shouldn't take an already-earned milestone back.
            milestoneRow(title: "Streak", items: streakMilestones, current: stats.bestStreak)
        }
        .padding(18)
        .quillCard()
    }

    private func milestoneRow(title: String, items: [(label: String, value: Int)], current: Int) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 92, alignment: .leading)
                .padding(.top, 5)
            HStack(spacing: 8) {
                ForEach(items, id: \.label) { item in
                    let reached = current >= item.value
                    VStack(spacing: 4) {
                        Circle()
                            .strokeBorder(reached ? Theme.accent : Theme.fillHover, lineWidth: 1.5)
                            .background(Circle().fill(reached ? Theme.accent.opacity(0.15) : Color.clear))
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(Theme.accent)
                                    .opacity(reached ? 1 : 0)
                            )
                            .frame(width: 20, height: 20)
                        Text(item.label)
                            .font(.system(size: 9))
                            .foregroundColor(reached ? Theme.textSecondary : Theme.textTertiary)
                    }
                }
            }
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

import AppKit
import SwiftUI

struct DictationView: View {
    @State private var entries: [DictationEntry] = DictationHistory.loadAll()

    private var grouped: [(day: Date, entries: [DictationEntry])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: entries) { cal.startOfDay(for: $0.timestamp) }
        return groups.keys.sorted(by: >).map { ($0, groups[$0]!.sorted { $0.timestamp > $1.timestamp }) }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Dictation")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .padding(.horizontal, Theme.pagePadding)
                    .padding(.top, Theme.pagePadding)
                    .padding(.bottom, 16)

                if entries.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            ForEach(grouped, id: \.day) { group in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(label(for: group.day))
                                        .font(.system(size: 11, weight: .semibold))
                                        .tracking(0.4)
                                        .foregroundColor(Theme.textTertiary)
                                        .padding(.horizontal, 4)

                                    VStack(spacing: 0) {
                                        ForEach(Array(group.entries.enumerated()), id: \.element.id) { index, entry in
                                            DictationRow(entry: entry, onDelete: { delete(entry) })
                                            if index < group.entries.count - 1 {
                                                Divider().opacity(0.08).padding(.leading, 20)
                                            }
                                        }
                                    }
                                    .quillCard()
                                }
                            }
                        }
                        .padding(.horizontal, Theme.pagePadding)
                        .padding(.bottom, 20)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            Divider().opacity(0.08)

            StatsSidebar(stats: DictationStats(entries: entries))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: .quillHistoryUpdated)) { _ in
            entries = DictationHistory.loadAll()
        }
    }

    private func delete(_ entry: DictationEntry) {
        DictationHistory.delete(entry)
    }

    private func label(for day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "TODAY" }
        if cal.isDateInYesterday(day) { return "YESTERDAY" }
        let f = DateFormatter()
        f.dateFormat = "MMMM d, yyyy"
        return f.string(from: day).uppercased()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic")
                .font(.system(size: 28))
                .foregroundColor(Theme.accent)
            Text("No dictations yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
            Text("Hold Fn and speak anywhere — what you dictate shows up here, read straight from a file on this Mac, never uploaded.")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Persistent at-a-glance stats, always visible next to the list — same
/// idea as Wispr's right-hand panel, kept to plain local numbers (no
/// AI-generated "Voice Profile" card).
private struct StatsSidebar: View {
    let stats: DictationStats

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("At a glance")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
                .padding(.top, Theme.pagePadding)

            statRow(value: "\(stats.totalWords)", label: "total words")
            statRow(value: "\(stats.wordsPerMinute)", label: "words / min")
            statRow(value: "\(stats.streak)", label: stats.streak == 1 ? "day streak" : "day streak")

            Spacer()

            Label("Local only, never uploaded", systemImage: "lock.shield")
                .font(.system(size: 10))
                .foregroundColor(Theme.textTertiary)
                .padding(.bottom, 16)
        }
        .padding(.horizontal, 18)
        .frame(width: 190)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func statRow(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
        }
    }
}

/// One history row — text plus hover-reveal copy/delete actions, so a
/// dictation that failed to land in whatever app was focused (or just
/// needs to go somewhere else, or was junk) can still be grabbed or
/// cleared without opening Settings.
private struct DictationRow: View {
    let entry: DictationEntry
    let onDelete: () -> Void
    @State private var hovering = false
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(entry.timestamp, style: .time)
                .font(.system(size: 12))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 64, alignment: .leading)
                .padding(.top, 1)

            Text(entry.text)
                .font(.system(size: 13))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                Button(action: copy) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(copied ? Theme.accent : Theme.textSecondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help(copied ? "Copied" : "Copy")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Delete")
            }
            .opacity(hovering || copied ? 1 : 0)
            .animation(.easeOut(duration: 0.12), value: hovering)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .padding(.leading, 4)
        .contentShape(Rectangle())
        .background(hovering ? Theme.textQuaternary : Color.clear)
        .onHover { hovering = $0 }
    }

    private func copy() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(entry.text, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
    }
}

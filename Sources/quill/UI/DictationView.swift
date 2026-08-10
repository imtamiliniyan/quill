import SwiftUI

struct DictationView: View {
    @State private var entries: [DictationEntry] = DictationHistory.loadAll()

    private var grouped: [(day: Date, entries: [DictationEntry])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: entries) { cal.startOfDay(for: $0.timestamp) }
        return groups.keys.sorted(by: >).map { ($0, groups[$0]!.sorted { $0.timestamp > $1.timestamp }) }
    }

    var body: some View {
        Group {
            if entries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(grouped, id: \.day) { group in
                            VStack(alignment: .leading, spacing: 0) {
                                Text(label(for: group.day))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.4))
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 6)

                                VStack(spacing: 0) {
                                    ForEach(Array(group.entries.enumerated()), id: \.element.id) { index, entry in
                                        row(entry)
                                        if index < group.entries.count - 1 {
                                            Divider().opacity(0.08).padding(.leading, 20)
                                        }
                                    }
                                }
                                .background(Color.white.opacity(0.03))
                                .cornerRadius(10)
                                .padding(.horizontal, 12)
                            }
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: .quillHistoryUpdated)) { _ in
            entries = DictationHistory.loadAll()
        }
    }

    private func row(_ entry: DictationEntry) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(entry.timestamp, style: .time)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 64, alignment: .leading)
            Text(entry.text)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
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
                .foregroundColor(.white)
            Text("Hold Fn and speak anywhere — what you dictate shows up here, read straight from a file on this Mac, never uploaded.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .padding(32)
    }
}

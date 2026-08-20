import SwiftUI

/// A real sidebar tab (peer to Dictation/Insights/Style/Voice Engine/
/// Enhancement Engine/Getting Started) showing what's shipped, dated —
/// FluidVoice's own "Change logs" tab made the same case well: a visible
/// track record builds trust in an app that's still actively developed
/// (layout reference only, no code borrowed, no FluidVoice branding —
/// same standing rule as everywhere else this app takes UI inspiration
/// from them). Content lives in `ChangeLog.swift`, hand-maintained real
/// dates — see that file's doc comment for why there's no fabricated
/// version-number scheme.
struct ChangeLogView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 17))
                    .foregroundColor(Theme.accent)
                Text("Change Log")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, Theme.pagePadding)
            .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(ChangeLog.entries.enumerated()), id: \.element.id) { index, entry in
                        entryCard(entry, isLatest: index == 0)
                    }
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func entryCard(_ entry: ChangeLogEntry, isLatest: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(entry.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                if isLatest {
                    Text("LATEST")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Theme.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Theme.accent.opacity(0.15))
                        .clipShape(Capsule())
                }
                Spacer()
                Text(entry.date)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
            }

            VStack(alignment: .leading, spacing: 7) {
                ForEach(entry.changes, id: \.self) { change in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 4, height: 4)
                            .padding(.top, 6)
                        Text(change)
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .quillCard()
    }
}

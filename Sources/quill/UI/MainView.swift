import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case dictation = "Dictation"
    case insights = "Insights"
    case style = "Style"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dictation: return "mic"
        case .insights: return "chart.bar"
        case .style: return "wand.and.stars"
        }
    }
}

/// Drives which sidebar tab is showing and whether the Settings sheet is up.
/// Lives for the lifetime of the main window (MainWindow owns one instance).
@MainActor
final class AppViewState: ObservableObject {
    @Published var selection: SidebarItem? = .dictation
    @Published var showSettings = false
}

struct MainView: View {
    @ObservedObject var state: AppViewState

    var body: some View {
        // A plain HStack, not NavigationSplitView — NavigationSplitView
        // auto-adds a sidebar show/hide toggle that turned out to be part
        // of the view itself, not a real NSToolbarItem, so
        // `.toolbar(removing: .sidebarToggle)` had nothing to act on in
        // this AppKit-hosted NSWindow (no SwiftUI Scene/toolbar behind it).
        // A plain HStack has no such built-in chrome to fight — the
        // sidebar here is never meant to collapse anyway.
        HStack(spacing: 0) {
            sidebar
            Divider().opacity(0.08)
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background)
        }
        .sheet(isPresented: $state.showSettings) {
            SettingsView()
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(SidebarItem.allCases) { item in
                    sidebarRow(item)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 12)

            Spacer()

            Divider().opacity(0.2)

            Label("Stored locally, not in the cloud", systemImage: "lock.shield")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.45))
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                state.showSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(12)
        }
        .frame(width: 190)
        .background(Theme.background)
    }

    private func sidebarRow(_ item: SidebarItem) -> some View {
        let selected = state.selection == item
        return Button {
            state.selection = item
        } label: {
            Label(item.rawValue, systemImage: item.icon)
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                .foregroundColor(selected ? .white : .white.opacity(0.75))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(selected ? Color.white.opacity(0.08) : Color.clear)
        .cornerRadius(6)
    }

    @ViewBuilder
    private var detail: some View {
        switch state.selection {
        case .dictation: DictationView()
        case .insights: InsightsView()
        case .style: StyleComingSoonView()
        case nil: EmptyView()
        }
    }
}

// MARK: - Placeholders (Phase 4 fills this in)

private struct StyleComingSoonView: View {
    var body: some View {
        ComingSoonView(
            icon: "wand.and.stars",
            title: "Style rewriting",
            body: "Bring your own OpenAI or Anthropic API key to rewrite dictated text (formal, casual, cleanup). Off by default — text is only sent to the provider you pick, using your own key, when you ask for a rewrite."
        )
    }
}

private struct ComingSoonView: View {
    let icon: String
    let title: String
    let body_: String

    init(icon: String, title: String, body: String) {
        self.icon = icon
        self.title = title
        self.body_ = body
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(Theme.accent)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            Text(body_)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Text("Coming soon")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .padding(.top, 4)
        }
        .padding(32)
    }
}

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
        NavigationSplitView {
            sidebar
        } detail: {
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
            List(SidebarItem.allCases, selection: $state.selection) { item in
                Label(item.rawValue, systemImage: item.icon).tag(item)
            }
            .listStyle(.sidebar)

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
        .background(Theme.background)
    }

    @ViewBuilder
    private var detail: some View {
        switch state.selection {
        case .dictation: DictationComingSoonView()
        case .insights: InsightsComingSoonView()
        case .style: StyleComingSoonView()
        case nil: EmptyView()
        }
    }
}

// MARK: - Placeholders (Phase 3 / Phase 4 fill these in)

private struct DictationComingSoonView: View {
    var body: some View {
        ComingSoonView(
            icon: "mic",
            title: "Dictation history",
            body: "Every dictation you make will show up here, grouped by day — read straight from a file on this Mac, never uploaded anywhere."
        )
    }
}

private struct InsightsComingSoonView: View {
    var body: some View {
        ComingSoonView(
            icon: "chart.bar",
            title: "Insights",
            body: "Word counts, speaking speed, and streaks — all computed locally from your own history file."
        )
    }
}

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

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
                .foregroundColor(Theme.textTertiary)
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
                .foregroundColor(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(selected ? Theme.fillHover : Color.clear)
        .cornerRadius(6)
    }

    @ViewBuilder
    private var detail: some View {
        switch state.selection {
        case .dictation: DictationView()
        case .insights: InsightsView()
        case .style: StyleView()
        case nil: EmptyView()
        }
    }
}

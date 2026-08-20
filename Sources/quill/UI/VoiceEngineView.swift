import SwiftUI

/// A real sidebar tab (peer to Dictation/Insights/Style/Getting Started),
/// not tucked inside Settings — matches how FluidVoice keeps its own model
/// picker in a dedicated "Voice Engine" section rather than buried in
/// general settings (UI/layout reference only, no code or branding
/// borrowed). Was `ModelsSettingsView` inside `SettingsView.swift`'s
/// General tab; moved out wholesale once there was a natural home for it —
/// same `MenuBarController.selectModel` entry point, same behavior.
struct VoiceEngineView: View {
    let menuBar: MenuBarController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Voice Engine")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, Theme.pagePadding)
                .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ModelsSettingsView(menuBar: menuBar)
                        .padding(18)
                        .quillCard()
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// Radio-button model picker plus a per-model delete (trash icon), so
/// switching or freeing up disk space never requires the terminal —
/// mirrors exactly what the menu bar's "Switch Model" submenu already does,
/// through the same `MenuBarController.selectModel` entry point.
private struct ModelsSettingsView: View {
    let menuBar: MenuBarController
    @State private var currentModelID: String
    @State private var confirmingDelete: TranscriptionModel?
    @State private var deleteError: String?

    init(menuBar: MenuBarController) {
        self.menuBar = menuBar
        _currentModelID = State(initialValue: menuBar.modelID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Models").font(.system(size: 13, weight: .semibold))
            Text("Choose which model transcribes your dictation. Downloaded models can be removed here to free up space.")
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)

            VStack(spacing: 8) {
                ForEach(ModelRegistry.shared, id: \.id) { model in
                    modelRow(model)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .quillModelChanged)) { _ in
            currentModelID = menuBar.modelID
        }
        .confirmationDialog(
            "Delete \(confirmingDelete?.displayName ?? "")? You'll need to download it again to use it.",
            isPresented: Binding(
                get: { confirmingDelete != nil },
                set: { if !$0 { confirmingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Model", role: .destructive) {
                if let model = confirmingDelete { delete(model) }
                confirmingDelete = nil
            }
            Button("Cancel", role: .cancel) { confirmingDelete = nil }
        }
        .alert(
            "Couldn't delete model",
            isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )
        ) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    private func modelRow(_ model: TranscriptionModel) -> some View {
        let selected = model.id == currentModelID
        let downloaded = ModelAvailability.isDownloaded(model)
        return HStack(spacing: 10) {
            Button {
                guard !selected else { return }
                menuBar.selectModel(model)
                currentModelID = menuBar.modelID
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                        .foregroundColor(selected ? Theme.accent : Theme.textTertiary)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(model.displayName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Theme.textPrimary)
                            if model.recommended {
                                Text("RECOMMENDED")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(Theme.accent)
                            }
                        }
                        HStack(spacing: 8) {
                            DotRating(label: "Speed", value: model.speed)
                            DotRating(label: "Accuracy", value: model.accuracy)
                        }
                        Text(downloaded ? "\(model.sizeMB) MB · downloaded" : "\(model.sizeMB) MB · not downloaded")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textTertiary)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if downloaded && !selected {
                Button {
                    confirmingDelete = model
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Delete downloaded model")
            }
        }
        .padding(10)
        .background(selected ? Theme.fillHover : Theme.textQuaternary)
        .cornerRadius(8)
    }

    private func delete(_ model: TranscriptionModel) {
        do {
            try ModelAvailability.deleteFiles(for: model)
        } catch {
            deleteError = error.localizedDescription
        }
    }
}

/// A 1–5 dot rating (Phase 5a) — deliberately not a percentage. There's no
/// real benchmark behind `model.speed`/`model.accuracy`, just each
/// architecture's documented general characteristics, and a precise-looking
/// "96%" would claim more certainty than that's worth. Dots read as
/// "roughly how this compares to the others," which is what they are.
private struct DotRating: View {
    let label: String
    let value: Int

    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(Theme.textTertiary)
            HStack(spacing: 1.5) {
                ForEach(1...5, id: \.self) { i in
                    Circle()
                        .fill(i <= value ? Theme.accent : Theme.fillHover)
                        .frame(width: 4, height: 4)
                }
            }
        }
    }
}

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
                    CustomVocabularySettingsView()
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

/// Proper nouns/technical terms the selected ASR model tends to mis-hear
/// ("Llama" → "Lama", "Qwen" → "when") — corrected after transcription by
/// `TranscriptSanitizer.correctVocabulary`, since neither Parakeet nor
/// WhisperKit exposes real vocabulary boosting (Parakeet's a transducer
/// model; that trick only works for prompt-conditioned ones like
/// Whisper). Same chip-list editor pattern as Style's Remove Filler
/// Words — list itself writes straight through to `QuillSettings`, no
/// separate "apply" step, and no master toggle: an empty list already is
/// "off."
private struct CustomVocabularySettingsView: View {
    @State private var replacements = QuillSettings.vocabularyReplacements
    @State private var heardText = ""
    @State private var replacementText = ""
    /// Non-nil while editing an existing rule instead of creating a new
    /// one — the form doubles as both, same field pair either way, only
    /// the submit button's action and label change. Without this, every
    /// newly-seen mis-hearing had to become its own separate rule (real
    /// user report: three different rows all mapping to "Claude") since
    /// there was no way to add one more variant to an existing rule.
    @State private var editingID: UUID?

    private var isEditing: Bool { editingID != nil }

    private var canSubmit: Bool {
        !heardText.trimmingCharacters(in: .whitespaces).isEmpty
            && !replacementText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Custom Vocabulary")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
            Text("Names and terms that get mis-transcribed — list what Quill actually hears, and what it should type instead.")
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("When Quill hears")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                TextField("e.g. cloud, clod, clown", text: $heardText)
                    .textFieldStyle(.roundedBorder)
                Text("Separate multiple mis-hearings with commas.")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Change it to")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                TextField("e.g. Claude", text: $replacementText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(submit)
            }

            HStack(spacing: 8) {
                Button(isEditing ? "Save Changes" : "Add Replacement", action: submit)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(!canSubmit)
                if isEditing {
                    Button("Cancel", action: cancelEditing)
                        .buttonStyle(.bordered)
                }
            }

            if !replacements.isEmpty {
                Divider().opacity(0.1)
                HStack(spacing: 4) {
                    Text("Your Dictionary")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Text("(\(replacements.count))")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                }
                Text("Quill corrects these automatically, every dictation.")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
                VStack(spacing: 8) {
                    ForEach(replacements) { rule in
                        replacementRow(rule)
                    }
                }
            }
        }
        .padding(18)
        .quillCard()
    }

    private func replacementRow(_ rule: QuillSettings.VocabularyReplacement) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(rule.heard.joined(separator: ", "))
                    .font(.system(size: 10.5))
                    .strikethrough()
                    .foregroundColor(Theme.textTertiary)
                Text(rule.replacement)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
            }
            Spacer()
            Button {
                startEditing(rule)
            } label: {
                Label("Modify", systemImage: "slider.horizontal.3")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.fillHover)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Theme.textTertiary.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            Button {
                delete(rule)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(editingID == rule.id ? Theme.accent.opacity(0.1) : Theme.textQuaternary)
        .cornerRadius(8)
    }

    private func startEditing(_ rule: QuillSettings.VocabularyReplacement) {
        editingID = rule.id
        heardText = rule.heard.joined(separator: ", ")
        replacementText = rule.replacement
    }

    private func cancelEditing() {
        editingID = nil
        heardText = ""
        replacementText = ""
    }

    private func delete(_ rule: QuillSettings.VocabularyReplacement) {
        replacements.removeAll { $0.id == rule.id }
        QuillSettings.vocabularyReplacements = replacements
        if editingID == rule.id { cancelEditing() }
    }

    private func submit() {
        let heard = heardText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let replacement = replacementText.trimmingCharacters(in: .whitespaces)
        guard !heard.isEmpty, !replacement.isEmpty else { return }

        if let id = editingID, let idx = replacements.firstIndex(where: { $0.id == id }) {
            replacements[idx].heard = heard
            replacements[idx].replacement = replacement
        } else {
            replacements.append(QuillSettings.VocabularyReplacement(id: UUID(), heard: heard, replacement: replacement))
        }
        QuillSettings.vocabularyReplacements = replacements
        cancelEditing()
    }
}

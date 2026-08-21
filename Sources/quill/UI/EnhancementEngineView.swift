import AppKit
import SwiftUI

/// A real sidebar tab (peer to Dictation/Insights/Style/Voice
/// Engine/Getting Started) listing the external AI providers Style's
/// Medium tier can use. Replaces the single combined
/// picker+key-field card that used to live in `StyleView.swift`'s
/// `apiKeyCard`, with FluidVoice's per-provider expandable-row layout
/// instead (layout reference only, no code borrowed). Each row shows that
/// provider's own official logo (`ProviderLogos.swift`, bundled PNGs) —
/// unlike everywhere else this project takes FluidVoice's UI as
/// inspiration, real provider marks are the correct, standard way to
/// identify a BYOK integration; nothing here is FluidVoice's own
/// branding.
///
/// No per-provider model picker for OpenAI/Anthropic/Google — each has
/// one fixed default (`StyleRewriter.modelName`), by original design:
/// this tab was scoped to "connect a key," nothing more. OpenRouter is
/// the one explicit exception, added afterward: it fronts hundreds of
/// models through a single key, so a fixed default doesn't fit the same
/// way — see `openRouterModelPicker` below.
///
/// Only one provider is ever "active" — the one `StyleRewriter` actually
/// calls for Rewrite/Medium, tracked as `QuillSettings.styleProvider`.
/// Saving a key makes that provider active automatically (the natural
/// "the one I just connected is the one I want" reading), but with four
/// providers now instead of two, a user can easily end up with several
/// keys saved at once — the active/inactive distinction stopped being
/// implicit the moment that became possible, so every row makes it
/// explicit: an "Active" badge on the one in use, and a "Use for
/// Rewrite" button on any other connected-but-inactive row to switch.
struct EnhancementEngineView: View {
    @State private var expanded: StyleProvider?
    @State private var apiKeyField: String = ""
    @State private var connected: [StyleProvider: Bool] = Dictionary(
        uniqueKeysWithValues: StyleProvider.allCases.map { ($0, APIKeyStore.hasKey(for: $0)) }
    )
    @State private var activeProvider: StyleProvider = QuillSettings.styleProvider

    // Local AI (Phase 4a/5e, model picker added later) — moved here from
    // Style so every AI backend Style can use (on-device or BYOK cloud) is
    // managed from one place, Local AI first since it needs no key.
    // Style's Auto Cleanup card still owns *selecting* it as the active
    // auto-cleanup tier (same split as Medium: the key/model lives here,
    // which tier runs stays a Style choice) — this state is this view's
    // own copy of that same download/selection status, not a duplicate
    // source of truth.
    //
    // Per-model rather than singular now that `LocalLLMModel.all` has more
    // than one entry: each dictionary is keyed by `LocalLLMModel.id`, and
    // `localAIModelID` tracks which one is the currently *selected* model
    // (persisted separately as `QuillSettings.localAIModelID` — download
    // state and selection are different questions, same as Voice Engine's
    // transcription models).
    @State private var localAIExpanded = false
    @State private var localAIModelID = QuillSettings.localAIModelID
    @State private var localAIDownloaded: [String: Bool] = Dictionary(
        uniqueKeysWithValues: LocalLLMModel.all.map { ($0.id, LocalEnhancer.isDownloaded(modelID: $0.id)) }
    )
    @State private var localAIDownloadProgress: [String: Double] = [:]
    @State private var localAIDownloadError: String?
    @State private var confirmingLocalAIDownload: LocalLLMModel?
    @State private var confirmingLocalAIDelete: LocalLLMModel?
    @State private var autoCleanupLevel: AutoCleanupLevel = QuillSettings.autoCleanupLevel

    // OpenRouter's model picker (fronts hundreds of models through one
    // key, unlike the other three providers' single fixed default) —
    // list is fetched lazily, only once OpenRouter's card is actually
    // opened, not on every visit to this tab.
    @State private var openRouterModel: String = QuillSettings.openRouterModel
    @State private var openRouterModels: [OpenRouterModelInfo] = []
    @State private var openRouterModelsLoading = false
    @State private var openRouterModelsError: String?
    @State private var modelPickerOpen = false
    @State private var modelSearch = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Enhancement Engine")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, Theme.pagePadding)
                .padding(.bottom, 4)
            Text("Local AI runs fully on this Mac, no key needed. Or connect your own OpenAI, Anthropic, Google, or OpenRouter key: either powers Style's Medium tier and Auto Cleanup.")
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 10) {
                    localAICard

                    ForEach(StyleProvider.allCases) { provider in
                        providerCard(provider)
                    }
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Local AI

    /// True only for the model that's both downloaded and the one Auto
    /// Cleanup is actually configured to use — matches how the cloud
    /// provider rows define "Active" (connected *and* the selected
    /// provider), just with an extra "selected among local models" axis.
    private func isLocalModelActive(_ model: LocalLLMModel) -> Bool {
        autoCleanupLevel == .localAI
            && localAIModelID == model.id
            && (localAIDownloaded[model.id] ?? false)
    }

    private var anyLocalModelActive: Bool {
        LocalLLMModel.all.contains { isLocalModelActive($0) }
    }

    private var localAICard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    localAIExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    localAIIcon
                    Text("Local AI")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                    if anyLocalModelActive {
                        Label("Active", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.accent)
                    } else {
                        Text("\(LocalLLMModel.all.filter { localAIDownloaded[$0.id] ?? false }.count) of \(LocalLLMModel.all.count) downloaded")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textTertiary)
                    }
                    Spacer()
                    Image(systemName: localAIExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.textTertiary)
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if localAIExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider().opacity(0.15)

                    HStack(spacing: 6) {
                        Image(systemName: "cpu")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textTertiary)
                        Text("Small on-device models for full tone rewrites: no key, no cloud, nothing leaves this Mac. Pick one below — one-time download per model, then it runs offline.")
                            .font(.system(size: 10.5))
                            .foregroundColor(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let localAIDownloadError {
                        Text(localAIDownloadError)
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                    }

                    VStack(spacing: 8) {
                        ForEach(LocalLLMModel.all) { model in
                            localAIModelRow(model)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .quillCard()
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(anyLocalModelActive ? Theme.accent.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
        .confirmationDialog(
            "Download \(confirmingLocalAIDownload?.displayName ?? "this model")?",
            isPresented: Binding(
                get: { confirmingLocalAIDownload != nil },
                set: { if !$0 { confirmingLocalAIDownload = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let model = confirmingLocalAIDownload {
                Button("Download (\(model.sizeLabel))") { beginLocalAIDownload(model) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Downloaded once, then runs entirely on this Mac. No key, no cloud, no per-dictation network call.")
        }
        .confirmationDialog(
            "Delete \(confirmingLocalAIDelete?.displayName ?? "this model")?",
            isPresented: Binding(
                get: { confirmingLocalAIDelete != nil },
                set: { if !$0 { confirmingLocalAIDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let model = confirmingLocalAIDelete {
                Button("Delete", role: .destructive) { deleteLocalAI(model) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Frees \(confirmingLocalAIDelete?.sizeLabel ?? "disk space"). Auto Cleanup resets to None if this was the active model.")
        }
    }

    private func localAIModelRow(_ model: LocalLLMModel) -> some View {
        let isDownloaded = localAIDownloaded[model.id] ?? false
        let isSelected = localAIModelID == model.id
        let isActive = isLocalModelActive(model)
        let progress = localAIDownloadProgress[model.id]

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "shippingbox")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
                Text(model.displayName)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                Text(model.sizeLabel)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
                Spacer()
                if isActive {
                    Label("Active", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.accent)
                } else if isDownloaded {
                    Text("Downloaded")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                }
            }

            if let progress {
                HStack(spacing: 8) {
                    ProgressView(value: progress)
                        .tint(Theme.accent)
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                }
            }

            HStack(spacing: 8) {
                if isDownloaded && !isActive {
                    Button {
                        localAIModelID = model.id
                        QuillSettings.localAIModelID = model.id
                        QuillSettings.autoCleanupLevel = .localAI
                        autoCleanupLevel = .localAI
                    } label: {
                        Label("Use for Auto Cleanup", systemImage: "checkmark.circle")
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Spacer()

                if isDownloaded {
                    Button("Delete", role: .destructive) {
                        confirmingLocalAIDelete = model
                    }
                    .controlSize(.small)
                } else if progress == nil {
                    Button("Download") {
                        confirmingLocalAIDownload = model
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .controlSize(.small)
                }
            }
        }
        .padding(10)
        .background(isSelected ? Theme.accent.opacity(0.06) : Theme.textQuaternary)
        .cornerRadius(8)
    }

    private var localAIIcon: some View {
        ZStack {
            Circle()
                .fill(Theme.accent.opacity(0.15))
                .frame(width: 28, height: 28)
            Image(systemName: "cpu")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.accent)
        }
    }

    private func beginLocalAIDownload(_ model: LocalLLMModel) {
        localAIDownloadProgress[model.id] = 0
        localAIDownloadError = nil
        // Also mirrored into the global DownloadActivity bar (Phase 5a):
        // this view's own @State resets if the sidebar switches away from
        // Enhancement Engine and back mid-download, even though
        // LocalEnhancer's actual download — an actor-owned Task, not tied
        // to this view — keeps running the whole time regardless.
        DownloadActivity.shared.begin(label: "Downloading \(model.displayName)")
        Task {
            do {
                try await LocalEnhancer.shared.download(modelID: model.id) { fraction in
                    Task { @MainActor in
                        localAIDownloadProgress[model.id] = fraction
                        DownloadActivity.shared.update(progress: fraction)
                    }
                }
                localAIDownloaded[model.id] = true
                localAIDownloadProgress[model.id] = nil
                localAIModelID = model.id
                QuillSettings.localAIModelID = model.id
                autoCleanupLevel = .localAI
                QuillSettings.autoCleanupLevel = .localAI
                DownloadActivity.shared.finish()
            } catch {
                localAIDownloadError = "\(error)"
                localAIDownloadProgress[model.id] = nil
                DownloadActivity.shared.finish()
            }
        }
    }

    private func deleteLocalAI(_ model: LocalLLMModel) {
        do {
            try LocalEnhancer.deleteFiles(modelID: model.id)
            Task { await LocalEnhancer.shared.unload(modelID: model.id) }
            localAIDownloaded[model.id] = false
            // Leaving the level selected would silently fall back to
            // basic filler cleanup on every dictation with no indication
            // why — reset to None instead, same as picking a fresh
            // default, but only if the model just deleted was actually
            // the active one.
            if autoCleanupLevel == .localAI && localAIModelID == model.id {
                autoCleanupLevel = .none
                QuillSettings.autoCleanupLevel = .none
            }
        } catch {
            localAIDownloadError = "\(error)"
        }
    }

    private func providerCard(_ provider: StyleProvider) -> some View {
        let isExpanded = expanded == provider
        let isConnected = connected[provider] ?? false
        // "Selected for Rewrite/Medium" — true independent of Auto
        // Cleanup's level, since this provider still drives the manual
        // Style "Rewrite" action either way.
        let isActive = isConnected && provider == activeProvider
        // Whether that selection is *also* what Auto Cleanup runs through
        // right now. When Auto Cleanup is set to Local AI instead, this is
        // false even while `isActive` is true — the badge used to just
        // say "Active" either way, which is exactly what looked like "both
        // active at once" (real user report). Not a functional bug —
        // `AutoCleanupLevel` is a single value, only one ever actually
        // drives Auto Cleanup — just the same word doing two jobs.
        let drivesAutoCleanup = isActive && autoCleanupLevel == .medium

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if isExpanded {
                        expanded = nil
                    } else {
                        expanded = provider
                        apiKeyField = ""
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    providerIcon(provider)
                    Text(provider.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                    if drivesAutoCleanup {
                        Label("Active", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.accent)
                    } else if isActive {
                        Label("Used for Rewrite", systemImage: "checkmark.circle")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                    } else if isConnected {
                        Text("Key saved")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textTertiary)
                    } else {
                        Text("No key set")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textTertiary)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.textTertiary)
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider().opacity(0.15)

                    if provider == .openRouter {
                        openRouterModelPicker
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "cpu")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textTertiary)
                            Text("Uses \(StyleRewriter.modelName(for: provider)): fixed, not user-selectable yet.")
                                .font(.system(size: 10.5))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }

                    SecureField(
                        isConnected ? "Key saved, paste a new one to replace it" : "Paste your \(provider.rawValue) API key",
                        text: $apiKeyField
                    )
                    .textFieldStyle(.roundedBorder)

                    if isConnected && !isActive {
                        Button {
                            QuillSettings.styleProvider = provider
                            activeProvider = provider
                        } label: {
                            Label("Use for Rewrite & Medium", systemImage: "checkmark.circle")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                    } else if drivesAutoCleanup {
                        Label("Currently used for Rewrite and Auto Cleanup Medium.", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(Theme.accent)
                    } else if isActive {
                        Label("Used for Rewrite. Auto Cleanup is set to Local AI instead — change that in Style to use \(provider.rawValue) there too.", systemImage: "checkmark.circle")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                    }

                    HStack(spacing: 8) {
                        Button("Get API Key") {
                            NSWorkspace.shared.open(keyPageURL(for: provider))
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        if isConnected {
                            Button("Remove", role: .destructive) {
                                APIKeyStore.clearKey(for: provider)
                                connected[provider] = false
                                apiKeyField = ""
                            }
                        }
                        Button("Cancel") {
                            expanded = nil
                            apiKeyField = ""
                        }
                        Button("Save") {
                            APIKeyStore.setKey(apiKeyField, for: provider)
                            QuillSettings.styleProvider = provider
                            activeProvider = provider
                            connected[provider] = APIKeyStore.hasKey(for: provider)
                            apiKeyField = ""
                            expanded = nil
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                        .disabled(apiKeyField.isEmpty)
                    }

                    Text("""
                    Stored in the macOS Keychain on this Mac only, never written to disk in plain \
                    text, never committed to a repo, never sent anywhere except directly to \
                    \(provider.rawValue) itself, and only at the moment you press Rewrite or Auto \
                    Cleanup runs Medium.
                    """)
                    .font(.system(size: 10.5))
                    .foregroundColor(Theme.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .quillCard()
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isActive ? Theme.accent.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
    }

    /// A searchable dropdown over OpenRouter's public model catalog —
    /// same interaction shape as FluidVoice's own picker (search field,
    /// scrollable checkmarked list, "N more — refine your search" when
    /// truncated), which is a genuinely useful pattern for browsing
    /// hundreds of entries and fine to reuse as an interaction shape —
    /// same "layout/interaction only" rule as everything else borrowed
    /// from FluidVoice this session, no code involved.
    private var openRouterModelPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Model")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundColor(Theme.textSecondary)

            Button {
                withAnimation(.easeInOut(duration: 0.12)) { modelPickerOpen.toggle() }
            } label: {
                HStack {
                    Text(openRouterModel)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    if openRouterModelsLoading {
                        ProgressView().controlSize(.small)
                    }
                    Image(systemName: modelPickerOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                }
                .padding(8)
                .background(Theme.textQuaternary)
                .cornerRadius(6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if modelPickerOpen {
                VStack(spacing: 0) {
                    TextField("Search models…", text: $modelSearch)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11.5))
                        .padding(8)
                    Divider().opacity(0.15)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(filteredOpenRouterModels.prefix(50)) { model in
                                Button {
                                    openRouterModel = model.id
                                    QuillSettings.openRouterModel = model.id
                                    modelPickerOpen = false
                                    modelSearch = ""
                                } label: {
                                    HStack {
                                        Text(model.id)
                                            .font(.system(size: 11.5))
                                            .foregroundColor(Theme.textPrimary)
                                        Spacer()
                                        if model.id == openRouterModel {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(Theme.accent)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                            if filteredOpenRouterModels.count > 50 {
                                Text("\(filteredOpenRouterModels.count - 50) more, refine your search")
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.textTertiary)
                                    .padding(8)
                            } else if filteredOpenRouterModels.isEmpty && !openRouterModelsLoading {
                                Text(openRouterModels.isEmpty ? "Loading…" : "No matches.")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(Theme.textTertiary)
                                    .padding(8)
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                }
                .background(Theme.textQuaternary)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.fillHover, lineWidth: 1))
            }

            if let openRouterModelsError {
                Text(openRouterModelsError)
                    .font(.system(size: 10))
                    .foregroundColor(.red)
            }
        }
        .onAppear(perform: loadOpenRouterModelsIfNeeded)
    }

    private var filteredOpenRouterModels: [OpenRouterModelInfo] {
        guard !modelSearch.isEmpty else { return openRouterModels }
        let query = modelSearch.lowercased()
        return openRouterModels.filter {
            $0.id.lowercased().contains(query) || ($0.name?.lowercased().contains(query) ?? false)
        }
    }

    private func loadOpenRouterModelsIfNeeded() {
        guard openRouterModels.isEmpty, !openRouterModelsLoading else { return }
        openRouterModelsLoading = true
        openRouterModelsError = nil
        Task {
            do {
                openRouterModels = try await OpenRouterModels.fetch()
            } catch {
                openRouterModelsError = "Couldn't load the model list. Still using \(openRouterModel)."
            }
            openRouterModelsLoading = false
        }
    }

    /// Each provider's own mark on a small white badge — OpenAI's and
    /// Anthropic's logos are solid black/dark ink, not designed with a
    /// dark-mode inversion, so a plain circle in Quill's own dark fill
    /// would make them nearly unreadable. A white badge (the common
    /// pattern for showing monochrome brand marks in a dark UI, e.g. how
    /// most editors render marketplace/integration icons) keeps every
    /// logo legible without modifying or recoloring any of them. Falls
    /// back to a plain initial-letter circle if the bundled image can't
    /// be found (e.g. a `swift run` outside the packaged .app, where
    /// `Bundle.module` resolves differently) — never a blank row.
    private func providerIcon(_ provider: StyleProvider) -> some View {
        ZStack {
            if let logo = ProviderLogos.image(for: provider) {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.white)
                    .frame(width: 28, height: 28)
                logo
                    .resizable()
                    .scaledToFit()
                    .frame(width: 17, height: 17)
            } else {
                Circle()
                    .fill(Theme.textQuaternary)
                    .frame(width: 28, height: 28)
                Text(String(provider.rawValue.prefix(1)))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }

    private func keyPageURL(for provider: StyleProvider) -> URL {
        switch provider {
        case .openAI: return URL(string: "https://platform.openai.com/api-keys")!
        case .anthropic: return URL(string: "https://console.anthropic.com/settings/keys")!
        case .google: return URL(string: "https://aistudio.google.com/app/apikey")!
        case .openRouter: return URL(string: "https://openrouter.ai/keys")!
        }
    }
}

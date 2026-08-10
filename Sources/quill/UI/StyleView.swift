import AppKit
import SwiftUI

struct StyleView: View {
    @State private var autoCleanupLevel: AutoCleanupLevel = QuillSettings.autoCleanupLevel
    @State private var autoCleanupTone: StyleTone = QuillSettings.autoCleanupTone

    @State private var provider: StyleProvider = QuillSettings.styleProvider
    @State private var apiKeyField: String = ""
    @State private var openAIConnected = APIKeyStore.hasKey(for: .openAI)
    @State private var anthropicConnected = APIKeyStore.hasKey(for: .anthropic)

    @State private var tone: StyleTone = .cleanUp
    @State private var inputText: String = ""
    @State private var outputText: String = ""
    @State private var isRewriting = false
    @State private var errorMessage: String?
    @State private var copied = false

    private var hasKey: Bool {
        provider == .openAI ? openAIConnected : anthropicConnected
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Style")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, Theme.pagePadding)
                .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    autoCleanupCard
                    apiKeyCard
                    rewriteCard
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Auto Cleanup

    /// The actual answer to "clean up my speech while I dictate" — applies
    /// automatically to every dictation, before it's typed, across every
    /// app. Set once here; nothing to touch again per-dictation. The
    /// separate Rewrite box below is for polishing arbitrary text on
    /// demand, not live dictation.
    private var autoCleanupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Auto Cleanup")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
            Text("Applies automatically to every dictation, before it's typed — across every app. Set once, not per-dictation.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))

            VStack(spacing: 8) {
                ForEach(AutoCleanupLevel.allCases) { level in
                    autoCleanupRow(level)
                }
            }

            if autoCleanupLevel == .medium {
                autoCleanupToneRow
            }
        }
        .padding(18)
        .quillCard()
    }

    /// Formal / Casual / Very Casual — Auto Cleanup's own tone set,
    /// deliberately narrower than Rewrite-on-demand's four options (no
    /// Clean Up, no Concise here).
    private let autoCleanupTones: [StyleTone] = [.formal, .casual, .veryCasual]

    /// Which tone Medium rewrites into — one global choice, applied to
    /// every dictation the same way regardless of which app it's typed
    /// into. Deliberately not per-app: no monitoring of the frontmost app,
    /// same tone everywhere. Set once here, then just hold the dictation
    /// key like normal. Cards (name + example) instead of a plain
    /// segmented picker so the difference between tones is legible before
    /// picking one — same idea as Wispr Flow's preview cards.
    private var autoCleanupToneRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tone")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .padding(.top, 2)

            HStack(alignment: .top, spacing: 10) {
                ForEach(autoCleanupTones) { tone in
                    toneCard(tone)
                }
            }
        }
        .padding(.horizontal, 2)
    }

    private func toneCard(_ tone: StyleTone) -> some View {
        let selected = autoCleanupTone == tone
        return Button {
            autoCleanupTone = tone
            QuillSettings.autoCleanupTone = tone
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tone.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    Text(tone.styleHint)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                }
                Text(tone.example)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Theme.accent.opacity(0.12) : Color.white.opacity(0.02))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? Theme.accent : Color.white.opacity(0.08), lineWidth: selected ? 1.5 : 1)
            )
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    private func autoCleanupRow(_ level: AutoCleanupLevel) -> some View {
        let selected = autoCleanupLevel == level
        return Button {
            autoCleanupLevel = level
            QuillSettings.autoCleanupLevel = level
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(selected ? Theme.accent : .white.opacity(0.35))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(level.rawValue)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        if level == .medium {
                            Text(hasKey ? "USES YOUR KEY" : "NO KEY YET — USES LIGHT")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(hasKey ? Theme.accent : .white.opacity(0.35))
                        }
                    }
                    Text(level.summary)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
            }
            .padding(12)
            .background(selected ? Color.white.opacity(0.06) : Color.white.opacity(0.02))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - API key

    private var apiKeyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Connect an API key")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                if hasKey {
                    Label("Connected", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.accent)
                }
            }

            Picker("", selection: $provider) {
                ForEach(StyleProvider.allCases) { p in
                    Text(p.rawValue).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: provider) { _, new in
                QuillSettings.styleProvider = new
                apiKeyField = ""
            }

            HStack(spacing: 8) {
                SecureField(
                    hasKey ? "Key saved — paste a new one to replace it" : "Paste your \(provider.rawValue) API key",
                    text: $apiKeyField
                )
                .textFieldStyle(.roundedBorder)

                Button("Save") {
                    APIKeyStore.setKey(apiKeyField, for: provider)
                    updateConnected()
                    apiKeyField = ""
                }
                .disabled(apiKeyField.isEmpty)

                if hasKey {
                    Button("Remove", role: .destructive) {
                        APIKeyStore.clearKey(for: provider)
                        updateConnected()
                    }
                }
            }

            Text("""
            Stored in the macOS Keychain on this Mac only — never written to disk in plain text, \
            never committed to a repo, never sent anywhere except directly to \(provider.rawValue) \
            itself, and only at the moment you press Rewrite below.
            """)
            .font(.system(size: 11))
            .foregroundColor(.white.opacity(0.4))
        }
        .padding(18)
        .quillCard()
    }

    private func updateConnected() {
        openAIConnected = APIKeyStore.hasKey(for: .openAI)
        anthropicConnected = APIKeyStore.hasKey(for: .anthropic)
    }

    // MARK: - Rewrite

    private var rewriteCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Rewrite on demand")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
            Text("For polishing arbitrary text whenever you want, separate from Auto Cleanup above.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))

            Picker("", selection: $tone) {
                ForEach([StyleTone.cleanUp, .formal, .casual, .concise]) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if tone == .cleanUp {
                Text("Runs entirely on this Mac — filler words and basic punctuation, no network, no key needed.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            } else if !hasKey {
                Text("Add an API key above to use \(tone.rawValue) — Clean Up works offline without one.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $inputText)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .frame(height: 90)
                    .padding(6)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)

                if inputText.isEmpty {
                    Text("Paste or type text to clean up or rewrite…")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }

            HStack {
                Button(action: runRewrite) {
                    if isRewriting {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(tone == .cleanUp ? "Clean Up" : "Rewrite")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(inputText.isEmpty || isRewriting || (tone != .cleanUp && !hasKey))

                Spacer()
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }

            if !outputText.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Divider().opacity(0.1)
                    Text(outputText)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.9))
                        .textSelection(.enabled)
                    Button(action: copyOutput) {
                        Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(18)
        .quillCard()
    }

    private func runRewrite() {
        errorMessage = nil
        outputText = ""

        // Clean Up never touches the network, regardless of whether a key
        // is set — it's the always-local tier, on purpose.
        if tone == .cleanUp {
            outputText = AutoCleanup.localCleanup(inputText)
            return
        }

        isRewriting = true
        let text = inputText
        let currentTone = tone
        let currentProvider = provider
        Task {
            do {
                let result = try await StyleRewriter.rewrite(text, tone: currentTone, provider: currentProvider)
                await MainActor.run {
                    outputText = result
                    isRewriting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isRewriting = false
                }
            }
        }
    }

    private func copyOutput() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(outputText, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
    }
}

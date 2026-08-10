import AppKit
import SwiftUI

struct StyleView: View {
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
                    apiKeyCard
                    rewriteCard
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
            Text("Rewrite")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)

            Picker("", selection: $tone) {
                ForEach(StyleTone.allCases) { t in
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
            outputText = TranscriptSanitizer.cleanUpFillers(inputText)
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

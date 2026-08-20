import AppKit
import SwiftUI

struct StyleView: View {
    @State private var autoCleanupLevel: AutoCleanupLevel = QuillSettings.autoCleanupLevel
    @State private var autoCleanupTone: StyleTone = QuillSettings.autoCleanupTone

    // Local AI's download/delete management now lives in Enhancement
    // Engine (top of its provider list) alongside OpenAI/Anthropic/
    // Google/OpenRouter — one place to manage every AI backend Style can
    // use. This view only needs to know whether the model is already on
    // disk, for the row's "READY"/"NOT DOWNLOADED" badge — re-read fresh
    // on every (re)construction, same reasoning as `provider` below:
    // StyleView is fully torn down when the sidebar selection leaves
    // Style, so this naturally picks up a download that happened while
    // this tab wasn't visible.
    @State private var localAIDownloaded = LocalEnhancer.isDownloaded()

    // Key connection itself now lives in the Enhancement Engine sidebar
    // tab (`EnhancementEngineView.swift`) — this view still needs to know
    // *whether* a key is connected (Medium's badge, the Rewrite card's
    // disabled state) and *which provider* Enhancement Engine last saved a
    // key for, since that's the provider Rewrite/Medium actually calls.
    // Re-read fresh from QuillSettings/APIKeyStore every time this view is
    // (re)constructed — StyleView is fully torn down when the sidebar
    // selection leaves Style and rebuilt when it comes back, same pattern
    // ModelsSettingsView already relies on for `currentModelID`.
    @State private var provider: StyleProvider = QuillSettings.styleProvider

    @State private var tone: StyleTone = .cleanUp
    @State private var inputText: String = ""
    @State private var outputText: String = ""
    @State private var isRewriting = false
    @State private var errorMessage: String?
    @State private var copied = false

    // Whichever provider Enhancement Engine last connected a key for —
    // this is the one Medium/Rewrite actually use, so only that one needs
    // checking here (was a 2-way ternary before Google/OpenRouter existed;
    // that broke silently for any provider past the first two).
    private var hasKey: Bool {
        APIKeyStore.hasKey(for: provider)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Style")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, Theme.pagePadding)
                .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    autoCleanupCard
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
                .foregroundColor(Theme.textPrimary)
            Text("Applies automatically to every dictation, before it's typed, across every app. Set once, not per-dictation.")
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)

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
                .foregroundColor(Theme.textSecondary)
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
                        .foregroundColor(Theme.textPrimary)
                    // Fixed 2-line height regardless of actual wrap — the
                    // three style hints are different lengths ("Lowercase,
                    // minimal punctuation" vs "Relaxed punctuation, natural
                    // capitalization"), so without this the cards drift out
                    // of alignment with each other by a line.
                    Text(tone.styleHint)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: 24, alignment: .topLeading)
                }
                // Same reasoning, fixed 2-line height: the example
                // sentences wrap to different line counts per tone (Very
                // Casual's is one short line, Formal's wraps to two).
                Text(tone.example)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 32, alignment: .topLeading)
                    .padding(10)
                    .background(Theme.textQuaternary)
                    .cornerRadius(8)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Theme.accent.opacity(0.12) : Theme.textQuaternary)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? Theme.accent : Theme.fillHover, lineWidth: selected ? 1.5 : 1)
            )
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    /// Selecting Local AI here never blocks on a download — same as
    /// Medium, which is always selectable even with no key connected
    /// (`AutoCleanup.apply` falls back to Light for either level until
    /// its backend is actually ready). Downloading/deleting the model
    /// itself is Enhancement Engine's job now, not this row's.
    private func autoCleanupRow(_ level: AutoCleanupLevel) -> some View {
        let selected = autoCleanupLevel == level
        return Button {
            autoCleanupLevel = level
            QuillSettings.autoCleanupLevel = level
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(selected ? Theme.accent : Theme.textTertiary)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(level.rawValue)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                        if level == .medium {
                            Text(hasKey ? "USES YOUR KEY" : "NO KEY YET · USES LIGHT")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(hasKey ? Theme.accent : Theme.textTertiary)
                        }
                        if level == .localAI {
                            Text(localAIDownloaded ? "READY" : "NOT DOWNLOADED · USES LIGHT")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(localAIDownloaded ? Theme.accent : Theme.textTertiary)
                        }
                    }
                    Text(level.summary)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                    if level == .localAI && !localAIDownloaded {
                        Text("Download the model in Enhancement Engine.")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textTertiary)
                    }
                }
                Spacer()
            }
            .padding(12)
            .background(selected ? Theme.fillHover : Theme.textQuaternary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Rewrite

    // API key connection now lives entirely in EnhancementEngineView.swift
    // — no in-place editor here anymore, just the `hasKey`/`provider`
    // reads above, used to gate Medium's badge and the Rewrite card below.

    private var rewriteCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Rewrite on demand")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
            Text("For polishing arbitrary text whenever you want, separate from Auto Cleanup above.")
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)

            Picker("", selection: $tone) {
                ForEach([StyleTone.cleanUp, .formal, .casual, .concise]) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if tone == .cleanUp {
                Text("Runs entirely on this Mac: filler words and basic punctuation, no network, no key needed.")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
            } else if !hasKey {
                Text("Connect an API key in Enhancement Engine to use \(tone.rawValue). Clean Up works offline without one.")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $inputText)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .frame(height: 90)
                    .padding(6)
                    .background(Theme.textQuaternary)
                    .cornerRadius(8)

                if inputText.isEmpty {
                    Text("Paste or type text to clean up or rewrite…")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textTertiary)
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
                        .foregroundColor(Theme.textPrimary)
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

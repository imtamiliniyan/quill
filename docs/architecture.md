# Architecture

This describes Quill as it actually is today - a full native macOS dictation app, not the bare CLI daemon the earliest version of this document described. Quill grew from that daemon into a menu bar app with a real window, on-device AND cloud-optional AI cleanup, dictation history/insights, and Sparkle-based auto-updates. Nothing below is aspirational; every module named here exists in `Sources/quill/` today.

## Goals

1. **Native macOS app, menu bar first.** Runs as a menu bar (`NSStatusItem`) presence with no dock icon by default (`.accessory` activation policy); a full app window is one click away and only claims a dock icon while it's open.
2. **Push-to-talk.** Hold Fn (default), speak, release - transcript appears at the cursor. Toggle and "automatic" (either gesture) activation modes are also available.
3. **On-device transcription, always.** No network calls for speech-to-text. Audio never leaves the machine, on any Auto Cleanup tier.
4. **AI cleanup is optional, and has an on-device option too.** Three tiers: type exactly what you said, clean up on-device with a small local LLM (no key, no cloud), or clean up via your own OpenAI/Anthropic/Google/OpenRouter key. The free, on-device tier is a first-class option, not a downsell toward BYOK.
5. **Pluggable transcription engines and models.** WhisperKit and FluidAudio (Parakeet) both ship; the model list is a static Swift registry, not bundled resources - new engines are one new `Transcriber` conformance.
6. **Real auto-update.** Sparkle-signed releases, checked automatically and via a menu item, no manual "check GitHub and download" step for the user.
7. **Native and lean.** One Swift Package executable target. No sidecar processes, no HTTP servers, no bundled Node/Electron runtime.

## Non-goals

- Cross-platform (macOS only, Apple Silicon)
- Streaming partial transcripts - push-to-talk only; batch transcription after release, not live-updating text while still speaking (the recording overlay's own live-transcript preview is deliberately parked, see Open Questions)
- Cloud transcription providers - every transcription engine is on-device; "cloud" only ever refers to the optional cleanup step, never the speech-to-text step itself
- Voice-driven Mac control, agentic text editing, or slash-command modes ("Command Mode"/"Edit Mode" in competitor products) - Quill cleans up dictation, it doesn't operate your Mac
- Meeting recording, speaker diarization, semantic search
- True per-speaker model fine-tuning ("train it on my voice") - not technically realistic on-device; see Open Questions for the ASR-level vocabulary-boosting alternative actually being scoped
- Notarization - an explicit, stated tradeoff (no Apple Developer Program enrollment); Homebrew's cask install works around Gatekeeper's warning, a direct `.dmg` download does not

## Why Swift

- **CoreML / ANE access.** WhisperKit and FluidAudio are Swift-native and run inference on the Apple Neural Engine.
- **MLX for on-device cleanup too.** Local AI's rewrite model (Llama 3.2 3B Instruct, 4-bit) runs via `mlx-swift-lm` - Apple's own MLX framework, Swift-native, no Python runtime bundled.
- **No FFI for platform APIs.** `AVAudioEngine`, `CGEventTap`, `CGEvent`, `AXUIElement` (Accessibility), `NSWindow`, `NSStatusItem` - all first-party.
- **Permissions plumbing** (microphone, accessibility) is far smoother in a Swift/AppKit binary than via a wrapped runtime.
- **AppKit + SwiftUI hybrid for free.** The recording overlay, the menu bar item, and the main app window are all native `NSWindow`/`NSStatusItem` hosting SwiftUI content - no cross-platform UI toolkit needed for a single-platform app.

The binary is a single Swift Package executable target (`swift build -c release`), assembled into a `.app` bundle by `scripts/build-app.sh` for distribution (icon, `Info.plist`, code signing, bundling `Sparkle.framework`) - `swift build` alone produces a working binary but not a double-clickable app.

## High-level shape

```
                                    ┌──────────────────────────┐
                                    │   Quill (ArgumentParser) │
                                    │   Quill.swift            │
                                    └───────────┬──────────────┘
                                                │ wires modules, NSApp.run()
                                                ▼
┌──────────────────┐  hotkey down   ┌──────────────────┐
│   HotkeyMonitor  │ ─────────────▶ │  AudioCapture    │
│  (CGEventTap)    │  hotkey up     │ (AVAudioEngine)  │
└──────────────────┘ ◀───────────── └────────┬─────────┘
                                             │ [Float] PCM
                                             ▼
                                    ┌──────────────────┐
                                    │  Transcriber     │  (via TranscriberBox,
                                    │  (protocol)      │   live-swappable)
                                    │  WhisperKit /    │
                                    │  Parakeet        │
                                    └────────┬─────────┘
                                             │ String
                                             ▼
                                    ┌─────────────────────┐
                                    │ TranscriptSanitizer │  bracket-noise strip +
                                    │  (always runs)      │  "literal <command>" trigger
                                    └────────┬────────────┘
                                             │
                                             ▼
                                    ┌──────────────────┐
                                    │   AutoCleanup     │  None / Local AI (MLX) /
                                    │  (per-tier)       │  Medium (OpenAI/Anthropic/
                                    └────────┬─────────┘  Google/OpenRouter, BYOK)
                                             │
                                             ▼
                                    ┌────────────────────┐
                                    │  TextFormatting    │  lowercase-first / space-
                                    │  (+ CursorContext) │  between / smart-capitalize
                                    └────────┬───────────┘
                                             │
                                             ▼
                                    ┌──────────────────┐
                                    │  TextInjector    │
                                    │   (CGEvent)      │
                                    └──────────────────┘
```

Alongside this hot path: `MenuBarController` (always present), `MainWindow`/`MainView` (opened on demand - the full sidebar app), `DictationHistory` (every dictation logged locally), `AppUpdater` (Sparkle, runs independently of dictation).

## Two ways the app is running at once

Quill is never just "the daemon" - two independent pieces of UI exist simultaneously:

1. **The menu bar item** (`MenuBarController`) - always present while Quill runs. Shows idle/recording/transcribing state, the active model, and a menu: Switch Model, Copy Last Transcript, Open Quill, Settings…, Check for Updates…, Quit.
2. **The main app window** (`MainWindow` → `MainView`), opened from the menu bar's "Open Quill" or by double-clicking the `.app`. A real `NSWindow` (`.titled`, resizable) with a sidebar of tabs: **Dictation** (live history), **Insights** (words/streaks/time-saved stats), **Style** (Auto Cleanup level + tone + manual Rewrite), **Voice Engine** (transcription model picker), **Enhancement Engine** (BYOK provider keys + Local AI model management), **Getting Started** (re-runnable onboarding), **Change Log** (real GitHub Release notes, fetched live), **Feedback** (mailto-based bug/feedback form with a clipboard fallback). A titlebar accessory (`TitleBarStatsView`) sits next to the traffic lights with a light/dark toggle and a Feedback shortcut, visible regardless of which tab is open.

`NSApp.setActivationPolicy` flips between `.accessory` (menu bar only, no dock icon) and `.regular` (dock icon shown) exactly while the main window is open - closing it drops back to `.accessory`.

## Modules

Grouped by folder under `Sources/quill/`, matching the actual source layout (see **Project layout** below).

### Process / CLI (root of `Sources/quill/`)

- **`Quill.swift`** - the `@main` `ParsableCommand` (`swift-argument-parser`). Subcommands: `run` (default - the daemon), `setup` (first-run permission walkthrough), `doctor` (permission/config diagnostics), `models list`/`models download`, `local-ai test` (exercises the Local AI rewrite path directly against arbitrary text, no audio needed - the harness used for verifying dictation-cleanup fixes), `install` (LaunchAgent add/remove for launch-at-login). Two real entry paths inside `run`: a direct path (skips onboarding, used by the LaunchAgent daemon) and an onboarding-gated path (first run / double-clicked `.app`), both wiring up the same modules.
- **`Doctor.swift` / `Setup.swift`** - permission and configuration checks (microphone, accessibility, Fn key remapping), shared between the `doctor` subcommand and the startup checks `run` performs unless `--skip-doctor` is passed.
- **`Install.swift`** - installs/removes the `launchd` LaunchAgent for launch-at-login (`LaunchAtLoginManager` in `Settings/` does the actual plist work).
- **`SingleInstance.swift`** - an `flock()`'d lock file ensures only one process ever holds the Fn-key tap. Without it, a LaunchAgent daemon and a double-clicked `.app` each install their own `CGEventTap`, and every dictation gets captured and typed twice. Whichever process loses the race asks the winner to open its window instead of starting a second daemon.

### Input (`Input/`)

- **`HotkeyMonitor`** - global hotkey via `CGEventTap` on `flagsChanged`, default **hold Fn**. Emits `.pressed`/`.released`; mode-agnostic by design.
- **`ActivationMode`** - `.hold` (press/release, walkie-talkie), `.toggle` (press to start, press again to stop), `.automatic` (either: a quick tap toggles, a held press stops on release past a threshold). The mode-specific state machine lives in `Quill.swift`'s `attachDictationHandlers`, not in `HotkeyMonitor` itself.
- **`TextInjector`** - posts the cleaned text at the cursor via `CGEvent`; falls back to clipboard-paste for apps that drop synthetic keystrokes (some Electron apps).
- **`CursorContext`** - best-effort Accessibility read of the text immediately before the cursor in whatever app is focused. Powers "Space Between Dictations" and "Smart Capitalization." Fails to `nil` (not a guess) when an app's AX support won't answer - several Electron/Chromium editors don't expose a standards-compliant `AXValue`.

### Audio (`Audio/`)

- **`AudioCapture`** - `AVAudioEngine` tap on the input node, 16kHz mono `Float32`, buffered while the hotkey is held. Also feeds live mic-level data to the recording overlay and onboarding's mic-test preview.

### Transcription (`Transcription/`)

- **`Transcriber`** (protocol) - `warmUp(progress:)` and `transcribe(_:) async throws -> String`. `TranscriberFactory` picks the concrete implementation from a model's `Engine`.
- **`WhisperKitTranscriber`** / **`ParakeetTranscriber`** - wrap WhisperKit and FluidAudio respectively. Both funnel their raw output through `TranscriptSanitizer.sanitize` before returning.
- **`TranscriberBox`** - holds the transcriber actually in use so the menu bar model switcher can swap it live without tearing down the hotkey monitor or restarting the daemon.
- **`ModelAvailability`** - best-effort "is this model already on disk" check, so switching to an already-downloaded model skips the confirm-and-download prompt.
- **`ParakeetModelVersion`** - resolves Quill's own `parakeetVersion` string (`"v2"`/`"v3"`/`"tdtCtc110m"`) to FluidAudio's real enum, kept out of `TranscriptionModel` itself so that type doesn't need a FluidAudio import.
- **`TranscriptSanitizer`** - runs on every transcript, from every engine, regardless of Auto Cleanup tier:
  - Strips non-speech bracket tokens (`[BLANK_AUDIO]`, `(silence)`, etc.) a model can emit when it hears nothing.
  - Applies the **"literal `<command>`" trigger word**: saying "literal new line"/"literal period"/"literal comma"/"literal question mark"/"literal exclamation mark or point" forces that exact result deterministically - no model call, so it can't be unreliable the way Auto Cleanup's LLM-inferred version of the same commands can be on long/complex dictation. Strict word-boundary match so it never fires on "literally"; requiring the trigger at all means genuine content containing those words untouched. Scoped to unambiguous 1:1 substitutions only - wrapping commands (bold/header) still need real clause-boundary judgment and stay LLM-only.
  - Also home to `cleanUpFillers` - the rule-based (no model, no network) filler-word/basic-punctuation pass used by Auto Cleanup's `.none`-adjacent fallback path and Style's manual "Clean Up" tone.

### Models (`Models/`)

- **`ModelRegistry`** - the transcription model list lives directly in Swift source (not a bundled JSON resource, so the binary stays self-contained with no `Bundle.module` lookup). Currently 9 models: 6 WhisperKit sizes (tiny through large-v3) and 3 Parakeet variants (v2 English-only, v3 multilingual/recommended, and a 110M fast TDT-CTC hybrid). Every `sizeMB` is a real number computed from each model's actual required files via the HuggingFace tree API, not a guess; `speed`/`accuracy` are 1–5 relative dot ratings, not fabricated benchmark percentages.
- **`TranscriptionModel`** - the `Codable` model descriptor (id, display name, engine, per-engine ID, size, languages, recommended flag, speed/accuracy dots).

### Style / cleanup pipeline (`Style/`)

- **`AutoCleanup`** - the three-tier `AutoCleanupLevel`: `.none` (types exactly what you said), `.localAI` ("Local AI" - on-device MLX rewrite, no key, no network), `.medium` (displayed as **"Cloud Model"** - BYOK cloud rewrite; the internal name is a leftover from a retired Light/Medium/Full ladder and is kept because it's what's persisted to `UserDefaults`). Each tier falls back to the rule-based `cleanUpFillers` pass if its backend isn't ready (model not downloaded, no key set) rather than blocking dictation or typing nothing.
- **`DictationCleanupPrompt`** - the shared system prompt for every LLM-backed rewrite (Local AI and all 4 cloud providers), plus deterministic post-processing backstops layered on top of it: hallucination/content-loss detection (falls back to raw+filler-cleanup if the model dropped too much or clearly went off-script), spoken-digit-run conversion ("five thirty" → "5:30"), spoken-enumeration promotion into real numbered lists, and stray-markdown-marker stripping. Built this way deliberately: prompt-only iteration on a 3B on-device model causes whack-a-mole regressions on well-scoped, unambiguous patterns (numbers, lists, standalone formatting commands) - those get a deterministic string transform instead of another prompt tweak.
- **`LocalEnhancer`** - MLX model load/generate/download/delete for Local AI (`mlx-swift-lm`, Llama 3.2 3B Instruct 4-bit by default, fetched from Hugging Face on first use, not bundled).
- **`StyleRewriter`** - the 4 cloud BYOK providers (OpenAI, Anthropic, Google, OpenRouter), one `rewrite` entry point dispatching to per-provider implementations, all funneled through the same `DictationCleanupPrompt` backstops.
- **`TextFormatting`** - literal, user-controlled adjustments applied last, after Auto Cleanup: lowercase-first-letter, space-between-back-to-back-dictations, and smart capitalization (via `CursorContext` - capitalizes only when the text before the cursor looks like a fresh sentence).
- **`LocalLLMModel`** / **`OpenRouterModels`** - model descriptors/catalog fetch for Local AI's model choice and OpenRouter's live model picker respectively.

### Settings & identity (`Settings/`, `Onboarding/`)

- **`QuillSettings`** (`Onboarding/`) - the `UserDefaults`-backed settings store: Auto Cleanup level/tone, activation mode, text formatting toggles, filler word list, dark-mode override, assumed typing WPM, selected models, debug logging, and more. One place, not scattered `UserDefaults` calls.
- **`APIKeyStore`** (`Settings/`) - Keychain-backed BYOK key storage (`StyleProvider`: OpenAI/Anthropic/Google/OpenRouter). Existence checks use `kSecReturnAttributes`, not `kSecReturnData`, specifically so checking whether a key exists doesn't itself trigger a macOS Keychain authorization prompt.
- **`LaunchAtLoginManager`** - launch-at-login LaunchAgent plist management.
- **`OnboardingState`** - drives the first-run flow (permissions → transcription model → Local AI offer).

### History & diagnostics (`History/`, `Diagnostics/`)

- **`DictationHistory`** - every dictation appended to `~/Library/Application Support/Quill/history.jsonl`. Local only, never uploaded; `rawText` is stored alongside the cleaned text only when Auto Cleanup actually changed something, which is also how "fixes made" gets counted.
- **`DictationStats`** - pure computed properties over `DictationHistory`'s entries: total words, WPM, streaks, time saved (given a user-editable assumed typing speed), personal records, milestones. Shared by Insights and the title bar pill's earlier iteration, so every surface agrees on one formula.
- **`QuillLog`** - captures the app's own stderr debug output (model loads, hotkey failures, Auto Cleanup fallbacks) into a capped local log a user can review and optionally attach to Feedback. Not a crash reporter, not telemetry - nothing leaves the Mac unless the user explicitly attaches it to an email they send themselves.

### UI (`UI/`)

- **`MenuBarController`** - the `NSStatusItem` and its menu (see "Two ways the app is running").
- **`MainWindow`** / **`MainView`** - the full app window and its sidebar (`SidebarItem` enum: Dictation/Insights/Style/Voice Engine/Enhancement Engine/Getting Started/Change Log/Feedback), plus the Settings sheet.
- **`TitleBarStatsView`** / **`StandardMenu`** - a titlebar accessory (light/dark toggle, Feedback shortcut) hosted via `NSTitlebarAccessoryViewController`; and a minimal `NSApp.mainMenu` (Edit menu: Cut/Copy/Paste/Select All/Undo/Redo) that a `ParsableCommand`-based app doesn't get for free the way a SwiftUI `App` or nib-based app would - without it, ⌘C/⌘V silently do nothing in any text field.
- **`RecordingOverlay`** - a borderless, click-through `NSWindow` pill shown while recording/transcribing, with a live mic-level waveform.
- **`AppUpdater`** - wraps Sparkle's `SPUStandardUpdaterController`; owns both the automatic background check and the menu bar's "Check for Updates…" item. Sparkle's own native alert handles found/not-found, download, EdDSA signature verification, and install.
- **`GitHubReleases`** / **`ChangeLog`** / **`ChangeLogView`** - the Change Log tab's live source: fetches real release notes from GitHub's public Releases API (parsing a `Released: yyyy-MM-dd` line plus `- ` bullets out of each release body), falling back to a small hand-written array if the fetch fails.
- **`DownloadActivity`** - a global signal a persistent bar in `MainView` observes, so any model download (transcription switch or Local AI) stays visible above every sidebar tab regardless of which view started it or whether that view is still on screen.
- **`Theme`** - the shared, appearance-aware color palette (light/dark, following System Settings or `QuillSettings`' manual override) every view draws from.
- Feature-specific views: `DictationView`, `InsightsView` (+ `ActivityChartView`, `StreakCalendarView`), `StyleView`, `VoiceEngineView`, `EnhancementEngineView` (+ `ProviderLogos`), `GettingStartedView`, `FeedbackView`, `Settings/SettingsView`, `OnboardingView`/`OnboardingWindow`, `ModelDownloadView`/`ModelDownloadState`, `MicLevelMeter`.

## Data flow, end-to-end

1. `Quill` (ArgumentParser) validates permissions, loads settings, wires modules, sets `.accessory` activation policy, enters `NSApp.run()`.
2. Menu bar shows `idle`.
3. User triggers dictation per their `ActivationMode` (hold/toggle/automatic). `RecordingOverlay` shows; `AudioCapture` starts buffering.
4. Dictation ends (release, second toggle press, or hold-threshold release). Overlay switches to a transcribing state.
5. The active `Transcriber` (via `TranscriberBox`) runs CoreML inference, returns a string.
6. `TranscriptSanitizer.sanitize` runs unconditionally: strips non-speech bracket noise, applies any "literal `<command>`" triggers.
7. `AutoCleanup.apply` runs per the user's tier (None / Local AI / Medium), with the model prompt's own deterministic backstops layered on top; falls back to `cleanUpFillers` on any failure.
8. `TextFormatting.apply` runs the user's formatting toggles, reading `CursorContext` if needed.
9. `TextInjector` posts the final text at the cursor.
10. `DictationHistory.append` logs the entry (raw text too, if cleanup changed anything).
11. Overlay hides. Menu bar back to `idle`.

## Permissions

Two prompts, surfaced via `quill doctor` and the onboarding flow:

1. **Microphone** - standard `AVCaptureDevice` request.
2. **Accessibility** - required for `CGEventTap` (hotkey) and `CGEvent`/AX reads (text injection, cursor context). Granted to whatever process actually owns the binary's TCC identity - the `.app` bundle itself when launched normally, or the parent terminal/LaunchAgent if run some other way. Switching how Quill is launched (Terminal → double-clicked `.app` → LaunchAgent) can require re-granting.

`quill doctor` checks both, and Fn-key remapping (macOS can map 🌐 to Emoji/Dictation instead of leaving it a plain modifier - `quill doctor` detects this and tells the user to set it to "Do Nothing").

## Distribution & auto-update

- **Releases**: tagged (`vX.Y.Z`) on GitHub. `.github/workflows/release.yml` builds automatically on every tag push but lands as a **draft** - the real signed `.dmg`/`.zip` are always uploaded by hand afterward, replacing CI's unsigned CLI-only tarball, before publishing.
- **Sparkle auto-update**: `AppUpdater` checks `appcast.xml` (an RSS+Sparkle-namespace feed at the repo root, served via jsDelivr's GitHub CDN mirror - not `raw.githubusercontent.com`, whose cache proved to serve stale content inconsistently across edge locations for several minutes after a push; jsDelivr supports an explicit purge, which is the actual "go live" step after pushing an appcast update). Every release is EdDSA-signed (`scripts/release-appcast.sh`) and Sparkle verifies the signature before installing. Automatic background checks plus a manual "Check for Updates…" menu item; Sparkle's own alert requires an explicit click to actually install, never installs silently.
- **Homebrew**: `imtamiliniyan/homebrew-quill` (a separate repo/tap). Not just a convenience - since Quill isn't notarized, a direct `.dmg` download gets Gatekeeper's hard "cannot verify" block with no override option, while `brew install --cask` includes a `postflight` that strips `com.apple.quarantine`, so it opens cleanly.
- **Notarization - explicitly declined**, not an oversight: Quill is free and open source, and $99/year for a solo Developer ID enrollment wasn't judged worth it. Stated openly on the landing page and in `SECURITY.md`'s scope section, with Homebrew as the real mitigation for the common install path.

## What we are deliberately NOT building

- Streaming/live-updating transcript text while still speaking - batch transcription after hotkey release only. The recording overlay's pill/waveform/state machine already exist; the live-text piece is blocked on `Transcriber` having no streaming/partial-result API in either backend, and approximating it via repeated re-transcription costs real CPU/battery and visibly "flickers" as later passes revise earlier guesses. A real tradeoff, presented rather than silently built or silently skipped.
- True model fine-tuning on the user's own voice/phonetics - not realistic on-device, and not actually what similar competitor products do either despite marketing language implying it. The realistic, scoped alternative (ASR-level vocabulary boosting/correction via FluidAudio's own `CustomVocabularyContext`/CTC rescoring, already used by Quill's Parakeet engine) is scoped but not built - see Open Questions.
- Voice-driven Mac control or agentic editing ("Command Mode"/"Edit Mode" in some competitors) - different product entirely from "clean up my dictation."
- Meeting recording, speaker diarization, semantic search over transcripts.
- Notarization (see Distribution above - a stated business tradeoff, not a gap).

## Project layout

```
quill/
  Package.swift                    # SPM, single executable target, macOS 14+
  Sources/quill/
    Quill.swift                    # @main ParsableCommand, subcommands, run loop
    Doctor.swift / Setup.swift / Install.swift
    SingleInstance.swift           # flock()'d single-daemon guard

    Input/
      HotkeyMonitor.swift          # CGEventTap
      ActivationMode.swift         # hold / toggle / automatic
      TextInjector.swift           # CGEvent posting, clipboard-paste fallback
      CursorContext.swift          # Accessibility read of text before cursor

    Audio/
      AudioCapture.swift           # AVAudioEngine tap + ring buffer

    Transcription/
      Transcriber.swift            # protocol + TranscriberFactory
      WhisperKitTranscriber.swift
      ParakeetTranscriber.swift
      TranscriberBox.swift         # live-swappable current transcriber
      TranscriptSanitizer.swift    # bracket-noise strip + "literal" commands
      ModelAvailability.swift
      ParakeetModelVersion.swift

    Models/
      ModelRegistry.swift          # static Swift model list (9 models)
      TranscriptionModel.swift

    Style/                         # the cleanup pipeline
      AutoCleanup.swift            # None / Local AI / Medium tiers
      DictationCleanupPrompt.swift # shared LLM prompt + deterministic backstops
      LocalEnhancer.swift          # MLX on-device rewrite
      StyleRewriter.swift          # 4 cloud BYOK providers
      TextFormatting.swift         # lowercase/space/smart-capitalize
      LocalLLMModel.swift
      OpenRouterModels.swift

    Settings/
      APIKeyStore.swift            # Keychain-backed BYOK keys
      LaunchAtLoginManager.swift
      QuillProfile.swift

    Onboarding/
      QuillSettings.swift          # UserDefaults-backed settings store
      OnboardingState.swift

    History/
      DictationHistory.swift       # ~/Library/Application Support/Quill/history.jsonl
      DictationStats.swift

    Diagnostics/
      QuillLog.swift               # capped local debug log, Feedback-attachable

    UI/
      MainWindow.swift / MainView.swift   # sidebar app window + Settings sheet
      MenuBarController.swift             # NSStatusItem + menu
      RecordingOverlay.swift              # borderless pill, mic level
      TitleBarStatsView.swift / StandardMenu.swift
      AppUpdater.swift                    # Sparkle wrapper
      GitHubReleases.swift / ChangeLog.swift / ChangeLogView.swift
      DownloadActivity.swift
      Theme.swift
      DictationView.swift / InsightsView.swift / StyleView.swift /
      VoiceEngineView.swift / EnhancementEngineView.swift /
      GettingStartedView.swift / FeedbackView.swift /
      Settings/SettingsView.swift / OnboardingView.swift / OnboardingWindow.swift /
      ModelDownloadView.swift / ModelDownloadState.swift / MicLevelMeter.swift /
      ActivityChartView.swift / StreakCalendarView.swift / ProviderLogos.swift

  Resources/
    Info.plist                     # Sparkle keys (SUFeedURL, SUPublicEDKey, …)
  scripts/
    build-app.sh                   # assembles the .app bundle for local dev/test
    release-appcast.sh             # signs a release zip, prints the appcast <item>
  appcast.xml                      # Sparkle update feed
  landing/                         # the marketing site (separate Vercel project, quill-stt)
  docs/
    architecture.md                # this file
  README.md
  SECURITY.md
```

Build: `swift build -c release`. Resulting binary at `.build/release/quill`. Real distributable `.app`: `scripts/build-app.sh` (icon, `Info.plist`, code signing, bundling `Sparkle.framework`, producing a `.dmg`).

## Open questions

- **Custom vocabulary / word-boosting.** Quill's Parakeet engine already runs on FluidAudio, which ships a real CTC-based vocabulary-boosting system (`CustomVocabularyContext`/`CtcKeywordSpotter`/`VocabularyRescorer` - acoustic-evidence-based rescoring, not blind text substitution) - but it's wired into FluidAudio's `SlidingWindowAsrManager`, not the plain batch `AsrManager` `ParakeetTranscriber` currently uses. Building this means either switching to the streaming manager or running the CTC rescorer as a manual post-pass over the batch transcript, plus new UI for managing words. Parakeet-only; no equivalent path exists for WhisperKit.
- **Live-updating transcript text in the recording overlay.** Blocked on `Transcriber` having no streaming/partial-result API - see "What we are deliberately NOT building."
- **Trigger-word configurability.** The "literal `<command>`" trigger is currently hardcoded to the word "literal," not yet a `QuillSettings` field a user can customize.
- **Full signed+notarized CI pipeline.** The GitHub Actions release build produces an unsigned CLI-only tarball; the real signed `.app`/`.dmg` are always built and signed locally, by hand. A cloud-built signed pipeline needs a Developer ID cert and (if notarization is ever revisited) notarization credentials added as GitHub Secrets - a deliberate manual step, not yet automated.

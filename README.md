# Quill

[![Latest release](https://img.shields.io/github/v/release/imtamiliniyan/quill?label=latest)](https://github.com/imtamiliniyan/quill/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A free, on-device replacement for paid dictation tools like Wispr Flow and Gladia. Hold a hotkey, speak, release. Quill transcribes locally on the Apple Neural Engine and types the result directly into whatever's focused. No subscription, no account required, and no audio or dictation history ever leaves your Mac unless you explicitly connect your own cloud API key.

**[Download the latest release](https://github.com/imtamiliniyan/quill/releases/latest)** · macOS 14+ on Apple Silicon (M1 or newer)

## How to use

1. **Launch Quill.** It lives in the menu bar. No dock icon until you open the app window.
2. **Click into the text field you want to dictate into.** Messages, the address bar, a Slack thread, anywhere a cursor blinks.
3. **Hold the `fn` key, speak, release.** A small pill appears at the bottom of the screen while the mic is hot. (Toggle and Automatic activation are also available in Settings, if holding a key isn't your style.)
4. **The transcript types itself in at the cursor** when you release, usually within 200-300ms.

That's the whole interface: no record button, no stop button, no "send." First launch walks you through granting microphone + Accessibility permissions and picking a transcription model.

> **Note:** on most modern Macs the `fn` key is the bottom-left key. If yours is set to "Change Input Source" or "Show Emoji & Symbols," Quill's setup will tell you how to flip it back to plain `fn`.

## Features

- **Live dictation history** — every dictation, with per-entry copy/delete, so nothing's lost even if focus moved before it landed.
- **Insights** — words-per-minute gauge, streak calendar, personal records, and milestones, all computed locally from your own history.
- **Voice Engine** — 9 on-device transcription models across two engines (Whisper, Parakeet); switch anytime with real download progress for anything not yet on disk. See the table below.
- **Enhancement Engine** — clean up and rewrite dictation automatically or on demand:
  - **Local AI**: a small on-device model, no key, no cloud, nothing leaves your Mac.
  - **Bring your own key**: OpenAI, Anthropic, Google, or OpenRouter (with a searchable model picker over OpenRouter's full catalog). This is the only path in Quill that ever sends dictation text over the network, and only when you've explicitly connected a key and turned it on.
- **Activation modes** — Hold, Toggle, or Automatic (a hybrid of both).
- **Text Formatting** — lowercase first letter, space between dictations, smart capitalization, and an editable filler-word list.
- **Change Log** — synced live from this repo's own GitHub Releases, right in the app.
- **Settings** — profile, launch-at-login, and a Data & Privacy pane that plainly states what stays local vs. the BYOK exception above, plus one-click history clearing.

## Supported models

Speed and accuracy are relative 1-5 ratings based on each architecture's known characteristics, not a benchmark suite. Sizes are real, computed from each model's actual downloaded files.

| Model | Size | Languages | Speed | Accuracy |
|---|---|---|---|---|
| Whisper Tiny (English) | 73 MB | en | ●●●●● | ● |
| Whisper Base (English) | 145 MB | en | ●●●● | ●● |
| Whisper Small (English) | 488 MB | en | ●●● | ●●● |
| Whisper Medium (English) | 1,459 MB | en | ●● | ●●●● |
| Whisper Large v3 Turbo | 1,620 MB | multi | ●●● | ●●●●● |
| Whisper Large v3 | 2,947 MB | multi | ● | ●●●●● |
| Parakeet TDT-CTC 110M (Fast) | 217 MB | en | ●●●●● | ●● |
| Parakeet TDT 0.6B v2 (English) | 443 MB | en | ●●●●● | ●●●●● |
| **Parakeet TDT 0.6B v3** (recommended) | 480 MB | multi | ●●●●● | ●●●● |

## Build from source

```sh
git clone https://github.com/imtamiliniyan/quill.git
cd quill
./scripts/build-app.sh
```

This builds `dist/Quill.app` and packages `dist/Quill.dmg` (drag-to-Applications installer with a branded background). Open the `.dmg` and drag `Quill.app` to Applications. No separate install step, no terminal needed after that.

The build is signed with a stable local identity rather than left ad-hoc, so macOS doesn't re-prompt for Accessibility/Keychain access on every rebuild. See the comments at the top of [scripts/build-app.sh](scripts/build-app.sh) for the one-time certificate setup if you're building it yourself.

The `.dmg` itself is packaged with [dmgbuild](https://dmgbuild.readthedocs.io/) (`pip3 install dmgbuild`) rather than a live Finder/AppleScript session. Finder's background-picture setting doesn't reliably survive `hdiutil convert`; dmgbuild writes it directly. Layout settings live in [scripts/dmg_settings.py](scripts/dmg_settings.py).

For quick local iteration without packaging a `.dmg`:

```sh
swift build -c release
.build/release/quill --help
```

A separate CI workflow ([.github/workflows/release.yml](.github/workflows/release.yml)) builds a bare CLI binary on every tag push, but only ever produces a **draft** GitHub Release. Nothing from CI goes public, downloadable, or becomes "latest" until it's manually reviewed and published from GitHub's Releases page. The actual signed, notarizable `.app`/`.dmg` users should download is still built and uploaded manually via the script above.

## Privacy

Everything runs locally by default: transcription, history, and Insights never touch the network. The one exception is entirely opt-in: if you connect your own OpenAI, Anthropic, Google, or OpenRouter key in Enhancement Engine, dictation text is sent to that provider only when you press Rewrite or when Auto Cleanup's Medium tier runs. Keys are stored in the macOS Keychain, never written to disk in plain text, never committed anywhere.

## Stack

- **Swift + SwiftUI** — single SPM executable target, full app window over an `NSStatusItem` menu bar presence
- **WhisperKit** and **FluidAudio (Parakeet)** — on-device transcription via CoreML, ANE-accelerated, switchable at runtime
- **MLX** — Local AI's on-device rewrite model
- **AVAudioEngine** — mic capture
- **CGEventTap** — global hotkey
- **CGEvent** — text injection at cursor (falls back to clipboard-paste for apps like Electron that drop synthetic keystrokes)
- **Security framework (Keychain Services)** — BYOK API key storage
- **NSWindow** (borderless, click-through) — recording-indicator pill

See [docs/architecture.md](docs/architecture.md) for design notes.

## License

[MIT](LICENSE)

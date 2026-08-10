# Quill

A free, on-device replacement for paid dictation tools like Wispr Flow and Gladio. Hold a hotkey, speak, release — Quill transcribes locally on the Apple Neural Engine and types the result directly into whatever's focused. No subscription, no account, and no audio or dictation history ever leaves your Mac.

**Requires:** macOS 14+ on Apple Silicon (M1 or newer). Transcription runs on the Neural Engine via CoreML.

## How to use

1. **Launch Quill.** It lives in the menu bar — no dock icon until you open the app window.
2. **Click into the text field you want to dictate into** — Messages, the address bar, a Slack thread, anywhere a cursor blinks.
3. **Hold the `fn` key, speak, release.** A small pill appears at the bottom of the screen while the mic is hot.
4. **The transcript types itself in at the cursor** when you release, usually within 200–300ms.

That's the whole interface — no record button, no stop button, no "send." First launch walks you through granting microphone + Accessibility permissions and picking a transcription model.

> **Note:** on most modern Macs the `fn` key is the bottom-left key. If yours is set to "Change Input Source" or "Show Emoji & Symbols," Quill's setup will tell you how to flip it back to plain `fn`.

## What's in the app

Quill is a full menu-bar app, not just a background daemon:

- **Dictation** — live history of everything you've dictated, with per-entry copy/delete.
- **Insights** — words-per-minute gauge, a streak calendar, and stats on filler words and corrections caught over time.
- **Style** — two independent layers of cleanup, both opt-in and both **off by default**:
  - **Auto Cleanup** applies automatically to every dictation before it's typed, across every app — set once, not per-dictation.
    - *Light*: removes filler words and fixes basic punctuation. Fully local, instant, no key needed.
    - *Medium*: rewrites using a tone you pick once (Formal / Casual / Very Casual) via your own OpenAI or Anthropic API key (BYOK). This is the only thing in Quill that ever sends dictation text over the network, and only when Medium is explicitly turned on.
  - **Rewrite on demand** — a separate paste-in box for cleaning up or rewriting arbitrary text whenever you want, independent of live dictation.
- **Model switcher** — swap between transcription models (WhisperKit, Parakeet/FluidAudio) live from the menu bar, with real download progress for models not yet on disk.
- **Settings** — profile, launch-at-login, and a Data & Privacy pane that plainly states what stays local vs. the one BYOK exception above, plus one-click history clearing.

Your own OpenAI/Anthropic API key (if you add one for Medium) is stored in the macOS Keychain — never written to disk in plain text, never committed anywhere.

## Build from source

```sh
git clone https://github.com/imtamiliniyan/quill.git
cd quill
./scripts/build-app.sh
```

This builds `dist/Quill.app` and packages `dist/Quill.dmg` (drag-to-Applications installer with a branded background). Open the `.dmg` and drag `Quill.app` to Applications — no separate install step, no terminal needed after that.

The build is signed with a stable local identity rather than left ad-hoc, so macOS doesn't re-prompt for Accessibility/Keychain access on every rebuild. See the comments at the top of [scripts/build-app.sh](scripts/build-app.sh) for the one-time certificate setup if you're building it yourself.

For quick local iteration without packaging a `.dmg`:

```sh
swift build -c release
.build/release/quill --help
```

## Stack

- **Swift + SwiftUI** — single SPM executable target, full app window over an `NSStatusItem` menu bar presence
- **WhisperKit** and **FluidAudio (Parakeet)** — on-device transcription via CoreML, ANE-accelerated, switchable at runtime
- **AVAudioEngine** — mic capture
- **CGEventTap** — global hotkey
- **CGEvent** — text injection at cursor (falls back to clipboard-paste for apps like Electron that drop synthetic keystrokes)
- **Security framework (Keychain Services)** — BYOK API key storage for Style's Medium tier
- **NSWindow** (borderless, click-through) — recording-indicator pill

See [docs/architecture.md](docs/architecture.md) for design notes.

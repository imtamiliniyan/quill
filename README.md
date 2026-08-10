# Quill

A minimal macOS dictation daemon. Push-to-talk, on-device transcription, text inserted at the cursor.

> Quill is a fork of [digimata/parrot](https://github.com/digimata/parrot) by Andrew Jones, under the MIT license. It started from a fix for a bug where dictated text never reached the focused app (see [digimata/parrot#27](https://github.com/digimata/parrot/pull/27)), and is developed independently from here.

## Install

```sh
curl -fsSL https://imtamiliniyan.github.io/quill/install.sh | sh
quill setup                       # grants mic + accessibility, downloads the model
quill install --launch-at-login   # optional — runs in the background on login
```

**Requires:** macOS 14+ on Apple Silicon (M1 or newer). Transcription runs on the Apple Neural Engine via CoreML — so the installer refuses to run on Intel.

The installer drops the binary in `/usr/local/bin/quill`. Builds are unsigned for now, so the installer strips the quarantine xattr — once you've inspected the script you'll see exactly what it does.

## How to use

1. **Run it.** Either `quill install --launch-at-login` (daemonized, runs forever, lives in the menu bar), or `quill` in any terminal tab.
2. **Click into the text field you want to dictate into** — Messages, the address bar, a Slack thread, anywhere a cursor blinks.
3. **Hold the `fn` key, speak, release.** A small pill appears at the bottom of the screen while the mic is hot.
4. **The transcript types itself in at the cursor** when you release. Usually within 200-300ms.

That's it. There is no record button, no stop button, no "send" — `fn` is the whole interface.

> **Note:** on most modern Macs the `fn` key is the bottom-left key. If yours is set to "Change input source" or "Show emoji & symbols," `quill setup` will tell you how to flip it back to plain `fn`.

## CLI

```sh
quill                                 # run in the foreground (^C to quit)
quill setup                           # one-time setup: permissions + model download
quill install --launch-at-login       # register a LaunchAgent (background daemon)
quill install --uninstall             # remove the LaunchAgent
quill doctor                          # check permissions + fn key setting
quill models list                     # list available models
quill models download <id>            # pre-download a model
quill --model whisper-large-v3-turbo  # bigger, multilingual, slower first-run
quill --hotkey right-option           # change the push-to-talk key
quill --no-overlay                    # disable the bottom-of-screen pill
```

## Stack

- **Swift** — single SPM executable target
- **WhisperKit** — Whisper inference via CoreML, ANE-accelerated
- **AVAudioEngine** — mic capture
- **CGEventTap** — global hotkey
- **CGEvent** — text injection at cursor
- **NSWindow** (borderless, click-through) — recording-indicator pill

See [docs/architecture.md](docs/architecture.md) for design notes.

## Build from source

```sh
swift build -c release
.build/release/quill --help
```

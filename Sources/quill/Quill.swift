import AppKit
import ArgumentParser
import Foundation
import WhisperKit

@main
struct Quill: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "quill",
        abstract: "Minimal macOS dictation daemon. Hold Fn, speak, release.",
        subcommands: [Run.self, Setup.self, Doctor.self, Models.self, Install.self],
        defaultSubcommand: Run.self
    )
}

struct Run: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Run the daemon (default)."
    )

    @Flag(name: .long, help: "Skip permission checks at startup.")
    var skipDoctor: Bool = false

    @Flag(name: .long, help: "Print every keyboard event the tap sees (debug).")
    var debugHotkey: Bool = false

    @Flag(name: .long, help: "Write each capture to /tmp/quill-last.wav for inspection.")
    var dumpWav: Bool = false

    @Flag(name: .long, help: "Disable the on-screen recording overlay.")
    var noOverlay: Bool = false

    @Option(name: .long, help: "Model id to use. Defaults to the recommended model.")
    var model: String?

    func run() throws {
        // Exactly one quill process may own the Fn-key tap at a time. Two
        // running together (the "Launch at login" LaunchAgent daemon plus
        // a double-clicked Quill.app, say) don't just waste CPU — neither
        // tap consumes the key, so both independently capture, transcribe,
        // and inject on every hold, and every dictation gets typed twice.
        // Confirmed via `ps` showing both processes alive at once.
        guard SingleInstance.acquire() else {
            if !skipDoctor {
                // Most likely case: the background daemon is already
                // running and the user just double-clicked the app to look
                // at it. Don't fail silently — hand off to the instance
                // that's actually listening.
                SingleInstance.requestOpenMain()
            }
            FileHandle.standardError.write(Data(
                "quill is already running. Opening its window instead of starting a second instance.\n".utf8
            ))
            return
        }

        // --skip-doctor means "I already know what I'm doing" — this is what
        // the LaunchAgent (and any scripted/CLI use) passes. That path keeps
        // today's exact behavior: hard-fail and exit on missing permissions,
        // since there's no one at a screen to walk through onboarding and
        // launchd is the one who should decide whether to restart it.
        //
        // Without --skip-doctor (a bare `quill`, or double-clicking the
        // .app), missing permissions/model instead show an onboarding
        // window and keep the process alive — the app used to just
        // silently exit here, which is unusable for anyone not watching
        // the terminal it was launched from.
        if skipDoctor {
            try runAssumingConfigured()
        } else {
            try runWithOnboarding()
        }
    }

    // MARK: - CLI / LaunchAgent path (unchanged behavior)

    private func runAssumingConfigured() throws {
        let chosenModel: TranscriptionModel
        if let id = model {
            guard let m = ModelRegistry.find(id) else {
                FileHandle.standardError.write(Data("unknown model: \(id)\n".utf8))
                FileHandle.standardError.write(Data("run `quill models list` to see options.\n".utf8))
                throw ExitCode(1)
            }
            chosenModel = m
        } else {
            guard let m = ModelRegistry.recommended() else {
                FileHandle.standardError.write(Data("no models registered\n".utf8))
                throw ExitCode(1)
            }
            chosenModel = m
        }

        let transcriber = TranscriberFactory.make(for: chosenModel)
        let warmupSemaphore = DispatchSemaphore(value: 0)
        var warmupError: Error?
        Task.detached {
            do {
                try await transcriber.warmUp()
            } catch {
                warmupError = error
            }
            warmupSemaphore.signal()
        }
        warmupSemaphore.wait()
        if let warmupError {
            FileHandle.standardError.write(Data("warmup failed: \(warmupError)\n".utf8))
            throw ExitCode(1)
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        QuillSettings.applyAppearance()
        MainActor.assumeIsolated { _ = AppUpdater.shared }

        // Never prompt from this path — see HotkeyMonitor's promptForAccessibility doc.
        let monitor = HotkeyMonitor(debug: debugHotkey, promptForAccessibility: false)
        let capture = AudioCapture()
        let overlay: RecordingOverlay? = noOverlay ? nil : MainActor.assumeIsolated { RecordingOverlay() }
        if let overlay {
            capture.onLevel = { level in overlay.pushLevel(level) }
        }
        let menuBar = MainActor.assumeIsolated { MenuBarController(modelID: chosenModel.id) }
        let box = MainActor.assumeIsolated { TranscriberBox(transcriber: transcriber, modelID: chosenModel.id) }
        let mainWindow = MainActor.assumeIsolated { MainWindow(menuBar: menuBar) }
        MainActor.assumeIsolated {
            menuBar.attachModelSwitcher(box: box)
            menuBar.onModelNeedsDownload = { model in
                mainWindow.showDownload(model: model, box: box) {
                    menuBar.updateModel(model.id)
                }
            }
            menuBar.onOpenMain = { mainWindow.showMain() }
            menuBar.onOpenSettings = { mainWindow.showSettings() }
            menuBar.onCheckForUpdates = { AppUpdater.shared.checkForUpdates() }
        }
        SingleInstance.observeOpenMainRequests {
            MainActor.assumeIsolated { mainWindow.showMain() }
        }

        do {
            try attachDictationHandlers(
                monitor: monitor, capture: capture, overlay: overlay,
                menuBar: menuBar, box: box, dumpWav: dumpWav
            )
        } catch {
            FileHandle.standardError.write(Data("failed to register hotkey tap: \(error)\n".utf8))
            FileHandle.standardError.write(Data("run `quill setup` to configure permissions.\n".utf8))
            throw ExitCode(1)
        }

        installSigintHandler(monitor: monitor)
        FileHandle.standardError.write(Data("listening on fn hold · model: \(chosenModel.id) · ^C to quit\n".utf8))
        app.run()
    }

    // MARK: - Onboarding-gated path (bare `quill`, or the .app double-clicked)

    private func runWithOnboarding() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        QuillSettings.applyAppearance()
        MainActor.assumeIsolated { _ = AppUpdater.shared }

        let state = MainActor.assumeIsolated { OnboardingState() }
        let menuBar = MainActor.assumeIsolated {
            MenuBarController(modelID: state.selectedModel?.id ?? "not set")
        }
        let onboarding = MainActor.assumeIsolated { OnboardingWindow(state: state) }
        let mainWindow = MainActor.assumeIsolated { MainWindow(menuBar: menuBar) }
        MainActor.assumeIsolated {
            menuBar.onOpenMain = { mainWindow.showMain() }
            menuBar.onOpenSettings = { mainWindow.showSettings() }
            menuBar.onCheckForUpdates = { AppUpdater.shared.checkForUpdates() }
        }
        // Phase 5c: Settings' Getting Started tab reaches back to the same
        // onboarding window through this, via MainWindow → MainView.
        MainActor.assumeIsolated {
            mainWindow.onRunOnboardingAgain = {
                state.restart()
                onboarding.show()
            }
        }
        SingleInstance.observeOpenMainRequests {
            MainActor.assumeIsolated { mainWindow.showMain() }
        }

        let monitor = HotkeyMonitor(debug: debugHotkey)
        let capture = AudioCapture()
        let overlay: RecordingOverlay? = noOverlay ? nil : MainActor.assumeIsolated { RecordingOverlay() }
        if let overlay {
            capture.onLevel = { level in overlay.pushLevel(level) }
        }
        let dumpWav = self.dumpWav

        var box: TranscriberBox?

        func startDictation(model: TranscriptionModel, transcriber: Transcriber) {
            MainActor.assumeIsolated { menuBar.updateModel(model.id) }
            let liveBox = MainActor.assumeIsolated { () -> TranscriberBox in
                if let existing = box {
                    existing.switchTo(transcriber, modelID: model.id)
                    return existing
                }
                let newBox = TranscriberBox(transcriber: transcriber, modelID: model.id)
                box = newBox
                menuBar.attachModelSwitcher(box: newBox)
                menuBar.onModelNeedsDownload = { downloadModel in
                    mainWindow.showDownload(model: downloadModel, box: newBox) {
                        menuBar.updateModel(downloadModel.id)
                    }
                }
                return newBox
            }
            do {
                try attachDictationHandlers(
                    monitor: monitor, capture: capture, overlay: overlay,
                    menuBar: menuBar, box: liveBox, dumpWav: dumpWav
                )
                FileHandle.standardError.write(Data("listening on fn hold · model: \(model.id)\n".utf8))
            } catch {
                // Don't exit — permission may have been revoked after the
                // fact. Re-show onboarding instead of silently disappearing.
                FileHandle.standardError.write(Data("failed to register hotkey tap: \(error)\n".utf8))
                MainActor.assumeIsolated { onboarding.show() }
            }
        }

        MainActor.assumeIsolated {
            // `box == nil` guards against a real bug, not a hypothetical
            // one: HotkeyMonitor.start() creates a brand-new CGEventTap on
            // every call rather than replacing the previous one (checked
            // directly — it never invalidates an existing tap first), so
            // calling startDictation again on a Phase 5c "Run Onboarding
            // Again" replay would double-process every hotkey press, the
            // same failure mode Quill.swift's own SingleInstance guard
            // exists to prevent for two separate processes. The first,
            // real setup still needs to run exactly once, which this
            // still does.
            onboarding.onFinished = {
                guard box == nil, let model = state.selectedModel, let t = state.warmedTranscriber else { return }
                startDictation(model: model, transcriber: t)
            }
        }

        let readyModel: TranscriptionModel? = MainActor.assumeIsolated {
            state.isReady ? state.selectedModel : nil
        }
        if let model = readyModel {
            // Already configured from a previous run: model's on disk, just
            // needs loading into memory — no window needed.
            let transcriber = TranscriberFactory.make(for: model)
            Task { @MainActor in
                do {
                    try await transcriber.warmUp()
                    startDictation(model: model, transcriber: transcriber)
                } catch {
                    FileHandle.standardError.write(Data("warmup failed: \(error)\n".utf8))
                    onboarding.show()
                }
            }
        } else {
            MainActor.assumeIsolated { onboarding.show() }
        }

        installSigintHandler(monitor: monitor)
        app.run()
    }

    private func installSigintHandler(monitor: HotkeyMonitor) {
        let sigint = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        sigint.setEventHandler {
            FileHandle.standardError.write(Data("\nshutting down\n".utf8))
            monitor.stop()
            NSApp.terminate(nil)
        }
        sigint.resume()
        signal(SIGINT, SIG_IGN)
    }
}

/// Wires up the press/release hotkey handler shared by both the
/// already-configured (LaunchAgent) path and the onboarding path — capture
/// audio, show recording state, transcribe on release, inject the result.
private func attachDictationHandlers(
    monitor: HotkeyMonitor,
    capture: AudioCapture,
    overlay: RecordingOverlay?,
    menuBar: MenuBarController,
    box: TranscriberBox,
    dumpWav: Bool
) throws {
    // Phase 5f: whether a hotkey press starts+finishes a dictation across
    // two taps (`.toggle`) or the original hold-and-release (`.hold`) is
    // just a matter of which of these two the .pressed/.released events
    // below call, and when — the recording/transcribing logic itself
    // doesn't change between the two modes.
    func beginRecording() {
        do {
            try capture.start()
            FileHandle.standardError.write(Data("● recording\n".utf8))
            MainActor.assumeIsolated {
                overlay?.show(.recording)
                menuBar.setRecording(true)
            }
        } catch {
            FileHandle.standardError.write(Data("capture failed: \(error)\n".utf8))
        }
    }

    func finishRecording() {
        let samples = capture.stop()
        MainActor.assumeIsolated {
            overlay?.show(.transcribing)
            menuBar.setTranscribing()
        }
        let seconds = Double(samples.count) / AudioCapture.targetSampleRate
        let rms = computeRMS(samples)
        FileHandle.standardError.write(Data(
            String(format: "○ captured %.2fs · rms %.3f\n", seconds, rms).utf8
        ))
        if dumpWav, !samples.isEmpty {
            let path = "/tmp/quill-last.wav"
            do {
                try WAVWriter.write(samples: samples, sampleRate: 16_000, to: path)
                FileHandle.standardError.write(Data("  wrote \(path)\n".utf8))
            } catch {
                FileHandle.standardError.write(Data("  wav write failed: \(error)\n".utf8))
            }
        }
        guard !samples.isEmpty else {
            MainActor.assumeIsolated {
                overlay?.hide()
                menuBar.setRecording(false)
            }
            return
        }
        Task {
            let started = Date()
            let (transcriberNow, modelIDNow) = await MainActor.run { (box.current, box.modelID) }
            do {
                let rawText = try await transcriberNow.transcribe(samples)
                let elapsed = Date().timeIntervalSince(started)
                FileHandle.standardError.write(Data(
                    String(format: "→ %.2fs · %@\n", elapsed, rawText).utf8
                ))

                // Auto Cleanup runs on every dictation automatically —
                // that's the point (a one-time setting in Style, not a
                // per-dictation decision). Light is local/instant;
                // Medium calls out to the user's own Style API key, so
                // show a "polishing…" beat instead of looking stuck.
                let level = QuillSettings.autoCleanupLevel
                if level != .none {
                    await MainActor.run {
                        overlay?.show(.polishing)
                        menuBar.setPolishing()
                    }
                }
                let finalText = await AutoCleanup.apply(rawText, level: level)

                await MainActor.run {
                    // Text Formatting runs last, after Auto Cleanup, and
                    // reads the focused app's actual cursor context — has
                    // to happen right here, immediately before injection,
                    // not earlier in the pipeline where focus could in
                    // theory have moved on.
                    let injectedText = TextFormatting.apply(finalText)
                    TextInjector.inject(injectedText)
                    overlay?.hide()
                    menuBar.setRecording(false)
                    DictationHistory.append(
                        text: injectedText, rawText: rawText,
                        model: modelIDNow, durationSeconds: seconds
                    )
                }
            } catch {
                FileHandle.standardError.write(Data("transcription failed: \(error)\n".utf8))
                await MainActor.run {
                    overlay?.hide()
                    menuBar.setRecording(false)
                }
            }
        }
    }

    // Toggle mode's own recording flag — separate from AudioCapture's
    // internal state, since this only needs to answer "did the last press
    // start a recording or stop one," which .hold mode never needs to ask
    // (press and release are already unambiguous there).
    var isTogglingRecording = false

    // .automatic's state: whether a recording is currently open, and — only
    // while that recording is still waiting on its *own* first release —
    // when it started. Once that first release has resolved the gesture
    // (hold vs. tap), `pressStartedAt` goes back to nil and any further
    // press is unambiguously "the second tap that stops a toggle."
    var isAutoRecording = false
    var autoPressStartedAt: Date?

    try monitor.start { event in
        switch QuillSettings.activationMode {
        case .hold:
            switch event {
            case .pressed: beginRecording()
            case .released: finishRecording()
            }

        case .toggle:
            // Every press flips state; releases are ignored entirely —
            // in a tap gesture the key comes back up almost immediately,
            // and .hold's release-driven finish would end the recording
            // before the user had a chance to actually speak.
            guard event == .pressed else { return }
            if isTogglingRecording {
                isTogglingRecording = false
                finishRecording()
            } else {
                isTogglingRecording = true
                beginRecording()
            }

        case .automatic:
            // Accepts both gestures on the same hotkey: a quick tap starts
            // a recording that a second tap later stops (like .toggle); a
            // press held past `automaticHoldThreshold` and then released
            // stops on that release instead (like .hold, walkie-talkie
            // style). The two can't be told apart at press time — only the
            // release (or a second press, for the tap case) resolves it.
            switch event {
            case .pressed:
                if !isAutoRecording {
                    isAutoRecording = true
                    autoPressStartedAt = Date()
                    beginRecording()
                } else if autoPressStartedAt == nil {
                    // A toggle-started recording is already open and its
                    // starting press was already resolved as a tap — this
                    // press is the second tap that ends it.
                    isAutoRecording = false
                    finishRecording()
                }
                // else: still physically holding the very press that
                // started this recording — nothing to do until release.
            case .released:
                guard let startedAt = autoPressStartedAt else { return }
                autoPressStartedAt = nil
                if Date().timeIntervalSince(startedAt) >= ActivationMode.automaticHoldThreshold {
                    // Held long enough to read as a deliberate hold — stop
                    // now, same as .hold's release.
                    isAutoRecording = false
                    finishRecording()
                }
                // else: that was a quick tap — leave the recording open,
                // waiting for a second tap to stop it, same as .toggle.
            }
        }
    }
}

struct Doctor: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Check microphone, accessibility, and Fn key configuration."
    )

    func run() throws {
        let checks = DoctorReport.run()
        DoctorReport.print(checks)
        if !DoctorReport.allOK(checks) {
            throw ExitCode(1)
        }
    }
}

struct Models: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Manage transcription models.",
        subcommands: [List.self, Download.self]
    )

    struct List: ParsableCommand {
        func run() throws {
            for m in ModelRegistry.shared {
                let star = m.recommended ? "★" : " "
                let id = m.id.padding(toLength: 26, withPad: " ", startingAt: 0)
                let langs = "[\(m.languages.joined(separator: ","))]"
                    .padding(toLength: 9, withPad: " ", startingAt: 0)
                let size = String(format: "%5d MB", m.sizeMB)
                print("\(star) \(id) \(size)  \(langs)  \(m.displayName)")
            }
        }
    }

    struct Download: ParsableCommand {
        @Argument(help: "Model id to download.") var id: String

        func run() throws {
            guard let m = ModelRegistry.find(id) else {
                print("unknown model: \(id)")
                throw ExitCode(1)
            }
            let t = TranscriberFactory.make(for: m)

            let sem = DispatchSemaphore(value: 0)
            var capturedError: Error?
            Task.detached {
                do { try await t.warmUp() } catch { capturedError = error }
                sem.signal()
            }
            sem.wait()
            if let e = capturedError { throw e }
        }
    }
}

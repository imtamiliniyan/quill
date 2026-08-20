import SwiftUI


struct OnboardingView: View {
    @ObservedObject var state: OnboardingState
    var onFinished: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            header

            switch state.step {
            case .permissions:
                PermissionsStep(state: state)
            case .modelPicker:
                ModelPickerStep(state: state)
            case .downloading:
                DownloadingStep(state: state)
            case .localAI:
                LocalAIStep(state: state)
            case .done:
                DoneStep(onFinished: onFinished)
            }

            Spacer()
        }
        .padding(28)
        .frame(width: 480, height: 620)
        .background(Theme.background)
        .foregroundColor(Theme.textPrimary)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Quill")
                .font(.system(size: 22, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.top, 8)
    }

    private var subtitle: String {
        switch state.step {
        case .permissions: return "A couple of permissions, then you're set."
        case .modelPicker: return "Pick a transcription model."
        case .downloading: return "Downloading your model…"
        case .localAI: return "One more thing (optional)."
        case .done: return "All set."
        }
    }
}

// MARK: - Permissions

/// Phase 5c: a real two-step checklist, not two independently-actionable
/// rows shown at once — Accessibility stays visually locked until
/// Microphone is actually granted, with an explicit "Needed"/"Ready"
/// badge per step, matching the same wording Settings' Getting Started
/// tab uses for the same two checks.
private struct PermissionsStep: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        VStack(spacing: 16) {
            PermissionRow(
                step: 1,
                title: "Microphone",
                detail: "Needed to hear you while you hold the hotkey.",
                granted: state.micGranted,
                locked: false,
                actionTitle: "Allow Microphone",
                action: state.requestMicrophone,
                showLiveMeter: true
            )
            PermissionRow(
                step: 2,
                title: "Accessibility",
                detail: "Needed to detect the hotkey and type text into whatever app you're focused on. macOS doesn't let apps grant this to themselves. Click below, then toggle Quill on in the list that opens.",
                granted: state.accessibilityGranted,
                locked: !state.micGranted,
                actionTitle: "Open Accessibility Settings",
                action: state.openAccessibilitySettings,
                showLiveMeter: false
            )
        }
    }
}

private struct PermissionRow: View {
    let step: Int
    let title: String
    let detail: String
    let granted: Bool
    /// True while an earlier step in the checklist isn't done yet — the
    /// row still shows what's coming, but its action button is disabled
    /// so nothing here reads as independently actionable out of order.
    let locked: Bool
    let actionTitle: String
    let action: () -> Void
    /// Phase 5b: live proof the mic is actually receiving audio, right
    /// next to "Ready" — only meaningful once `granted`, and only asked
    /// for on the Microphone row.
    let showLiveMeter: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(granted ? Theme.accent : Theme.textQuaternary)
                        .frame(width: 20, height: 20)
                    if granted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Theme.background)
                    } else {
                        Text("\(step)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(locked ? Theme.textTertiary : Theme.textPrimary)
                    }
                }
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(locked ? Theme.textTertiary : Theme.textPrimary)
                Spacer()
                if showLiveMeter && granted {
                    MicLevelMeter()
                }
                Text(granted ? "Ready" : "Needed")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(granted ? Theme.accent : Theme.textTertiary)
            }
            Text(detail)
                .font(.system(size: 12))
                .foregroundColor(locked ? Theme.textTertiary : Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if showLiveMeter && granted {
                Text("Speak to test: the bars respond to your voice in real time.")
                    .font(.system(size: 10.5))
                    .foregroundColor(Theme.textTertiary)
            }
            if !granted {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(locked)
                if locked {
                    Text("Complete microphone access first.")
                        .font(.system(size: 10.5))
                        .foregroundColor(Theme.textTertiary)
                }
            }
        }
        .padding(16)
        .background(Theme.textQuaternary)
        .cornerRadius(10)
    }
}

// MARK: - Model picker

private struct ModelPickerStep: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        VStack(spacing: 12) {
            // Scrollable, height-capped — the registry grew from 4 to 8
            // models and an un-capped VStack here was pushing Continue
            // below the fixed 480x620 onboarding window's visible area
            // (cropped off entirely, not just scrolled past). Capping the
            // list's own height keeps Continue always on screen
            // regardless of how many models the registry has, present or
            // future.
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(ModelRegistry.shared, id: \.id) { model in
                        ModelRow(
                            model: model,
                            selected: state.selectedModel?.id == model.id,
                            onSelect: { state.chooseModel(model) }
                        )
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: 380)

            Button("Continue") { state.beginDownload() }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(state.selectedModel == nil)
                .padding(.top, 8)
        }
    }
}

private struct ModelRow: View {
    let model: TranscriptionModel
    let selected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(selected ? Theme.accent : Theme.textTertiary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(model.displayName)
                            .font(.system(size: 14, weight: .medium))
                        if model.recommended {
                            Text("RECOMMENDED")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Theme.accent)
                        }
                    }
                    Text("\(model.sizeMB) MB · \(model.languages.joined(separator: ", "))")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
            }
            .padding(12)
            .background(selected ? Theme.fillHover : Theme.textQuaternary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Downloading

private struct DownloadingStep: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        VStack(spacing: 16) {
            Text(state.selectedModel?.displayName ?? "")
                .font(.system(size: 14, weight: .medium))
            if let progress = state.downloadProgress {
                ProgressView(value: progress)
                    .tint(Theme.accent)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            } else {
                ProgressView()
            }
            if let error = state.downloadError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                Button("Try Again") { state.beginDownload() }
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Theme.textQuaternary)
        .cornerRadius(10)
    }
}

// MARK: - Local AI

/// Offered once, right after the transcription model finishes — Quill's
/// own answer to FluidVoice's "one more thing" Fluid Intelligence screen,
/// but downloading Quill's own MLX/Llama model and routing into Quill's
/// own AutoCleanupLevel, not their runtime. Three ways out, all equally
/// visible: download it, use your own cloud key instead, or skip for now.
private struct LocalAIStep: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Clean up dictation automatically?")
                    .font(.system(size: 15, weight: .medium))
                Text(AutoCleanupLevel.localAI.summary)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Theme.textQuaternary)
            .cornerRadius(10)

            if let progress = state.localAIDownloadProgress, state.localAIDownloadError == nil {
                VStack(spacing: 10) {
                    ProgressView(value: progress)
                        .tint(Theme.accent)
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(Theme.textQuaternary)
                .cornerRadius(10)
            } else if let error = state.localAIDownloadError {
                VStack(spacing: 10) {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                    Button("Try Again") { state.beginLocalAIDownload() }
                        .buttonStyle(.bordered)
                    Button("Skip for now") { state.skipLocalAI() }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(Theme.textQuaternary)
                .cornerRadius(10)
            } else {
                VStack(spacing: 10) {
                    Button("Download & Enable (~1.8 GB)") { state.beginLocalAIDownload() }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                        .frame(maxWidth: .infinity)
                    Button("I'll use my own AI key instead") { state.useOwnAIKeyInstead() }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    Button("Skip for now") { state.skipLocalAI() }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
    }
}

// MARK: - Done

private struct DoneStep: View {
    var onFinished: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(Theme.accent)
            Text("Hold fn anywhere and start talking.")
                .font(.system(size: 14))
                .foregroundColor(Theme.textPrimary)
            Button("Start Dictating") { onFinished() }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
        }
    }
}

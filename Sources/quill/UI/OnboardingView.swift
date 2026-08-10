import SwiftUI

private let accent = Color(red: 181 / 255, green: 209 / 255, blue: 255 / 255)
private let bg = Color(red: 0.075, green: 0.078, blue: 0.086)

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
            case .done:
                DoneStep(onFinished: onFinished)
            }

            Spacer()
        }
        .padding(28)
        .frame(width: 480, height: 580)
        .background(bg)
        .foregroundColor(.white)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Quill")
                .font(.system(size: 22, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.top, 8)
    }

    private var subtitle: String {
        switch state.step {
        case .permissions: return "A couple of permissions, then you're set."
        case .modelPicker: return "Pick a transcription model."
        case .downloading: return "Downloading your model…"
        case .done: return "All set."
        }
    }
}

// MARK: - Permissions

private struct PermissionsStep: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        VStack(spacing: 16) {
            PermissionRow(
                title: "Microphone",
                detail: "Needed to hear you while you hold the hotkey.",
                granted: state.micGranted,
                actionTitle: "Allow Microphone",
                action: state.requestMicrophone
            )
            PermissionRow(
                title: "Accessibility",
                detail: "Needed to detect the hotkey and type text into whatever app you're focused on. macOS doesn't let apps grant this to themselves — click below, then toggle Quill on in the list that opens.",
                granted: state.accessibilityGranted,
                actionTitle: "Open Accessibility Settings",
                action: state.openAccessibilitySettings
            )
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let granted: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(granted ? accent : .white.opacity(0.4))
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                Spacer()
            }
            Text(detail)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
            if !granted {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
}

// MARK: - Model picker

private struct ModelPickerStep: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        VStack(spacing: 12) {
            ForEach(ModelRegistry.shared, id: \.id) { model in
                ModelRow(
                    model: model,
                    selected: state.selectedModel?.id == model.id,
                    onSelect: { state.chooseModel(model) }
                )
            }
            Button("Continue") { state.beginDownload() }
                .buttonStyle(.borderedProminent)
                .tint(accent)
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
                    .foregroundColor(selected ? accent : .white.opacity(0.4))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(model.displayName)
                            .font(.system(size: 14, weight: .medium))
                        if model.recommended {
                            Text("RECOMMENDED")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(accent)
                        }
                    }
                    Text("\(model.sizeMB) MB · \(model.languages.joined(separator: ", "))")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
            }
            .padding(12)
            .background(selected ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
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
                    .tint(accent)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
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
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
}

// MARK: - Done

private struct DoneStep: View {
    var onFinished: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(accent)
            Text("Hold fn anywhere and start talking.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
            Button("Start Dictating") { onFinished() }
                .buttonStyle(.borderedProminent)
                .tint(accent)
        }
    }
}

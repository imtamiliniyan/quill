import ApplicationServices
import AVFoundation
import SwiftUI

/// A real sidebar tab (peer to Dictation/Insights/Style), not tucked
/// inside Settings — matches where FluidVoice actually keeps this, in its
/// own persistent sidebar, once there was a real reason to add that shell
/// to Quill's main window rather than settle for the Settings-tab
/// approximation this replaced. A status recap reachable anytime, not
/// just at first run, plus a way to replay onboarding on purpose.
///
/// Deliberately no Test Playground yet — that needs the same
/// live-transcript mechanism Phase 5d's dictation overlay builds; a
/// one-off recording flow just for this page would duplicate that work
/// instead of reusing it once it exists.
struct GettingStartedView: View {
    let onRunOnboardingAgain: () -> Void

    @State private var micGranted = false
    @State private var accessibilityGranted = false
    @State private var modelReady = false
    @State private var localAIReady = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Getting Started")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, Theme.pagePadding)
                .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Quick setup")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                            Button {
                                onRunOnboardingAgain()
                            } label: {
                                Label("Run Onboarding Again", systemImage: "arrow.counterclockwise")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.bordered)
                        }
                        Text("Talk anywhere. Quill types for you.")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)

                        VStack(spacing: 8) {
                            checklistRow(
                                title: "Microphone access",
                                detail: "Needed to hear you while you dictate.",
                                ready: micGranted
                            )
                            checklistRow(
                                title: "Accessibility access",
                                detail: "Needed to type into whatever app you're focused on.",
                                ready: accessibilityGranted
                            )
                            checklistRow(
                                title: "Transcription model",
                                detail: "A model is selected and downloaded.",
                                ready: modelReady
                            )
                            checklistRow(
                                title: "Local AI (optional)",
                                detail: "Free tone/grammar rewrite, no key needed.",
                                ready: localAIReady,
                                optional: true
                            )
                        }
                    }
                    .padding(18)
                    .quillCard()

                    Label("Hold fn anywhere and start talking.", systemImage: "mic.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear(perform: refresh)
    }

    private func refresh() {
        micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        accessibilityGranted = AXIsProcessTrusted()
        modelReady = QuillSettings.selectedModelID.flatMap(ModelRegistry.find).map(ModelAvailability.isDownloaded) ?? false
        localAIReady = QuillSettings.autoCleanupLevel == .localAI && LocalEnhancer.isDownloaded()
    }

    private func checklistRow(title: String, detail: String, ready: Bool, optional: Bool = false) -> some View {
        HStack(spacing: 10) {
            Image(systemName: ready ? "checkmark.circle.fill" : (optional ? "circle" : "exclamationmark.circle"))
                .font(.system(size: 14))
                .foregroundColor(ready ? Theme.accent : (optional ? Theme.textTertiary : .orange))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundColor(Theme.textTertiary)
            }
            Spacer()
            Text(ready ? "Ready" : (optional ? "Not set up" : "Needed"))
                .font(.system(size: 9.5, weight: .bold))
                .foregroundColor(ready ? Theme.accent : (optional ? Theme.textTertiary : .orange))
        }
        .padding(10)
        .background(Theme.textQuaternary)
        .cornerRadius(8)
    }
}

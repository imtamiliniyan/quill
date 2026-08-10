import SwiftUI

struct ModelDownloadView: View {
    @ObservedObject var state: ModelDownloadState

    var body: some View {
        VStack(spacing: 16) {
            Text(state.done ? "Switched" : "Downloading")
                .font(.system(size: 16, weight: .semibold))
            Text(state.model?.displayName ?? "")
                .font(.system(size: 13))
                .foregroundColor(Theme.textPrimary)

            if state.done {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(Theme.accent)
            } else if let progress = state.progress {
                ProgressView(value: progress)
                    .tint(Theme.accent)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            } else {
                ProgressView()
            }

            if let error = state.error {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                Button("Try Again") { state.retry() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(28)
        .frame(width: 420, height: 320)
        .background(Theme.background)
        .foregroundColor(Theme.textPrimary)
    }
}

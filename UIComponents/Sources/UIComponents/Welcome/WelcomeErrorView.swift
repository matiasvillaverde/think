import SwiftUI

/// Error view component for WelcomeView
internal struct WelcomeErrorView: View {
    let error: Error
    let loadAttempts: Int
    let onRetry: () async -> Void

    var body: some View {
        VStack(spacing: WelcomeConstants.spacingLarge) {
            errorIcon
            errorMessage
            retrySection
        }
        .padding()
        .frame(maxHeight: WelcomeConstants.maxScrollHeight)
    }

    @ViewBuilder private var errorIcon: some View {
        Image(systemName: "exclamationmark.triangle")
            .font(.system(size: WelcomeConstants.iconSizeLarge))
            .foregroundColor(.iconAlert)
            .accessibilityHidden(true)
    }

    @ViewBuilder private var errorMessage: some View {
        VStack(spacing: WelcomeConstants.spacingSmall) {
            Text("Failed to Load Models", bundle: .module)
                .font(.headline)
                .foregroundColor(.textPrimary)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder private var retrySection: some View {
        if loadAttempts < WelcomeConstants.maxLoadAttempts {
            Button {
                Task {
                    await onRetry()
                }
            } label: {
                Label(
                    String(localized: "Retry", bundle: .module),
                    systemImage: "arrow.clockwise"
                )
                .font(.footnote)
            }
            .buttonStyle(.bordered)
        } else {
            Text("Maximum retry attempts reached", bundle: .module)
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
    }
}

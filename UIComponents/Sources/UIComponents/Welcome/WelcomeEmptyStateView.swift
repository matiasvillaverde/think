import SwiftUI

/// Empty state view for when no language models are available
internal struct WelcomeEmptyStateView: View {
    var body: some View {
        VStack(spacing: WelcomeConstants.spacingLarge) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: WelcomeConstants.iconSizeLarge))
                .foregroundColor(.textSecondary)
                .accessibilityHidden(true)

            VStack(spacing: WelcomeConstants.spacingSmall) {
                Text("No Compatible Language Models", bundle: .module)
                    .font(.headline)
                    .foregroundColor(.textPrimary)

                Text("No language models are compatible with your device", bundle: .module)
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxHeight: WelcomeConstants.maxScrollHeight)
    }
}

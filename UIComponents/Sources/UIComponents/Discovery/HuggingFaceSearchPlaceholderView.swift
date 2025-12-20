import SwiftUI

/// Placeholder view for HuggingFace search
internal struct HuggingFaceSearchPlaceholderView: View {
    private enum Constants {
        static let iconSize: CGFloat = 60
    }

    internal var body: some View {
        VStack(spacing: DesignConstants.Spacing.large) {
            Image(systemName: "sparkles")
                .font(.system(size: Constants.iconSize))
                .foregroundStyle(Color.secondary)
                .accessibilityLabel("Sparkles icon")

            Text("Search HuggingFace", bundle: .module)
                .font(.headline)
                .foregroundColor(.textPrimary)

            Text(
                "Find and download any public model from HuggingFace",
                bundle: .module
            )
            .font(.subheadline)
            .foregroundColor(.textSecondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

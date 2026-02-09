import SwiftUI

/// Empty results view for HuggingFace search
internal struct HuggingFaceSearchEmptyView: View {
    private enum Constants {
        static let iconSize: CGFloat = 60
    }

    internal var body: some View {
        VStack(spacing: DesignConstants.Spacing.large) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: Constants.iconSize))
                .foregroundStyle(Color.textSecondary)
                .accessibilityLabel("Search icon")

            Text("No models found", bundle: .module)
                .font(.headline)
                .foregroundColor(.textPrimary)

            Text(
                "Try a different search term or adjust your filters",
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

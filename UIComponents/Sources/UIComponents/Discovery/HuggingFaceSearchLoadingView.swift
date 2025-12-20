import SwiftUI

/// Loading view for HuggingFace search
internal struct HuggingFaceSearchLoadingView: View {
    private enum Constants {
        static let scaleEffectMultiplier: CGFloat = 1.5
    }

    internal var body: some View {
        VStack(spacing: DesignConstants.Spacing.large) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(Constants.scaleEffectMultiplier)

            Text("Searching HuggingFace...", bundle: .module)
                .font(.headline)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

import SwiftUI

/// Error view for HuggingFace search
internal struct HuggingFaceSearchErrorView: View {
    let error: Error
    let onRetry: () -> Void

    private enum Constants {
        static let iconSize: CGFloat = 60
    }

    internal var body: some View {
        VStack(spacing: DesignConstants.Spacing.large) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: Constants.iconSize))
                .foregroundColor(.iconAlert)
                .accessibilityLabel(Text("Error icon", bundle: .module))

            Text("Search failed", bundle: .module)
                .font(.headline)
                .foregroundColor(.textPrimary)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                onRetry()
            } label: {
                Label {
                    Text("Retry", bundle: .module)
                } icon: {
                    Image(systemName: "arrow.clockwise")
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

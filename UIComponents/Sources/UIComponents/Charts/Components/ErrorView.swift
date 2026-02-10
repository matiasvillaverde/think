import SwiftUI

// MARK: - Constants

private enum ErrorViewConstants {
    static let iconSize: CGFloat = 48
    static let spacing: CGFloat = 20
    static let padding: CGFloat = 40
}

// MARK: - Error View

/// Display error state with retry option
public struct ErrorView: View {
    let error: Error
    let retry: () -> Void

    public var body: some View {
        VStack(spacing: ErrorViewConstants.spacing) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: ErrorViewConstants.iconSize))
                .foregroundColor(.orange)
                .accessibilityLabel(Text("Error icon", bundle: .module))

            Text("Failed to Load Metrics", bundle: .module)
                .font(.headline)

            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: retry) {
                Label {
                    Text("Retry", bundle: .module)
                } icon: {
                    Image(systemName: "arrow.clockwise")
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(ErrorViewConstants.padding)
    }
}

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
                .accessibilityLabel("Error icon")

            Text("Failed to Load Metrics")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: retry) {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(ErrorViewConstants.padding)
    }
}

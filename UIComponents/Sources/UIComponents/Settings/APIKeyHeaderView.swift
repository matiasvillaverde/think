import SwiftUI

// MARK: - API Key Header View

/// Header section for API key settings.
internal struct APIKeyHeaderView: View {
    private enum Constants {
        static let spacing: CGFloat = 8
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.spacing) {
            Text(
                String(
                    localized: "API Keys",
                    bundle: .module,
                    comment: "Title for API key settings section"
                )
            )
            .font(.title2)
            .fontWeight(.bold)

            Text(
                String(
                    localized: "Configure API keys to use remote AI models.",
                    bundle: .module,
                    comment: "Description for API key settings"
                )
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

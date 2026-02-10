import Abstractions
import SwiftUI

// MARK: - Model License Section

internal struct DiscoveryModelLicenseSection: View {
    let model: DiscoveredModel

    var body: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.medium) {
            Text("License", bundle: .module)
                .font(.headline)
                .foregroundColor(.textPrimary)

            HStack {
                Text(
                    model.license ?? String(localized: "Unknown", bundle: .module)
                )
                    .font(.body)
                    .foregroundColor(.textPrimary)

                Spacer()

                if let licenseUrl = model.licenseUrl,
                    let url = URL(string: licenseUrl) {
                    Link(destination: url) {
                        Image(systemName: "arrow.up.right.circle")
                            .foregroundColor(.accentColor)
                    }
                    .accessibilityLabel(Text("View license details", bundle: .module))
                }
            }
        }
    }
}

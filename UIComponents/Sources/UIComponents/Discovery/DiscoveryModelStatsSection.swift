import Abstractions
import SwiftUI

// MARK: - Model Stats Section

internal struct DiscoveryModelStatsSection: View {
    let model: DiscoveredModel

    var body: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.medium) {
            Text("Statistics", bundle: .module)
                .font(.headline)
                .foregroundColor(.textPrimary)

            HStack(spacing: DesignConstants.Spacing.large) {
                statItem(
                    icon: "arrow.down.circle",
                    value: formatNumber(model.downloads),
                    label: "Downloads"
                )

                Spacer()

                statItem(
                    icon: "heart",
                    value: formatNumber(model.likes),
                    label: "Likes"
                )

                Spacer()

                if model.totalSize > 0 {
                    statItem(
                        icon: "doc",
                        value: formatFileSize(model.totalSize),
                        label: "Size"
                    )
                }
            }
        }
    }

    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: DesignConstants.Spacing.small) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .accessibilityLabel(label)

            Text(value)
                .font(.headline)
                .foregroundColor(.textPrimary)

            Text(LocalizedStringKey(label), bundle: .module)
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter: NumberFormatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(for: number) ?? "\(number)"
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter: ByteCountFormatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

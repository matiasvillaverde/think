import SwiftUI

internal struct ContextUtilizationStats: View {
    let contextData: [ContextData]
    let viewModel: ContextUtilizationViewModel

    private enum Constants {
        static let verticalSpacing: CGFloat = 2
    }

    var body: some View {
        HStack(spacing: ChartConstants.Layout.sectionSpacing) {
            averageUtilizationView
            peakUtilizationView
            trendDirectionView
            Spacer()
        }
    }

    private var averageUtilizationView: some View {
        VStack(alignment: .leading, spacing: Constants.verticalSpacing) {
            Text("Average")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(String(format: "%.1f%%", viewModel.averageUtilization(for: contextData)))
                .font(.subheadline.weight(.bold))
                .foregroundColor(.primary)
        }
    }

    private var peakUtilizationView: some View {
        VStack(alignment: .leading, spacing: Constants.verticalSpacing) {
            Text("Peak")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(String(format: "%.1f%%", viewModel.peakUtilization(for: contextData)))
                .font(.subheadline.weight(.bold))
                .foregroundColor(
                    viewModel.utilizationColor(for: viewModel.peakUtilization(for: contextData))
                )
        }
    }

    private var trendDirectionView: some View {
        VStack(alignment: .leading, spacing: Constants.verticalSpacing) {
            Text("Trend")
                .font(.caption)
                .foregroundColor(.secondary)

            let trend: ContextUtilizationViewModel.TrendDirection = viewModel
                .trendDirection(for: contextData)
            HStack(spacing: Constants.verticalSpacing) {
                Image(systemName: trend.icon)
                    .font(.caption.weight(.bold))
                    .accessibilityLabel("Trend: \(trendText(for: trend))")
                Text(trendText(for: trend))
                    .font(.caption.weight(.medium))
            }
            .foregroundColor(trend.color)
        }
    }

    private func trendText(for trend: ContextUtilizationViewModel.TrendDirection) -> String {
        switch trend {
        case .increasing:
            "Rising"

        case .decreasing:
            "Falling"

        case .stable:
            "Stable"
        }
    }
}

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
            Text("Average", bundle: .module)
                .font(.caption)
                .foregroundColor(Color.textSecondary)
            Text(String(format: "%.1f%%", viewModel.averageUtilization(for: contextData)))
                .font(.subheadline.weight(.bold))
                .foregroundColor(Color.textPrimary)
        }
    }

    private var peakUtilizationView: some View {
        VStack(alignment: .leading, spacing: Constants.verticalSpacing) {
            Text("Peak", bundle: .module)
                .font(.caption)
                .foregroundColor(Color.textSecondary)
            Text(String(format: "%.1f%%", viewModel.peakUtilization(for: contextData)))
                .font(.subheadline.weight(.bold))
                .foregroundColor(
                    viewModel.utilizationColor(for: viewModel.peakUtilization(for: contextData))
                )
        }
    }

    private var trendDirectionView: some View {
        VStack(alignment: .leading, spacing: Constants.verticalSpacing) {
            Text("Trend", bundle: .module)
                .font(.caption)
                .foregroundColor(Color.textSecondary)

            let trend: ContextUtilizationViewModel.TrendDirection = viewModel
                .trendDirection(for: contextData)
            HStack(spacing: Constants.verticalSpacing) {
                Image(systemName: trend.icon)
                    .font(.caption.weight(.bold))
                    .accessibilityLabel(
                        Text("Trend: \(trendText(for: trend))", bundle: .module)
                    )
                Text(trendText(for: trend))
                    .font(.caption.weight(.medium))
            }
            .foregroundColor(trend.color)
        }
    }

    private func trendText(for trend: ContextUtilizationViewModel.TrendDirection) -> String {
        switch trend {
        case .increasing:
            return String(localized: "Rising", bundle: .module)

        case .decreasing:
            return String(localized: "Falling", bundle: .module)

        case .stable:
            return String(localized: "Stable", bundle: .module)
        }
    }
}

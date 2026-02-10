import SwiftUI

internal struct RepetitionRateStats: View {
    let repetitionData: [RepetitionData]
    let viewModel: RepetitionRateViewModel

    private enum Constants {
        static let spacingConstant: CGFloat = 2
        static let statsSpacing: CGFloat = 2
        static let percentageMultiplier: Double = 100.0
    }

    var body: some View {
        HStack(spacing: ChartConstants.Layout.sectionSpacing) {
            averageRateStat
            peakRateStat
            trendIndicatorStat
            Spacer()
        }
    }

    private var averageRateStat: some View {
        VStack(alignment: .leading, spacing: Constants.spacingConstant) {
            Text("Average", bundle: .module)
                .font(.caption)
                .foregroundColor(Color.textSecondary)

            let average: Double = viewModel.averageRate(for: repetitionData)
            Text(String(format: "%.1f%%", average * Constants.percentageMultiplier))
                .font(.subheadline.weight(.bold))
                .foregroundColor(viewModel.rateColor(for: average))
        }
    }

    private var peakRateStat: some View {
        VStack(alignment: .leading, spacing: Constants.spacingConstant) {
            Text("Peak", bundle: .module)
                .font(.caption)
                .foregroundColor(Color.textSecondary)

            let peak: Double = viewModel.peakRate(for: repetitionData)
            Text(String(format: "%.1f%%", peak * Constants.percentageMultiplier))
                .font(.subheadline.weight(.bold))
                .foregroundColor(viewModel.rateColor(for: peak))
        }
    }

    private var trendIndicatorStat: some View {
        VStack(alignment: .leading, spacing: Constants.statsSpacing) {
            Text("Trend", bundle: .module)
                .font(.caption)
                .foregroundColor(Color.textSecondary)

            let trend: TrendDirection = viewModel.trendDirection(for: repetitionData)
            HStack(spacing: Constants.statsSpacing) {
                Image(systemName: trend.icon)
                    .font(.caption.weight(.bold))
                    .foregroundColor(trend.color)
                    .accessibilityLabel(Text("Trend direction", bundle: .module))
                Text(trend.text)
                    .font(.caption.weight(.bold))
                    .foregroundColor(trend.color)
            }
        }
    }
}

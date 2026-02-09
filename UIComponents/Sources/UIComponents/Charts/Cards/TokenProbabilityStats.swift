import SwiftUI

internal struct TokenProbabilityStats: View {
    let filteredProbabilities: [TokenProbability]
    let viewModel: TokenProbabilityViewModel

    private enum Constants {
        static let statsSpacing: CGFloat = 2
        static let percentageMultiplier: Double = 100
        static let highThreshold: Double = 0.7
        static let exponentialPower: Double = 2.0
    }

    var body: some View {
        HStack(spacing: ChartConstants.Layout.sectionSpacing) {
            averageProbabilityView
            highConfidenceView
            uncertaintyScoreView
            Spacer()
        }
    }

    private var averageProbabilityView: some View {
        VStack(alignment: .leading, spacing: Constants.statsSpacing) {
            Text("Average")
                .font(.caption)
                .foregroundColor(Color.textSecondary)
            let avgProb: Double = viewModel.averageProbability(for: filteredProbabilities)
            Text(String(format: "%.1f%%", avgProb * Constants.percentageMultiplier))
                .font(.subheadline.weight(.bold))
                .foregroundColor(Color.textPrimary)
        }
    }

    private var highConfidenceView: some View {
        VStack(alignment: .leading, spacing: Constants.statsSpacing) {
            Text("High Conf")
                .font(.caption)
                .foregroundColor(Color.textSecondary)
            let percentage: Double = viewModel.highConfidencePercentage(
                for: filteredProbabilities,
                highThreshold: Constants.highThreshold,
                percentageMultiplier: Constants.percentageMultiplier
            )
            Text(String(format: "%.0f%%", percentage))
                .font(.subheadline.weight(.bold))
                .foregroundColor(.green)
        }
    }

    private var uncertaintyScoreView: some View {
        VStack(alignment: .leading, spacing: Constants.statsSpacing) {
            Text("Uncertainty")
                .font(.caption)
                .foregroundColor(Color.textSecondary)
            let score: Double = viewModel.uncertaintyScore(
                for: filteredProbabilities,
                exponentialPower: Constants.exponentialPower
            )
            Text(String(format: "%.2f", score))
                .font(.subheadline.weight(.bold))
                .foregroundColor(.orange)
        }
    }
}

import SwiftUI

internal struct TokenProbabilityLegend: View {
    let viewModel: TokenProbabilityViewModel

    private enum Constants {
        static let legendCircleSize: CGFloat = 10
        static let legendSpacing: CGFloat = 4
        static let highProbThreshold: Double = 0.7
        static let lowProbThreshold: Double = 0.3
        static let mediumProb: Double = 0.5
        static let highOffset: Double = 0.1
    }

    var body: some View {
        HStack(spacing: ChartConstants.Layout.sectionSpacing) {
            legendItem(
                color: viewModel.probabilityColor(
                    for: Constants.highProbThreshold + Constants.highOffset,
                    highThreshold: Constants.highProbThreshold,
                    lowThreshold: Constants.lowProbThreshold
                ),
                label: "High (>70%)"
            )
            legendItem(
                color: viewModel.probabilityColor(
                    for: Constants.mediumProb,
                    highThreshold: Constants.highProbThreshold,
                    lowThreshold: Constants.lowProbThreshold
                ),
                label: "Medium (30-70%)"
            )
            legendItem(
                color: viewModel.probabilityColor(
                    for: Constants.lowProbThreshold - Constants.highOffset,
                    highThreshold: Constants.highProbThreshold,
                    lowThreshold: Constants.lowProbThreshold
                ),
                label: "Low (<30%)"
            )
            Spacer()
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: Constants.legendSpacing) {
            Circle()
                .fill(color)
                .frame(width: Constants.legendCircleSize, height: Constants.legendCircleSize)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

import SwiftUI

internal struct PerplexityHeatMapStats: View {
    let heatMapData: [[HeatMapCell]]
    let selectedCell: HeatMapCell?
    let viewModel: PerplexityHeatMapViewModel

    private enum Constants {
        static let selectedInfoSpacing: CGFloat = 4
        static let selectedCellSpacing: CGFloat = 8
        static let statsSpacing: CGFloat = 2
        static let dividerHeight: CGFloat = 30
    }

    var body: some View {
        HStack(spacing: ChartConstants.Layout.sectionSpacing) {
            averagePerplexityView
            rangeView

            if let cell = selectedCell {
                selectedCellInfo(cell: cell)
            }

            Spacer()
        }
    }

    private var averagePerplexityView: some View {
        VStack(alignment: .leading, spacing: Constants.statsSpacing) {
            Text("Average")
                .font(.caption)
                .foregroundColor(Color.textSecondary)
            Text(String(format: "%.3f", viewModel.averagePerplexity(for: heatMapData)))
                .font(.subheadline.weight(.bold))
                .foregroundColor(Color.textPrimary)
        }
    }

    private var rangeView: some View {
        VStack(alignment: .leading, spacing: Constants.statsSpacing) {
            Text("Range")
                .font(.caption)
                .foregroundColor(Color.textSecondary)
            Text(String(
                format: "%.3f - %.3f",
                viewModel.minPerplexity(for: heatMapData),
                viewModel.maxPerplexity(for: heatMapData)
            ))
                .font(.subheadline.weight(.bold))
                .foregroundColor(Color.textPrimary)
        }
    }

    private func selectedCellInfo(cell: HeatMapCell) -> some View {
        HStack(spacing: Constants.selectedCellSpacing) {
            Divider()
                .frame(height: Constants.dividerHeight)

            VStack(alignment: .leading, spacing: Constants.selectedInfoSpacing) {
                Text("Selected")
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
                HStack(spacing: Constants.selectedInfoSpacing) {
                    Text("[\(cell.row), \(cell.column)]")
                        .font(.caption.weight(.medium))
                    Text(String(format: "%.3f", cell.value))
                        .font(.caption.weight(.bold))
                }
                .foregroundColor(Color.textPrimary)
            }
        }
    }
}

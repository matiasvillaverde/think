import SwiftUI

internal struct PerformanceStats: View {
    let selectedMetrics: Set<PerformanceLineChart.PerformanceMetric>
    let timeRange: PerformanceLineChart.TimeRange
    let viewModel: PerformanceChartViewModel

    private enum Constants {
        static let legendCircleSize: CGFloat = 10
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ChartConstants.Layout.itemSpacing) {
            ForEach(
                selectedMetrics.sorted { $0.rawValue < $1.rawValue },
                id: \.self
            ) { metric in
                statRow(for: metric)
            }
        }
    }

    private func statRow(for metric: PerformanceLineChart.PerformanceMetric) -> some View {
        HStack {
            Circle()
                .fill(metric.color)
                .frame(width: Constants.legendCircleSize, height: Constants.legendCircleSize)

            Text(metric.rawValue)
                .font(.caption)
                .foregroundColor(Color.textSecondary)

            Spacer()

            if let latestValue = viewModel.getLatestValue(for: metric, timeRange: timeRange) {
                Text("\(viewModel.formatValue(latestValue, unit: metric.unit)) \(metric.unit)")
                    .font(.caption.weight(.medium))
                    .foregroundColor(Color.textPrimary)
            }
        }
    }
}

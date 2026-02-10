import SwiftUI

internal struct PerformanceLegend: View {
    @Binding var selectedMetrics: Set<PerformanceLineChart.PerformanceMetric>

    private enum Constants {
        static let legendCircleSize: CGFloat = 10
        static let legendSpacing: CGFloat = 4
        static let selectedOpacity: Double = 1.0
        static let deselectedOpacity: Double = 0.3
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ChartConstants.Layout.cardSpacing) {
                ForEach(PerformanceLineChart.PerformanceMetric.allCases) { metric in
                    Button {
                        toggleMetric(metric)
                    } label: {
                        HStack(spacing: Constants.legendSpacing) {
                            Circle()
                                .fill(metric.color)
                                .frame(
                                    width: Constants.legendCircleSize,
                                    height: Constants.legendCircleSize
                                )
                                .opacity(
                                    selectedMetrics.contains(metric)
                                        ? Constants.selectedOpacity
                                        : Constants.deselectedOpacity
                                )

                            Text(verbatim: "\(metric.displayName) (\(metric.unit))")
                                .font(.caption)
                                .foregroundColor(
                                    selectedMetrics.contains(metric) ? .primary : .secondary
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func toggleMetric(_ metric: PerformanceLineChart.PerformanceMetric) {
        withAnimation {
            if selectedMetrics.contains(metric) {
                selectedMetrics.remove(metric)
            } else {
                selectedMetrics.insert(metric)
            }
        }
    }
}

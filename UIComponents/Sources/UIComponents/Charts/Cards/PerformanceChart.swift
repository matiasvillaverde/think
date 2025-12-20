import Charts
import SwiftUI

internal struct PerformanceChart: View {
    let performanceData: [PerformanceLineChart.PerformanceData]
    let dataHasAppeared: Bool

    private enum Constants {
        static let lineWidth: CGFloat = 2
        static let symbolSize: CGFloat = 30
        static let backgroundOpacity: Double = 0.2
        static let backgroundOpacityQuarter: Double = 0.05
        static let borderWidth: CGFloat = 0.5
    }

    var body: some View {
        Chart(dataHasAppeared ? performanceData : []) { data in
            LineMark(
                x: .value("Time", data.date),
                y: .value(data.metric.rawValue, data.value),
                series: .value("Metric", data.metric.rawValue)
            )
            .foregroundStyle(data.metric.color)
            .lineStyle(StrokeStyle(lineWidth: Constants.lineWidth))
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("Time", data.date),
                y: .value(data.metric.rawValue, data.value)
            )
            .foregroundStyle(data.metric.color)
            .symbolSize(Constants.symbolSize)
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisValueLabel(format: .dateTime.hour().minute())
                AxisGridLine()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel()
                AxisGridLine()
            }
        }
        .chartLegend(.hidden)
        .chartPlotStyle { plotArea in
            plotArea
                .background(
                    Color.gray.opacity(Constants.backgroundOpacityQuarter)
                )
                .border(
                    Color.gray.opacity(Constants.backgroundOpacity),
                    width: Constants.borderWidth
                )
        }
        .frame(height: ChartConstants.Layout.chartHeight)
    }
}

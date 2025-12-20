import Charts
import SwiftUI

internal struct ContextUtilizationChart: View {
    let contextData: [ContextData]
    let showFillArea: Bool
    let showDataPoints: Bool
    @Binding var dataHasAppeared: Bool
    let viewModel: ContextUtilizationViewModel
    let chartHeight: CGFloat
    let animationDuration: Double
    let animationDelay: Double

    private enum Constants {
        static let lineWidth: CGFloat = 2
        static let pointSize: CGFloat = 6
        static let fillOpacity: Double = 0.3
        static let gridOpacity: Double = 0.2
        static let borderOpacity: Double = 0.2
        static let borderWidth: CGFloat = 0.5
        static let dashLength: CGFloat = 5
        static let dashSpacing: CGFloat = 3
        static let warningThreshold: Double = 80.0
        static let dangerThreshold: Double = 90.0
    }

    var body: some View {
        Chart(contextData) { data in
            chartContent(for: data)
            thresholdMarks
        }
        .frame(height: chartHeight)
        .chartYScale(domain: 0 ... 100)
        .chartYAxis {
            yAxisMarks
        }
        .chartXAxis {
            xAxisMarks
        }
        .chartPlotStyle { plotArea in
            plotArea
                .border(
                    Color.gray.opacity(Constants.borderOpacity),
                    width: Constants.borderWidth
                )
        }
        .animation(.easeInOut(duration: animationDuration), value: showFillArea)
        .animation(.easeInOut(duration: animationDuration), value: showDataPoints)
        .onAppear {
            withAnimation(.easeInOut(duration: animationDuration).delay(animationDelay)) {
                dataHasAppeared = true
            }
        }
    }

    @ChartContentBuilder
    private func chartContent(for data: ContextData) -> some ChartContent {
        if showFillArea {
            AreaMark(
                x: .value("Index", data.index),
                yStart: .value("Start", 0),
                yEnd: .value("Used", data.utilizationRate)
            )
            .foregroundStyle(
                viewModel.utilizationColor(for: data.utilizationRate)
                    .opacity(Constants.fillOpacity)
            )
            .opacity(dataHasAppeared ? 1 : 0)
        }

        LineMark(
            x: .value("Index", data.index),
            y: .value("Used", data.utilizationRate)
        )
        .foregroundStyle(viewModel.utilizationColor(for: data.utilizationRate))
        .lineStyle(StrokeStyle(lineWidth: Constants.lineWidth))
        .opacity(dataHasAppeared ? 1 : 0)

        if showDataPoints {
            PointMark(
                x: .value("Index", data.index),
                y: .value("Used", data.utilizationRate)
            )
            .foregroundStyle(viewModel.utilizationColor(for: data.utilizationRate))
            .symbolSize(Constants.pointSize * Constants.pointSize)
            .opacity(dataHasAppeared ? 1 : 0)
        }
    }

    @ChartContentBuilder private var thresholdMarks: some ChartContent {
        RuleMark(y: .value("Warning", Constants.warningThreshold))
            .foregroundStyle(Color.orange.opacity(Constants.fillOpacity))
            .lineStyle(StrokeStyle(
                lineWidth: Constants.borderWidth,
                dash: [Constants.dashLength, Constants.dashSpacing]
            ))

        RuleMark(y: .value("Danger", Constants.dangerThreshold))
            .foregroundStyle(Color.red.opacity(Constants.fillOpacity))
            .lineStyle(StrokeStyle(
                lineWidth: Constants.borderWidth,
                dash: [Constants.dashLength, Constants.dashSpacing]
            ))
    }

    private var yAxisMarks: some AxisContent {
        AxisMarks(position: .leading) { value in
            AxisGridLine(
                stroke: StrokeStyle(
                    lineWidth: Constants.borderWidth,
                    dash: [Constants.dashLength, Constants.dashSpacing]
                )
            )
            .foregroundStyle(Color.secondary.opacity(Constants.gridOpacity))

            AxisValueLabel {
                if let intValue = value.as(Int.self) {
                    Text("\(intValue)%")
                        .font(.caption)
                }
            }
        }
    }

    private var xAxisMarks: some AxisContent {
        AxisMarks { _ in
            AxisGridLine(
                stroke: StrokeStyle(
                    lineWidth: Constants.borderWidth,
                    dash: [Constants.dashLength, Constants.dashSpacing]
                )
            )
            .foregroundStyle(Color.secondary.opacity(Constants.gridOpacity))
            AxisValueLabel()
                .font(.caption)
        }
    }
}

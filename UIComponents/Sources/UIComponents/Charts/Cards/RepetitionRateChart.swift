import Charts
import SwiftUI

internal struct RepetitionRateChart: View {
    let repetitionData: [RepetitionData]
    let showTrend: Bool
    let showBaseline: Bool
    let dataHasAppeared: Bool
    let selectedNGram: NGramLevel
    let viewModel: RepetitionRateViewModel
    let chartHeight: CGFloat

    private enum Constants {
        static let lineWidth: CGFloat = 2
        static let pointSize: CGFloat = 50
        static let baselineOpacity: Double = 0.5
        static let baselineLineWidth: CGFloat = 1
        static let dashPatternLong: CGFloat = 5
        static let dashPatternShort: CGFloat = 5
        static let chartOpacity: Double = 0.05
        static let borderOpacity: Double = 0.2
        static let borderWidth: CGFloat = 0.5
        static let animationDuration: Double = 0.8
        static let animationDamping: Double = 0.8
        static let gradientOpacity: Double = 0.3
        static let gradientOpacityLight: Double = 0.05
        static let percentageMultiplier: Double = 100.0
    }

    var body: some View {
        Chart(repetitionData) { data in
            chartMarks(for: data)
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                AxisTick()
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let rate = value.as(Double.self) {
                        Text(String(format: "%.1f%%", rate * Constants.percentageMultiplier))
                    }
                }
                AxisGridLine()
            }
        }
        .chartYScale(domain: 0 ... 1)
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color.paletteGray.opacity(Constants.chartOpacity))
                .border(
                    Color.paletteGray.opacity(Constants.borderOpacity),
                    width: Constants.borderWidth
                )
        }
        .frame(height: chartHeight)
        .animation(
            .spring(
                response: Constants.animationDuration,
                dampingFraction: Constants.animationDamping
            ),
            value: dataHasAppeared
        )
        .animation(.easeInOut, value: selectedNGram)
        .animation(.easeInOut, value: showTrend)
        .animation(.easeInOut, value: showBaseline)
    }

    @ChartContentBuilder
    private func chartMarks(for data: RepetitionData) -> some ChartContent {
        LineMark(
            x: .value("Index", data.index),
            y: .value("Rate", dataHasAppeared ? data.rate : 0)
        )
        .foregroundStyle(.blue)
        .lineStyle(StrokeStyle(lineWidth: Constants.lineWidth))

        if showTrend {
            AreaMark(
                x: .value("Index", data.index),
                y: .value("Rate", dataHasAppeared ? data.rate : 0)
            )
            .foregroundStyle(.linearGradient(
                colors: [
                    .blue.opacity(Constants.gradientOpacity),
                    .blue.opacity(Constants.gradientOpacityLight)
                ],
                startPoint: .top,
                endPoint: .bottom
            ))
        }

        PointMark(
            x: .value("Index", data.index),
            y: .value("Rate", dataHasAppeared ? data.rate : 0)
        )
        .foregroundStyle(.blue)
        .symbolSize(Constants.pointSize)

        if showBaseline {
            baselineMarks
        }
    }

    @ChartContentBuilder private var baselineMarks: some ChartContent {
        RuleMark(y: .value("Baseline", viewModel.baselineThreshold()))
            .foregroundStyle(Color.paletteOrange.opacity(Constants.baselineOpacity))
            .lineStyle(StrokeStyle(
                lineWidth: Constants.baselineLineWidth,
                dash: [Constants.dashPatternLong, Constants.dashPatternShort]
            ))

        RuleMark(y: .value("Warning", viewModel.warningThreshold()))
            .foregroundStyle(Color.paletteRed.opacity(Constants.baselineOpacity))
            .lineStyle(StrokeStyle(
                lineWidth: Constants.baselineLineWidth,
                dash: [Constants.dashPatternLong, Constants.dashPatternShort]
            ))
    }
}

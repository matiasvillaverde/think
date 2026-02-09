import Charts
import SwiftUI

internal struct TokenProbabilityChart: View {
    let filteredProbabilities: [TokenProbability]
    let showTrendLine: Bool
    let showConfidenceBands: Bool
    let dataHasAppeared: Bool
    let hoveredPoint: TokenProbability?
    let viewModel: TokenProbabilityViewModel
    let chartHeight: CGFloat
    let animationDuration: Double
    let config: TokenProcessingConfig

    private enum Constants {
        static let pointSize: CGFloat = 40
        static let trendLineWidth: CGFloat = 2
        static let normalOpacity: Double = 0.8
        static let dimmedOpacity: Double = 0.3
        static let trendOpacity: Double = 0.5
        static let dashLength: CGFloat = 5
        static let dashSpacing: CGFloat = 3
        static let gridLineWidth: CGFloat = 0.5
        static let borderWidth: CGFloat = 0.5
        static let chartOpacity: Double = 0.05
        static let borderOpacity: Double = 0.2
        static let confidenceOpacity: Double = 0.2
        static let confidenceLineOpacity: Double = 0.3
        static let confidenceLineWidth: CGFloat = 1
        static let dashPatternOne: CGFloat = 3
        static let dashPatternTwo: CGFloat = 3
        static let upperConfidenceMultiplier: Double = 0.3
        static let lowerConfidenceMultiplier: Double = 0.7
        static let upperPositionMultiplier: Double = 0.15
        static let lowerPositionMultiplier: Double = 0.85
    }

    var body: some View {
        Chart {
            ForEach(filteredProbabilities) { point in
                chartContent(for: point)
            }

            if showTrendLine,
                !filteredProbabilities.isEmpty {
                trendLineContent
            }

            if showConfidenceBands,
                !filteredProbabilities.isEmpty {
                confidenceBandContent
            }
        }
        .frame(height: chartHeight)
        .chartXScale(domain: 0 ... maxTokenPosition)
        .chartYScale(domain: 0 ... 1)
        .chartBackground { _ in
            chartBackgroundContent
        }
        .chartXAxis {
            xAxisContent
        }
        .chartYAxis {
            yAxisContent
        }
        .chartPlotStyle { plotArea in
            plotArea
                .border(
                    Color.paletteGray.opacity(Constants.borderOpacity),
                    width: Constants.borderWidth
                )
        }
        .animation(.easeInOut(duration: animationDuration), value: showTrendLine)
        .animation(.easeInOut(duration: animationDuration), value: showConfidenceBands)
    }

    @ChartContentBuilder
    private func chartContent(for point: TokenProbability) -> some ChartContent {
        PointMark(
            x: .value("Token Position", point.tokenIndex),
            y: .value("Probability", point.probability)
        )
        .foregroundStyle(point.color)
        .symbolSize(Constants.pointSize)
        .opacity(
            dataHasAppeared
                ? (hoveredPoint == nil || hoveredPoint?.id == point.id
                    ? Constants.normalOpacity : Constants.dimmedOpacity)
                : 0
        )
    }

    @ChartContentBuilder private var trendLineContent: some ChartContent {
        LineMark(
            x: .value("Position", 0),
            y: .value("Trend", trendStartY)
        )
        .foregroundStyle(Color.paletteBlue.opacity(Constants.trendOpacity))
        .lineStyle(StrokeStyle(lineWidth: Constants.trendLineWidth))

        LineMark(
            x: .value("Position", maxTokenPosition),
            y: .value("Trend", trendEndY)
        )
        .foregroundStyle(Color.paletteBlue.opacity(Constants.trendOpacity))
        .lineStyle(StrokeStyle(lineWidth: Constants.trendLineWidth))
    }

    @ChartContentBuilder private var confidenceBandContent: some ChartContent {
        AreaMark(
            x: .value("Position", 0),
            yStart: .value("Lower", trendStartY * Constants.lowerConfidenceMultiplier),
            yEnd: .value(
                "Upper",
                trendStartY + (1 - trendStartY) * Constants.upperConfidenceMultiplier
            )
        )
        .foregroundStyle(Color.paletteBlue.opacity(Constants.confidenceOpacity))

        AreaMark(
            x: .value("Position", maxTokenPosition),
            yStart: .value("Lower", trendEndY * Constants.lowerConfidenceMultiplier),
            yEnd: .value("Upper", trendEndY + (1 - trendEndY) * Constants.upperConfidenceMultiplier)
        )
        .foregroundStyle(Color.paletteBlue.opacity(Constants.confidenceOpacity))

        LineMark(
            x: .value("Position", 0),
            y: .value("Upper", trendStartY + (1 - trendStartY) * Constants.upperPositionMultiplier)
        )
        .foregroundStyle(Color.paletteBlue.opacity(Constants.confidenceLineOpacity))
        .lineStyle(StrokeStyle(
            lineWidth: Constants.confidenceLineWidth,
            dash: [Constants.dashPatternOne, Constants.dashPatternTwo]
        ))

        LineMark(
            x: .value("Position", 0),
            y: .value("Lower", trendStartY * Constants.lowerPositionMultiplier)
        )
        .foregroundStyle(Color.paletteBlue.opacity(Constants.confidenceLineOpacity))
        .lineStyle(StrokeStyle(
            lineWidth: Constants.confidenceLineWidth,
            dash: [Constants.dashPatternOne, Constants.dashPatternTwo]
        ))
    }

    private var chartBackgroundContent: some View {
        Rectangle()
            .fill(Color.paletteGray.opacity(Constants.chartOpacity))
    }

    private var xAxisContent: some AxisContent {
        AxisMarks { _ in
            AxisGridLine(
                stroke: StrokeStyle(
                    lineWidth: Constants.gridLineWidth,
                    dash: [Constants.dashLength, Constants.dashSpacing]
                )
            )
            .foregroundStyle(Color.textSecondary.opacity(Constants.borderOpacity))
            AxisValueLabel()
                .font(.caption)
        }
    }

    private var yAxisContent: some AxisContent {
        AxisMarks(position: .leading) { value in
            AxisGridLine(
                stroke: StrokeStyle(
                    lineWidth: Constants.gridLineWidth,
                    dash: [Constants.dashLength, Constants.dashSpacing]
                )
            )
            .foregroundStyle(Color.textSecondary.opacity(Constants.borderOpacity))

            AxisValueLabel {
                if let doubleValue = value.as(Double.self) {
                    Text(String(format: "%.0f%%", doubleValue * 100))
                        .font(.caption)
                }
            }
        }
    }

    private var maxTokenPosition: Int {
        filteredProbabilities.map(\.tokenIndex).max() ?? 1
    }

    private var trendStartY: Double {
        viewModel.trendLineYValue(at: 0, for: filteredProbabilities)
    }

    private var trendEndY: Double {
        viewModel.trendLineYValue(at: maxTokenPosition, for: filteredProbabilities)
    }
}

import Charts
import Database
import SwiftUI

/// Chart content extension for EntropyChartCard
extension EntropyChartCard {
    @ChartContentBuilder var chartMarks: some ChartContent {
        if dataHasAppearedValue {
            areaMarks
            lineMarks
            if showThresholdLinesValue {
                thresholdMarks
            }
        }
    }

    @ChartContentBuilder private var areaMarks: some ChartContent {
        ForEach(entropyData) { data in
            AreaMark(
                x: .value("Date", data.date),
                y: .value("Entropy", data.smoothedEntropy)
            )
            .foregroundStyle(
                .linearGradient(
                    colors: [
                        entropyColor(for: data.smoothedEntropy)
                            .opacity(Constants.gradientOpacity),
                        entropyColor(for: data.smoothedEntropy)
                            .opacity(Constants.gradientOpacityLow)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
        }
    }

    @ChartContentBuilder private var lineMarks: some ChartContent {
        ForEach(entropyData) { data in
            LineMark(
                x: .value("Date", data.date),
                y: .value("Entropy", data.entropy)
            )
            .foregroundStyle(entropyColor(for: data.entropy))
            .lineStyle(StrokeStyle(lineWidth: Constants.lineWidth))
            .interpolationMethod(.catmullRom)
        }
    }

    @ChartContentBuilder private var thresholdMarks: some ChartContent {
        RuleMark(y: .value("Low", Constants.lowThreshold))
            .foregroundStyle(.green.opacity(Constants.thresholdOpacity))
            .lineStyle(
                StrokeStyle(
                    lineWidth: Constants.thresholdLineWidth,
                    dash: [Constants.dashLength, Constants.dashGap]
                )
            )
            .annotation(position: .trailing, alignment: .leading) {
                Text("Low", bundle: .module)
                    .font(.caption2)
                    .foregroundColor(.green)
            }

        RuleMark(y: .value("High", Constants.highThreshold))
            .foregroundStyle(.red.opacity(Constants.thresholdOpacity))
            .lineStyle(
                StrokeStyle(
                    lineWidth: Constants.thresholdLineWidth,
                    dash: [Constants.dashLength, Constants.dashGap]
                )
            )
            .annotation(position: .trailing, alignment: .leading) {
                Text("High", bundle: .module)
                    .font(.caption2)
                    .foregroundColor(.red)
            }
    }
}

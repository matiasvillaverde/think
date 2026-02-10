import Charts
import Database
import Foundation
import SwiftUI

// MARK: - Supporting Views

internal struct StatRow: View {
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(Color.textSecondary)

            Spacer()

            Text(value)
                .font(.caption.weight(.bold))
                .foregroundColor(color)
        }
    }
}

internal struct UtilizationStatsView: View {
    let metric: Metrics
    let remainingCapacity: Int?
    let utilizationPercentage: Double

    private enum Constants {
        static let spacingMultiplier: CGFloat = 2
        static let lowThreshold: Double = 50.0
        static let mediumThreshold: Double = 70.0
        static let highThreshold: Double = 90.0
        static let criticalThreshold: Double = 95.0
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: ChartConstants.Layout.itemSpacing * Constants.spacingMultiplier
        ) {
            modelNameView
            tokenStatsView
            UtilizationStatusView(utilizationPercentage: utilizationPercentage)
        }
    }

    private var modelNameView: some View {
        Group {
            if let modelName = metric.modelName {
                HStack {
                    Text("Model:", bundle: .module)
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                    Text(modelName)
                        .font(.caption.weight(.bold))
                }
            }
        }
    }

    private var tokenStatsView: some View {
        VStack(alignment: .leading, spacing: ChartConstants.Layout.itemSpacing) {
            StatRow(
                label: String(localized: "Used Tokens", bundle: .module),
                value: "\(metric.promptTokens + metric.generatedTokens)",
                color: .blue
            )

            if let remaining = remainingCapacity {
                StatRow(
                    label: String(localized: "Remaining", bundle: .module),
                    value: "\(remaining)",
                    color: utilizationPercentage > Constants.criticalThreshold
                        ? .red
                        : .green
                )
            }

            StatRow(
                label: String(localized: "Utilization", bundle: .module),
                value: String(format: "%.1f%%", utilizationPercentage),
                color: utilizationColor(for: utilizationPercentage)
            )
        }
    }

    private func utilizationColor(for percentage: Double) -> Color {
        switch percentage {
        case 0 ..< Constants.lowThreshold:
            .green

        case Constants.lowThreshold ..< Constants.mediumThreshold:
            .yellow

        case Constants.mediumThreshold ..< Constants.highThreshold:
            .orange

        default:
            .red
        }
    }
}

internal struct UtilizationTrendChart: View {
    let metrics: [Metrics]
    let utilizationPercentage: (Metrics) -> Double

    private enum Constants {
        static let trendSpacing: CGFloat = 8
        static let pointSymbolSize: CGFloat = 30
        static let trendChartHeight: CGFloat = 50
        static let chartBackgroundOpacity: Double = 0.05
        static let chartCornerRadius: CGFloat = 8
    }

    init(metrics: [Metrics], utilizationPercentage: @escaping (Metrics) -> Double) {
        self.metrics = metrics
        self.utilizationPercentage = utilizationPercentage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.trendSpacing) {
            Text("Trend", bundle: .module)
                .font(.caption)
                .foregroundColor(Color.textSecondary)

            Chart(Array(metrics.enumerated()), id: \.offset) { index, metric in
                LineMark(
                    x: .value("Index", index),
                    y: .value("Utilization", utilizationPercentage(metric))
                )
                .foregroundStyle(Color.paletteBlue)

                PointMark(
                    x: .value("Index", index),
                    y: .value("Utilization", utilizationPercentage(metric))
                )
                .foregroundStyle(Color.paletteBlue)
                .symbolSize(Constants.pointSymbolSize)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: Constants.trendChartHeight)
            .background(Color.paletteGray.opacity(Constants.chartBackgroundOpacity))
            .cornerRadius(Constants.chartCornerRadius)
        }
    }
}

internal struct UtilizationStatusView: View {
    let utilizationPercentage: Double

    private enum Constants {
        static let statusCircleSize: CGFloat = 8
        static let lowThreshold: Double = 50.0
        static let mediumThreshold: Double = 70.0
        static let highThreshold: Double = 90.0
        static let lineWidth: CGFloat = 2
    }

    private var status: (String, Color) {
        if utilizationPercentage < Constants.lowThreshold {
            return (String(localized: "Optimal", bundle: .module), .green)
        }
        if utilizationPercentage < Constants.mediumThreshold {
            return (String(localized: "Good", bundle: .module), .yellow)
        }
        if utilizationPercentage < Constants.highThreshold {
            return (String(localized: "Warning", bundle: .module), .orange)
        }
        return (String(localized: "Critical", bundle: .module), .red)
    }
    var body: some View {
        HStack {
            Circle()
                .fill(status.1)
                .frame(
                    width: Constants.statusCircleSize,
                    height: Constants.statusCircleSize
                )
            Text(status.0)
                .font(.caption.weight(.bold))
                .foregroundColor(status.1)
        }
    }
}

internal struct PolylineChartView: View {
    let data: [DataPoint]

    private enum Constants {
        static let lineWidth: CGFloat = 2
    }

    var body: some View {
        GeometryReader { geometry in
            let maxValue: Double = data.map(\.value).max() ?? 1
            let stepX: CGFloat = geometry.size.width /
                CGFloat(max(data.count - 1, 1))

            Path { path in
                for (index, point) in data.enumerated() {
                    let xPos: CGFloat = CGFloat(index) * stepX
                    let yPos: CGFloat = geometry.size.height *
                        (1 - CGFloat(point.value / maxValue))

                    if index == 0 {
                        path.move(to: CGPoint(x: xPos, y: yPos))
                    } else {
                        path.addLine(to: CGPoint(x: xPos, y: yPos))
                    }
                }
            }
            .stroke(Color.paletteBlue, lineWidth: Constants.lineWidth)
        }
    }
}

// MARK: - Data Model

internal struct DataPoint: Identifiable {
    let id: UUID = .init()
    let value: Double
}

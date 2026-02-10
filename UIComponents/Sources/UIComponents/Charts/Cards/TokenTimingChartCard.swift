import Charts
import Database
import Foundation
import SwiftUI

/// Token Timing Bar Chart wrapped in a card container
public struct TokenTimingChartCard: View {
    let metrics: [Metrics]

    @State private var messageCount: Int = 5
    @State private var showBreakdown: Bool = true
    @State private var dataHasAppeared: Bool = false

    private enum Constants {
        static let millisecondsMultiplier: Double = 1_000
        static let maxMessages: Int = 10
        static let legendRectWidth: CGFloat = 12
        static let legendRectHeight: CGFloat = 12
        static let legendRectCornerRadius: CGFloat = 2
        static let legendIconSpacing: CGFloat = 4
        static let statSpacing: CGFloat = 2
        static let stepperMinWidth: CGFloat = 30
        static let backgroundOpacity: Double = 0.2
        static let borderWidth: CGFloat = 0.5
        static let annotationThreshold: Double = 100
        static let backgroundOpacityQuarter: Double = 0.25
        static let divisionFactor: Double = 4
        static let categoryColors: [String: Color] = [
            "TTFT": .blue,
            "Avg Token": .green,
            "Total": .orange
        ]
        static let barAnimationDuration: Double = 0.6
        static let barAnimationDelay: Double = 0.05
    }

    public init(metrics: [Metrics]) {
        self.metrics = metrics
    }

    public var body: some View {
        ChartCard(
            title: String(localized: "Token Generation Timing", bundle: .module),
            subtitle: String(localized: "Breakdown for recent messages", bundle: .module),
            systemImage: "timer"
        ) {
            chartContent
        } controls: {
            controlsContent
        }
    }

    private var chartContent: some View {
        VStack(alignment: .leading, spacing: ChartConstants.Layout.cardSpacing) {
            if timingData.isEmpty {
                emptyDataView
            } else {
                timingChart
                legendView
                statsView
            }
        }
    }

    private var emptyDataView: some View {
        ContentUnavailableView(
            String(localized: "No Timing Data", bundle: .module),
            systemImage: "clock",
            description: Text("Token timing data will appear here", bundle: .module)
        )
        .frame(height: ChartConstants.Layout.compactChartHeight)
    }

    private var timingChart: some View {
        Chart(dataHasAppeared ? timingData : []) { item in
            BarMark(
                x: .value("Message", "M\(item.messageIndex + 1)"),
                y: .value("Time (ms)", dataHasAppeared ? item.value : 0)
            )
            .foregroundStyle(by: .value("Category", item.category))
            .position(by: .value("Category", showBreakdown ? item.category : "Combined"))
            .annotation(position: .top) {
                if item.value > Constants.annotationThreshold, dataHasAppeared {
                    Text(String(format: "%.0f", item.value))
                        .font(.caption2)
                        .foregroundColor(Color.textSecondary)
                }
            }
        }
        .chartForegroundStyleScale { (category: String) in
            Constants.categoryColors[category] ?? .gray
        }
        .chartYAxisLabel(String(localized: "Time (ms)", bundle: .module))
        .chartXAxisLabel(String(localized: "Message", bundle: .module))
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let time = value.as(Double.self) {
                        Text(String(format: "%.0f", time))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisTick()
                AxisValueLabel()
            }
        }
        .chartPlotStyle { plotArea in
            plotArea
                .background(
                    Color.paletteGray.opacity(Constants.backgroundOpacityQuarter)
                )
                .border(
                    Color.paletteGray.opacity(Constants.backgroundOpacity),
                    width: Constants.borderWidth
                )
        }
        .frame(height: ChartConstants.Layout.compactChartHeight)
        .animation(.easeInOut(duration: Constants.barAnimationDuration), value: dataHasAppeared)
        .animation(.easeInOut, value: showBreakdown)
        .animation(.easeInOut, value: messageCount)
        .onAppear {
            withAnimation(
                .easeInOut(duration: Constants.barAnimationDuration)
                    .delay(Constants.barAnimationDelay)
            ) {
                dataHasAppeared = true
            }
        }
    }

    private var legendView: some View {
        HStack(spacing: ChartConstants.Layout.sectionSpacing) {
            ForEach(Array(Constants.categoryColors.keys.sorted()), id: \.self) { category in
                HStack(spacing: Constants.legendIconSpacing) {
                    Rectangle()
                        .fill(Constants.categoryColors[category] ?? .gray)
                        .frame(width: Constants.legendRectWidth, height: Constants.legendRectHeight)
                        .cornerRadius(Constants.legendRectCornerRadius)

                    Text(verbatim: category)
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                }
            }
            Spacer()
        }
    }

    private var statsView: some View {
        HStack(spacing: ChartConstants.Layout.sectionSpacing) {
            // Average TTFT
            if let avgTTFT = calculateAverageTTFT() {
                VStack(alignment: .leading, spacing: Constants.statSpacing) {
                    Text("Avg TTFT", bundle: .module)
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                    Text(String(format: "%.1f ms", avgTTFT))
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.blue)
                }
            }

            // Average token time
            if let avgTokenTime = calculateAverageTokenTime() {
                VStack(alignment: .leading, spacing: Constants.statSpacing) {
                    Text("Avg Token", bundle: .module)
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                    Text(String(format: "%.1f ms", avgTokenTime))
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.green)
                }
            }

            // Total messages
            VStack(alignment: .leading, spacing: Constants.statSpacing) {
                Text("Messages", bundle: .module)
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
                Text(verbatim: "\(min(messageCount, metrics.count))")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.orange)
            }

            Spacer()
        }
    }

    private var controlsContent: some View {
        VStack(spacing: ChartConstants.Layout.cardSpacing) {
            // Message count stepper
            HStack {
                Text("Messages to show:", bundle: .module)
                    .font(.subheadline)
                    .foregroundColor(Color.textSecondary)

                Spacer()

                Stepper(value: $messageCount, in: 1 ... Constants.maxMessages) {
                    Text(verbatim: "\(messageCount)")
                        .font(.subheadline.weight(.bold))
                        .frame(minWidth: Constants.stepperMinWidth)
                }
            }

            // Breakdown toggle
            Toggle(isOn: $showBreakdown) {
                Text("Show breakdown by category", bundle: .module)
            }
            .font(.subheadline)
        }
    }

    // MARK: - Data Processing

    private struct TimingData: Identifiable {
        let id: UUID = .init()
        let category: String
        let value: Double
        let messageIndex: Int
    }

    private var timingData: [TimingData] {
        var data: [TimingData] = []

        for (index, metric) in metrics.prefix(messageCount).enumerated() {
            // Time to First Token
            if let ttft = metric.timeToFirstToken {
                data.append(
                    TimingData(
                        category: "TTFT",
                        value: ttft * Constants.millisecondsMultiplier,
                        messageIndex: index
                    )
                )
            }

            // Average token generation time
            if metric.generatedTokens > 0 {
                let avgTokenTime: Double = metric.totalTime / Double(metric.generatedTokens)
                data.append(
                    TimingData(
                        category: "Avg Token",
                        value: avgTokenTime * Constants.millisecondsMultiplier,
                        messageIndex: index
                    )
                )
            }

            // Total generation time
            data.append(
                TimingData(
                    category: "Total",
                    value: metric.totalTime * Constants.millisecondsMultiplier,
                    messageIndex: index
                )
            )
        }

        return data
    }

    private func calculateAverageTTFT() -> Double? {
        let ttftValues: [TimeInterval] = metrics.prefix(messageCount).compactMap(\.timeToFirstToken)
        guard !ttftValues.isEmpty else {
            return nil
        }
        return ttftValues.reduce(0, +) / Double(ttftValues.count) * Constants.millisecondsMultiplier
    }

    private func calculateAverageTokenTime() -> Double? {
        let validMetrics: [Metrics] = metrics.prefix(messageCount).filter { $0.generatedTokens > 0 }
        guard !validMetrics.isEmpty else {
            return nil
        }
        let avgTimes: [Double] = validMetrics.map { $0.totalTime / Double($0.generatedTokens) }
        return avgTimes.reduce(0, +) / Double(avgTimes.count) * Constants.millisecondsMultiplier
    }
}

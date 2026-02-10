import Charts
import Database
import Foundation
import SwiftUI

/// Model Comparison Chart wrapped in a card container
public struct ModelComparisonChartCard: View {
    let metrics: [Metrics]

    @State private var selectedMetric: MetricType = .speed
    @State private var showAllModels: Bool = false
    @State private var dataHasAppeared: Bool = false

    private enum Constants {
        static let chartHeight: CGFloat = 250
        static let maxModelsToShow: Int = 5
        static let legendCircleSize: CGFloat = 10
        static let legendItemSpacing: CGFloat = 8
        static let animationDuration: Double = 0.7
        static let animationDelay: Double = 0.3
        static let lineWidth: CGFloat = 2
        static let symbolSize: CGFloat = 30

        // Additional constants for magic numbers
        static let chartBackgroundOpacity: Double = 0.05
        static let borderOpacity: Double = 0.2
        static let borderWidth: CGFloat = 0.5
        static let bytesToMB: Double = 1_048_576
    }

    public enum MetricType: String, CaseIterable {
        case speed = "Speed"
        case tokenUsage = "Tokens"
        case latency = "Latency"
        case memory = "Memory"

        var displayName: String {
            rawValue
        }

        var unit: String {
            switch self {
            case .speed:
                "tok/s"

            case .tokenUsage:
                "tokens"

            case .latency:
                "seconds"

            case .memory:
                "MB"
            }
        }

        var fullName: String {
            switch self {
            case .speed:
                "Speed (tokens/sec)"

            case .tokenUsage:
                "Token Usage"

            case .latency:
                "Total Time (s)"

            case .memory:
                "Memory (MB)"
            }
        }

        var localizedFullName: String {
            fullName
        }
    }

    private struct ModelData: Identifiable {
        let id: UUID = .init()
        let modelName: String
        let date: Date
        let value: Double
    }

    public init(metrics: [Metrics]) {
        self.metrics = metrics
    }

    public var body: some View {
        ChartCard(
            title: String(localized: "Model Comparison", bundle: .module),
            subtitle: String(localized: "\(uniqueModelNames.count) models", bundle: .module),
            systemImage: "chart.line.uptrend.xyaxis.circle"
        ) {
            chartContent
        } controls: {
            controlsContent
        }
    }

    private var chartContent: some View {
        VStack(spacing: ChartConstants.Layout.cardSpacing) {
            if modelData.isEmpty {
                ContentUnavailableView(
                    String(localized: "No Comparison Data", bundle: .module),
                    systemImage: "chart.xyaxis.line",
                    description: Text("Model comparison data will appear here", bundle: .module)
                )
                .frame(height: Constants.chartHeight)
            } else {
                comparisonChart
                modelLegend
            }
        }
    }

    private var comparisonChart: some View {
        Chart(dataHasAppeared ? modelData : []) { data in
            LineMark(
                x: .value("Date", data.date),
                y: .value(selectedMetric.localizedFullName, data.value),
                series: .value("Model", data.modelName)
            )
            .foregroundStyle(by: .value("Model", data.modelName))
            .lineStyle(StrokeStyle(lineWidth: Constants.lineWidth))
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("Date", data.date),
                y: .value(selectedMetric.localizedFullName, data.value)
            )
            .foregroundStyle(by: .value("Model", data.modelName))
            .symbolSize(Constants.symbolSize)
        }
        .chartForegroundStyleScale(domain: modelNames, range: modelColors)
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisValueLabel(format: .dateTime.hour().minute())
                AxisGridLine()
            }
        }
        .chartYAxisLabel("\(selectedMetric.displayName) (\(selectedMetric.unit))")
        .chartLegend(.hidden)
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color.paletteGray.opacity(Constants.chartBackgroundOpacity))
                .border(
                    Color.paletteGray.opacity(Constants.borderOpacity),
                    width: Constants.borderWidth
                )
        }
        .frame(height: Constants.chartHeight)
        .animation(
            .easeInOut(duration: Constants.animationDuration),
            value: dataHasAppeared
        )
        .animation(.easeInOut, value: selectedMetric)
        .animation(.easeInOut, value: showAllModels)
        .onAppear {
            withAnimation(
                .easeInOut(duration: Constants.animationDuration)
                    .delay(Constants.animationDelay)
            ) {
                dataHasAppeared = true
            }
        }
    }

    private var modelLegend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ChartConstants.Layout.sectionSpacing) {
                ForEach(modelNames, id: \.self) { modelName in
                    HStack(spacing: Constants.legendItemSpacing) {
                        Circle()
                            .fill(modelColors[modelNames.firstIndex(of: modelName) ?? 0])
                            .frame(
                                width: Constants.legendCircleSize,
                                height: Constants.legendCircleSize
                            )

                        Text(modelName)
                            .font(.caption)
                            .foregroundColor(Color.textPrimary)
                            .lineLimit(1)

                        // Show latest value
                        if let latestValue = getLatestValue(for: modelName) {
                            Text(verbatim: "(\(formatValue(latestValue)))")
                                .font(.caption)
                                .foregroundColor(Color.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private var controlsContent: some View {
        VStack(spacing: ChartConstants.Layout.cardSpacing) {
            // Metric selector
            Picker(selection: $selectedMetric) {
                ForEach(MetricType.allCases, id: \.self) { metric in
                    Text(metric.displayName).tag(metric)
                }
            } label: {
                Text("Metric", bundle: .module)
            }
            .pickerStyle(.segmented)

            // Show all models toggle
            if uniqueModelNames.count > Constants.maxModelsToShow {
                Toggle(isOn: $showAllModels) {
                    Text("Show all \(uniqueModelNames.count) models", bundle: .module)
                }
                .font(.subheadline)
            }
        }
    }

    // MARK: - Data Processing

    private var modelData: [ModelData] {
        var data: [ModelData] = []

        for metric in metrics {
            guard
                let modelName = metric.modelName,
                modelNames.contains(modelName)
            else { continue }

            let value: Double = getValue(from: metric, for: selectedMetric)
            data.append(
                ModelData(
                    modelName: modelName,
                    date: metric.createdAt,
                    value: value
                )
            )
        }

        return data.sorted { $0.date < $1.date }
    }

    private var uniqueModelNames: [String] {
        let names: Set<String> = Set(metrics.compactMap(\.modelName))
        return Array(names).sorted()
    }

    private var modelNames: [String] {
        if showAllModels {
            return uniqueModelNames
        }
        return Array(uniqueModelNames.prefix(Constants.maxModelsToShow))
    }

    private var modelColors: [Color] {
        [.blue, .green, .orange, .purple, .red, .pink, .cyan, .indigo, .mint, .teal]
    }

    private func getValue(from metric: Metrics, for metricType: MetricType) -> Double {
        switch metricType {
        case .speed:
            metric.tokensPerSecond

        case .tokenUsage:
            Double(metric.totalTokens)

        case .latency:
            metric.totalTime

        case .memory:
            Double(metric.activeMemory) / Constants.bytesToMB // Convert to MB
        }
    }

    private func getLatestValue(for modelName: String) -> Double? {
        metrics
            .filter { $0.modelName == modelName }
            .max { $0.createdAt < $1.createdAt }
            .map { getValue(from: $0, for: selectedMetric) }
    }

    private func formatValue(_ value: Double) -> String {
        switch selectedMetric {
        case .speed:
            String(format: "%.1f", value)

        case .tokenUsage:
            String(format: "%.0f", value)

        case .latency:
            String(format: "%.2f", value)

        case .memory:
            String(format: "%.1f", value)
        }
    }
}

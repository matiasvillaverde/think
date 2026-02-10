import Charts
import Database
import Foundation
import SwiftUI

/// Entropy Area Chart wrapped in a card container
public struct EntropyChartCard: View {
    let metrics: [Metrics]

    @State private var showThresholdLines: Bool = true
    @State private var timeRange: TimeRange = .lastDay
    @State private var dataHasAppeared: Bool = false

    // Internal accessors for extensions
    var showThresholdLinesValue: Bool { showThresholdLines }
    var dataHasAppearedValue: Bool { dataHasAppeared }

    enum Constants {
        static let chartHeight: CGFloat = 250
        static let lowThreshold: Double = 2.0
        static let highThreshold: Double = 4.0
        static let smoothingFactor: Double = 0.3
        static let gradientOpacity: Double = 0.6
        static let gradientOpacityLow: Double = 0.1
        static let lineWidth: CGFloat = 2
        static let thresholdLineWidth: CGFloat = 1
        static let thresholdOpacity: Double = 0.5
        static let dashLength: CGFloat = 5
        static let dashGap: CGFloat = 5
        static let statSpacing: CGFloat = 2
        static let animationDuration: Double = 0.8
        static let animationDelay: Double = 0.2
        static let backgroundOpacity: Double = 0.05
        static let borderOpacity: Double = 0.2
        static let borderWidth: CGFloat = 0.5
    }

    enum EntropyTrend: String {
        case increasing = "Increasing"
        case decreasing = "Decreasing"
        case stable = "Stable"

        var displayName: String {
            rawValue
        }
    }

    public enum TimeRange: String, CaseIterable {
        case lastHour = "Last Hour"
        case lastDay = "Last Day"
        case lastWeek = "Last Week"
        case all = "All Time"

        var displayName: String {
            rawValue
        }

        func filter(_ metrics: [Metrics]) -> [Metrics] {
            let now: Date = Date()
            let calendar: Calendar = Calendar.current

            switch self {
            case .lastHour:
                let hourAgo: Date = calendar.date(byAdding: .hour, value: -1, to: now) ?? now
                return metrics.filter { $0.createdAt >= hourAgo }

            case .lastDay:
                let dayAgo: Date = calendar.date(byAdding: .day, value: -1, to: now) ?? now
                return metrics.filter { $0.createdAt >= dayAgo }

            case .lastWeek:
                let weekAgo: Date = calendar.date(
                    byAdding: .weekOfYear,
                    value: -1,
                    to: now
                ) ?? now
                return metrics.filter { $0.createdAt >= weekAgo }

            case .all:
                return metrics
            }
        }
    }

    struct EntropyData: Identifiable {
        let id: UUID = .init()
        let date: Date
        let entropy: Double
        let smoothedEntropy: Double
    }

    public init(metrics: [Metrics]) {
        self.metrics = metrics
    }

    public var body: some View {
        ChartCard(
            title: String(localized: "Entropy Analysis", bundle: .module),
            subtitle: String(localized: "Randomness over time", bundle: .module),
            systemImage: "waveform.path.ecg"
        ) {
            chartContent
        } controls: {
            controlsContent
        }
    }

    private var chartContent: some View {
        VStack(spacing: ChartConstants.Layout.cardSpacing) {
            if entropyData.isEmpty {
                ContentUnavailableView(
                    String(localized: "No Entropy Data", bundle: .module),
                    systemImage: "waveform",
                    description: Text("Entropy data will appear here", bundle: .module)
                )
                .frame(height: Constants.chartHeight)
            } else {
                entropyChart
                statsView
            }
        }
    }

    private var entropyChart: some View {
        Chart {
            chartMarks
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisValueLabel(format: .dateTime.hour().minute())
                AxisGridLine()
            }
        }
        .chartYAxisLabel(String(localized: "Entropy", bundle: .module))
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color.paletteGray.opacity(Constants.backgroundOpacity))
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
        .animation(.easeInOut, value: showThresholdLines)
        .animation(.easeInOut, value: timeRange)
        .onAppear {
            withAnimation(
                .easeInOut(duration: Constants.animationDuration)
                    .delay(Constants.animationDelay)
            ) {
                dataHasAppeared = true
            }
        }
    }

    private var controlsContent: some View {
        VStack(spacing: ChartConstants.Layout.cardSpacing) {
            // Time range picker
            HStack {
                Text("Time Range:", bundle: .module)
                    .font(.subheadline)
                    .foregroundColor(Color.textSecondary)

                Spacer()

                Picker(selection: $timeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.displayName).tag(range)
                    }
                } label: {
                    Text("Range", bundle: .module)
                }
                .pickerStyle(.segmented)
            }

            // Threshold toggle
            Toggle(isOn: $showThresholdLines) {
                Text("Show threshold lines", bundle: .module)
            }
            .font(.subheadline)
        }
    }

    // MARK: - Data Processing

    var entropyData: [EntropyData] {
        let filtered: [Metrics] = timeRange.filter(metrics)
            .sorted { $0.createdAt < $1.createdAt }

        var smoothedValue: Double = filtered.first?.entropy ?? 0
        var data: [EntropyData] = []

        for metric in filtered {
            smoothedValue = (metric.entropy ?? 0) * Constants.smoothingFactor +
                smoothedValue * (1 - Constants.smoothingFactor)

            data.append(
                EntropyData(
                    date: metric.createdAt,
                    entropy: metric.entropy ?? 0,
                    smoothedEntropy: smoothedValue
                )
            )
        }

        return data
    }

    var averageEntropy: Double {
        guard !entropyData.isEmpty else {
            return 0
        }
        return entropyData.map(\.entropy).reduce(0, +) / Double(entropyData.count)
    }

    var entropyTrend: EntropyTrend {
        guard entropyData.count > 1 else {
            return .stable
        }
        let first: Double = entropyData.first?.entropy ?? 0
        let last: Double = entropyData.last?.entropy ?? 0
        if last > first {
            return .increasing
        }
        if last < first {
            return .decreasing
        }
        return .stable
    }

    var trendColor: Color {
        switch entropyTrend {
        case .increasing:
            .orange

        case .decreasing:
            .blue

        case .stable:
            .gray
        }
    }

    func entropyColor(for value: Double) -> Color {
        switch value {
        case ..<Constants.lowThreshold:
            .green

        case Constants.lowThreshold ..< Constants.highThreshold:
            .yellow

        default:
            .red
        }
    }
}

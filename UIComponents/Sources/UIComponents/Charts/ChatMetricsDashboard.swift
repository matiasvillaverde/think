import Database
import SwiftUI

public struct ChatMetricsDashboard: View {
    let metrics: [Metrics]
    let chatId: String?
    let chatTitle: String?

    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass: UserInterfaceSizeClass?
    @Environment(\.verticalSizeClass)
    private var verticalSizeClass: UserInterfaceSizeClass?

    enum Constants {
        static let spacing: CGFloat = 16
        static let minColumnWidth: CGFloat = 300
        static let maxColumnWidth: CGFloat = 500
        static let cornerRadius: CGFloat = 12
        static let shadowRadius: CGFloat = 2
        static let headerIconSize: CGFloat = 30
        static let dividerPadding: CGFloat = 8
        static let headerSpacing: CGFloat = 8
        static let statisticsCardPadding: CGFloat = 12
        static let messageCountThreshold: Int = 2
        static let recentMessageCount: Int = 10
        static let lastMessageCount: Int = 5
        static let minHeight: CGFloat = 300
        static let iconWidth: CGFloat = 40
        static let percentMultiplier: Double = 100
        static let halfDivisor: CGFloat = 2
        static let modelModulo: Int = 3
        static let conversationInterval: Double = 300
        static let messageIndexStart: Int = 0
        static let messageIndexEnd: Int = 15
        static let contextWindow4k: Int = 4_096
        static let minPromptTokens: Int = 100
        static let maxPromptTokens: Int = 500
        static let minGeneratedTokens: Int = 500
        static let maxGeneratedTokens: Int = 2_000
        static let minContextTokens: Int = 500
        static let maxContextTokens: Int = 3_000
        static let minPeakMemory: UInt64 = 10_000_000
        static let maxPeakMemory: UInt64 = 100_000_000
        static let minPerplexity: Double = 5
        static let maxPerplexity: Double = 20
        static let minEntropy: Double = 2
        static let maxEntropy: Double = 8
        static let minRepetition: Double = 0.05
        static let maxRepetition: Double = 0.3
        static let minTotalTime: Double = 1.0
        static let maxTotalTime: Double = 3.0
        static let minTimeToFirst: Double = 0.1
        static let maxTimeToFirst: Double = 0.3
        static let minWidth: CGFloat = 600
        // Adaptive column counts
        static let iPhoneColumns: Int = 1
        static let iPadPortraitColumns: Int = 2
        static let iPadLandscapeColumns: Int = 3
        static let macOSColumns: Int = 2
        static let visionOSColumns: Int = 3
        static let iPhonePadding: CGFloat = 16
        static let defaultPadding: CGFloat = 20
    }

    @State private var selectedTimeRange: TimeRange = .all

    var filteredMetrics: [Metrics] {
        switch selectedTimeRange {
        case .all:
            metrics

        case .recent:
            Array(metrics.suffix(Constants.recentMessageCount))

        case .last:
            Array(metrics.suffix(Constants.lastMessageCount))
        }
    }

    enum TimeRange: String, CaseIterable {
        case all = "All Messages"
        case recent = "Recent (10)"
        case last = "Last 5"

        var icon: String {
            switch self {
            case .all:
                "clock"

            case .recent:
                "clock.badge.checkmark"

            case .last:
                "clock.badge.exclamationmark"
            }
        }
    }

    public init(
        metrics: [Metrics],
        chatId: String? = nil,
        chatTitle: String? = nil
    ) {
        self.metrics = metrics
        self.chatId = chatId
        self.chatTitle = chatTitle
    }

    public var body: some View {
        AdaptiveScrollContainer {
            VStack(spacing: Constants.spacing) {
                headerView

                if hasMultipleMessages {
                    timeRangeSelector
                }

                Divider()
                    .padding(.vertical, Constants.dividerPadding)

                if !filteredMetrics.isEmpty {
                    statisticsSection
                    conversationChartsSection
                } else {
                    emptyStateView
                }
            }
            .padding(adaptivePadding)
        }
    }

    private var headerView: some View {
        HStack {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: Constants.headerIconSize))
                .foregroundStyle(.blue)
                .accessibilityLabel("Chat icon")

            VStack(alignment: .leading, spacing: Constants.headerSpacing) {
                Text(chatTitle ?? "Chat Metrics")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                HStack {
                    if let chatId {
                        Text("ID: \(chatId)")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Text("\(metrics.count) messages")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            Spacer()
        }
    }

    private var timeRangeSelector: some View {
        Picker("Time Range", selection: $selectedTimeRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Label(range.rawValue, systemImage: range.icon)
                    .tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Metrics Data",
            systemImage: "chart.bar",
            description: Text("Chat metrics will appear here as messages are sent")
        )
        .frame(minHeight: Constants.minHeight)
    }

    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: Constants.spacing) {
            Text("Conversation Statistics")
                .font(.headline)
                .padding(.bottom, Constants.headerSpacing)

            statisticsGrid
        }
    }

    private var statisticsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .flexible(
                        minimum: Constants.minColumnWidth / Constants.halfDivisor,
                        maximum: Constants.maxColumnWidth / Constants.halfDivisor
                    )
                ),
                GridItem(
                    .flexible(
                        minimum: Constants.minColumnWidth / Constants.halfDivisor,
                        maximum: Constants.maxColumnWidth / Constants.halfDivisor
                    )
                )
            ],
            spacing: Constants.spacing
        ) {
            statisticsCard(
                title: "Avg Tokens/Second",
                value: averageTokensPerSecond,
                icon: "speedometer"
            )
            statisticsCard(
                title: "Total Tokens",
                value: "\(totalTokens)",
                icon: "number"
            )
            statisticsCard(
                title: "Avg Response Time",
                value: String(format: "%.1fs", averageResponseTime),
                icon: "timer"
            )
            statisticsCard(
                title: "Context Usage",
                value: String(format: "%.0f%%", averageContextUsage * Constants.percentMultiplier),
                icon: "chart.pie"
            )
        }
    }

    private func statisticsCard(title: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: Constants.iconWidth)
                .accessibilityLabel("\(title) icon")

            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            Spacer()
        }
        .padding(Constants.statisticsCardPadding)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .shadow(radius: Constants.shadowRadius)
    }

    private var conversationChartsSection: some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .flexible(
                        minimum: Constants.minColumnWidth,
                        maximum: Constants.maxColumnWidth
                    )
                )
            ],
            spacing: Constants.spacing
        ) {
            // Performance over time
            PerformanceChartCard(metrics: filteredMetrics)

            // Token timing comparison
            TokenTimingChartCard(metrics: filteredMetrics)

            // Quality metrics trends
            if hasQualityMetrics {
                EntropyChartCard(metrics: filteredMetrics)
                RepetitionRateTrendLineCard(metrics: filteredMetrics)
            }

            // Resource usage
            MemoryUsageCard(metrics: filteredMetrics)

            // Token distribution across conversation
            TokenDistributionCard(metrics: filteredMetrics)

            // Model comparison if multiple models used
            if hasMultipleModels {
                ModelComparisonChartCard(metrics: filteredMetrics)
            }

            // Perplexity heat map for quality analysis
            if hasPerplexityData {
                PerplexityHeatMapCard(metrics: filteredMetrics)
            }
        }
    }
}

#if DEBUG
    private func createPreviewMetric(index: Int) -> Metrics {
        typealias Const = ChatMetricsDashboard.Constants

        let modelName: String = index.isMultiple(of: Const.modelModulo) ? "GPT-4" : "Claude-3"

        let totalTimeRange: ClosedRange<Double> = Const.minTotalTime ... Const.maxTotalTime
        let timeToFirstRange: ClosedRange<Double> = Const.minTimeToFirst ... Const.maxTimeToFirst
        let promptTokensRange: ClosedRange<Int> = Const.minPromptTokens ... Const.maxPromptTokens
        let generatedTokensRange: ClosedRange<Int> = Const.minGeneratedTokens ... Const
            .maxGeneratedTokens
        let contextTokensRange: ClosedRange<Int> = Const.minContextTokens ... Const.maxContextTokens
        let peakMemoryRange: ClosedRange<UInt64> = Const.minPeakMemory ... Const.maxPeakMemory
        let perplexityRange: ClosedRange<Double> = Const.minPerplexity ... Const.maxPerplexity
        let entropyRange: ClosedRange<Double> = Const.minEntropy ... Const.maxEntropy
        let repetitionRange: ClosedRange<Double> = Const.minRepetition ... Const.maxRepetition

        return Metrics.preview(
            totalTime: Double.random(in: totalTimeRange),
            timeToFirstToken: Double.random(in: timeToFirstRange),
            promptTokens: Int.random(in: promptTokensRange),
            generatedTokens: Int.random(in: generatedTokensRange),
            contextWindowSize: Const.contextWindow4k,
            contextTokensUsed: Int.random(in: contextTokensRange),
            peakMemory: UInt64.random(in: peakMemoryRange),
            perplexity: Double.random(in: perplexityRange),
            entropy: Double.random(in: entropyRange),
            repetitionRate: Double.random(in: repetitionRange),
            modelName: modelName,
            createdAt: Date().addingTimeInterval(Double(index) * Const.conversationInterval)
        )
    }

    private func createPreviewMetrics() -> [Metrics] {
        let startIndex: Int = ChatMetricsDashboard.Constants.messageIndexStart
        let endIndex: Int = ChatMetricsDashboard.Constants.messageIndexEnd
        return (startIndex ..< endIndex).map { index in
            createPreviewMetric(index: index)
        }
    }

    #Preview("Chat Dashboard - With Data") {
        ChatMetricsDashboard(
            metrics: createPreviewMetrics(),
            chatId: "chat_123",
            chatTitle: "Technical Discussion"
        )
        .frame(minWidth: ChatMetricsDashboard.Constants.minWidth)
    }

    #Preview("Chat Dashboard - Empty") {
        ChatMetricsDashboard(
            metrics: [],
            chatTitle: "New Chat"
        )
        .frame(minWidth: ChatMetricsDashboard.Constants.minWidth)
    }
#endif

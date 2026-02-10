import Database
import SwiftUI

internal enum ChatMetricsDashboardConstants {
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

private enum ChatMetricsTimeRange: String, CaseIterable {
    case all = "all_messages"
    case last = "last_5"
    case recent = "recent_10"

    var title: String {
        switch self {
        case .all:
            return String(localized: "All Messages", bundle: .module)

        case .recent:
            return String(localized: "Recent (10)", bundle: .module)

        case .last:
            return String(localized: "Last 5", bundle: .module)
        }
    }

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

public struct ChatMetricsDashboard: View {
    let metrics: [Metrics]
    let chatId: String?
    let chatTitle: String?

    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass: UserInterfaceSizeClass?
    @Environment(\.verticalSizeClass)
    private var verticalSizeClass: UserInterfaceSizeClass?

    @State private var selectedTimeRange: ChatMetricsTimeRange = .all

    var filteredMetrics: [Metrics] {
        switch selectedTimeRange {
        case .all:
            metrics

        case .recent:
            Array(metrics.suffix(ChatMetricsDashboardConstants.recentMessageCount))

        case .last:
            Array(metrics.suffix(ChatMetricsDashboardConstants.lastMessageCount))
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
            VStack(spacing: ChatMetricsDashboardConstants.spacing) {
                headerView

                if hasMultipleMessages {
                    timeRangeSelector
                }

                Divider()
                    .padding(.vertical, ChatMetricsDashboardConstants.dividerPadding)

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
                .font(.system(size: ChatMetricsDashboardConstants.headerIconSize))
                .foregroundStyle(.blue)
                .accessibilityLabel(Text("Chat icon", bundle: .module))

            VStack(alignment: .leading, spacing: ChatMetricsDashboardConstants.headerSpacing) {
                Text(chatTitle ?? String(localized: "Chat Metrics", bundle: .module))
                    .font(.largeTitle)
                    .fontWeight(.bold)

                HStack {
                    if let chatId {
                        Text("ID: \(chatId)", bundle: .module)
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Text("\(metrics.count) messages", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            Spacer()
        }
    }

    private var timeRangeSelector: some View {
        Picker(selection: $selectedTimeRange) {
            ForEach(ChatMetricsTimeRange.allCases, id: \.self) { range in
                Label {
                    Text(range.title)
                } icon: {
                    Image(systemName: range.icon)
                        .accessibilityHidden(true)
                }
                    .tag(range)
            }
        } label: {
            Text("Time Range", bundle: .module)
        }
        .pickerStyle(.segmented)
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            String(localized: "No Metrics Data", bundle: .module),
            systemImage: "chart.bar",
            description: Text(
                "Chat metrics will appear here as messages are sent",
                bundle: .module
            )
        )
        .frame(minHeight: ChatMetricsDashboardConstants.minHeight)
    }

    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: ChatMetricsDashboardConstants.spacing) {
            Text("Conversation Statistics", bundle: .module)
                .font(.headline)
                .padding(.bottom, ChatMetricsDashboardConstants.headerSpacing)

            statisticsGrid
        }
    }

    private var statisticsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .flexible(
                        minimum: ChatMetricsDashboardConstants.minColumnWidth
                            / ChatMetricsDashboardConstants.halfDivisor,
                        maximum: ChatMetricsDashboardConstants.maxColumnWidth
                            / ChatMetricsDashboardConstants.halfDivisor
                    )
                ),
                GridItem(
                    .flexible(
                        minimum: ChatMetricsDashboardConstants.minColumnWidth
                            / ChatMetricsDashboardConstants.halfDivisor,
                        maximum: ChatMetricsDashboardConstants.maxColumnWidth
                            / ChatMetricsDashboardConstants.halfDivisor
                    )
                )
            ],
            spacing: ChatMetricsDashboardConstants.spacing
        ) {
            statisticsCard(
                title: String(localized: "Avg Tokens/Second", bundle: .module),
                value: averageTokensPerSecond,
                icon: "speedometer"
            )
            statisticsCard(
                title: String(localized: "Total Tokens", bundle: .module),
                value: "\(totalTokens)",
                icon: "number"
            )
            statisticsCard(
                title: String(localized: "Avg Response Time", bundle: .module),
                value: String(format: "%.1fs", averageResponseTime),
                icon: "timer"
            )
            statisticsCard(
                title: String(localized: "Context Usage", bundle: .module),
                value: String(
                    format: "%.0f%%",
                    averageContextUsage * ChatMetricsDashboardConstants.percentMultiplier
                ),
                icon: "chart.pie"
            )
        }
    }

    private func statisticsCard(title: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: ChatMetricsDashboardConstants.iconWidth)
                .accessibilityLabel(Text("\(title) icon", bundle: .module))

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
        .padding(ChatMetricsDashboardConstants.statisticsCardPadding)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: ChatMetricsDashboardConstants.cornerRadius))
        .shadow(radius: ChatMetricsDashboardConstants.shadowRadius)
    }

    private var conversationChartsSection: some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .flexible(
                        minimum: ChatMetricsDashboardConstants.minColumnWidth,
                        maximum: ChatMetricsDashboardConstants.maxColumnWidth
                    )
                )
            ],
            spacing: ChatMetricsDashboardConstants.spacing
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
        typealias Const = ChatMetricsDashboardConstants

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
        let startIndex: Int = ChatMetricsDashboardConstants.messageIndexStart
        let endIndex: Int = ChatMetricsDashboardConstants.messageIndexEnd
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
        .frame(minWidth: ChatMetricsDashboardConstants.minWidth)
    }

    #Preview("Chat Dashboard - Empty") {
        ChatMetricsDashboard(
            metrics: [],
            chatTitle: "New Chat"
        )
        .frame(minWidth: ChatMetricsDashboardConstants.minWidth)
    }
#endif

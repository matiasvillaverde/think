import Charts
import Database
import SwiftUI

internal struct ModelDashboard: View {
    let metrics: [Metrics]
    let modelName: String

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
        static let cardPadding: CGFloat = 12
        static let iconWidth: CGFloat = 40
        static let percentMultiplier: Double = 100
        static let halfDivisor: CGFloat = 2
        static let minHeight: CGFloat = 300
        static let minWidth: CGFloat = 600
        static let chartHeight: CGFloat = 300
        static let barWidth: CGFloat = 40
        static let recentMessageCount: Int = 20
        static let topChatsLimit: Int = 5
        // Adaptive column counts
        static let iPhoneColumns: Int = 1
        static let iPadPortraitColumns: Int = 2
        static let iPadLandscapeColumns: Int = 3
        static let macOSColumns: Int = 2
        static let visionOSColumns: Int = 3
        static let iPhonePadding: CGFloat = 16
        static let defaultPadding: CGFloat = 20
    }

    @State private var selectedMetric: MetricType = .performance
    @State private var showOnlyRecent: Bool = false

    var currentSelectedMetric: MetricType {
        selectedMetric
    }

    enum MetricType: String, CaseIterable {
        case performance = "Performance"
        case quality = "Quality"
        case resources = "Resources"
        case tokens = "Tokens"

        var icon: String {
            switch self {
            case .performance:
                "speedometer"

            case .quality:
                "star.fill"

            case .resources:
                "memorychip"

            case .tokens:
                "number.circle"
            }
        }
    }

    var filteredMetrics: [Metrics] {
        if showOnlyRecent {
            return Array(metrics.suffix(Constants.recentMessageCount))
        }
        return metrics
    }

    var chatGroups: [(String, [Metrics])] {
        let grouped: [String: [Metrics]] = Dictionary(grouping: filteredMetrics) { metric in
            metric.message?.chat?.id.uuidString ?? "Unknown"
        }
        return grouped
            .sorted { $0.value.count > $1.value.count }
            .prefix(Constants.topChatsLimit)
            .map { ($0.key, $0.value) }
    }

    internal init(metrics: [Metrics], modelName: String) {
        self.metrics = metrics
        self.modelName = modelName
    }

    internal var body: some View {
        AdaptiveScrollContainer {
            VStack(spacing: Constants.spacing) {
                headerView

                Toggle("Show Recent Only", isOn: $showOnlyRecent)
                    .padding(.horizontal)

                metricTypeSelector

                Divider()
                    .padding(.vertical, Constants.dividerPadding)

                if !filteredMetrics.isEmpty {
                    overviewSection
                    selectedMetricSection
                    conversationBreakdownSection
                } else {
                    emptyStateView
                }
            }
            .padding(adaptivePadding)
        }
    }

    private var adaptivePadding: CGFloat {
        #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                return Constants.iPhonePadding
            }
        #endif
        return Constants.defaultPadding
    }

    private var headerView: some View {
        HStack {
            Image(systemName: "cpu")
                .font(.system(size: Constants.headerIconSize))
                .foregroundStyle(.purple)
                .accessibilityLabel("Model icon")

            VStack(alignment: .leading, spacing: Constants.headerSpacing) {
                Text("\(modelName) Dashboard")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                HStack {
                    Text("\(metrics.count) total messages")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)

                    if let dateRange = getDateRange() {
                        Text("• \(dateRange)")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }

            Spacer()
        }
    }

    private var metricTypeSelector: some View {
        Picker("Metric Type", selection: $selectedMetric) {
            ForEach(MetricType.allCases, id: \.self) { type in
                Label(type.rawValue, systemImage: type.icon)
                    .tag(type)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Model Data",
            systemImage: "cpu",
            description: Text("Metrics for \(modelName) will appear here")
        )
        .frame(minHeight: Constants.minHeight)
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: Constants.spacing) {
            Text("Model Overview")
                .font(.headline)
                .padding(.bottom, Constants.headerSpacing)

            overviewGrid
        }
    }

    private var overviewGrid: some View {
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
            overviewCards
        }
    }

    @ViewBuilder private var overviewCards: some View {
        overviewCard(
            title: "Avg Tokens/Second",
            value: String(format: "%.1f", averageTokensPerSecond),
            icon: "speedometer"
        )
        overviewCard(
            title: "Total Tokens Generated",
            value: "\(totalGeneratedTokens)",
            icon: "number"
        )
        overviewCard(
            title: "Avg Response Time",
            value: String(format: "%.2fs", averageResponseTime),
            icon: "timer"
        )
        overviewCard(
            title: "Conversations",
            value: "\(uniqueChats)",
            icon: "bubble.left.and.bubble.right"
        )
        if let avgPerplexity = averagePerplexity {
            overviewCard(
                title: "Avg Perplexity",
                value: String(format: "%.1f", avgPerplexity),
                icon: "chart.line.uptrend.xyaxis"
            )
        }
        if let avgContextUsage = averageContextUsage {
            let percentage: Double = avgContextUsage * Constants.percentMultiplier
            overviewCard(
                title: "Avg Context Usage",
                value: String(format: "%.0f%%", percentage),
                icon: "chart.pie"
            )
        }
    }

    private func overviewCard(title: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.purple)
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
        .padding(Constants.cardPadding)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .shadow(radius: Constants.shadowRadius)
    }
}

#if DEBUG
    #Preview("Model Dashboard - GPT-4") {
        ModelDashboard(
            metrics: (0 ..< 30).map { index in
                Metrics.preview(
                    totalTime: Double.random(in: 1.5 ... 3.5),
                    timeToFirstToken: Double.random(in: 0.1 ... 0.3),
                    promptTokens: Int.random(in: 100 ... 500),
                    generatedTokens: Int.random(in: 500 ... 2_000),
                    contextWindowSize: 4_096,
                    contextTokensUsed: Int.random(in: 1_000 ... 3_000),
                    peakMemory: UInt64.random(in: 10_000_000 ... 100_000_000),
                    perplexity: Double.random(in: 5 ... 20),
                    entropy: Double.random(in: 2 ... 8),
                    repetitionRate: Double.random(in: 0.05 ... 0.3),
                    modelName: "GPT-4",
                    createdAt: Date().addingTimeInterval(Double(index) * 3_600)
                )
            },
            modelName: "GPT-4"
        )
        .frame(minWidth: ModelDashboard.Constants.minWidth)
    }

    #Preview("Model Dashboard - Empty") {
        ModelDashboard(
            metrics: [],
            modelName: "Claude-3"
        )
        .frame(minWidth: ModelDashboard.Constants.minWidth)
    }
#endif

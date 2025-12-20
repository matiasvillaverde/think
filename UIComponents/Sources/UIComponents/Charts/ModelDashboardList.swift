import Charts
import Database
import SwiftUI

/// A redesigned Model Dashboard using List-based layout with card components
public struct ModelDashboardList: View {
    @Binding var metrics: [Metrics]
    @State private var selectedModel: String?
    @State private var selectedChatId: String?
    @State private var expandedSections: Set<String> = ["performance", "timing"]

    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass: UserInterfaceSizeClass?

    private enum Constants {
        static let bytesToMegabytes: Double = 1_048_576
        static let megabytesToGigabytes: Double = 1_024
    }

    public init(metrics: Binding<[Metrics]>) {
        _metrics = metrics
    }

    public var body: some View {
        ChartsDashboardList {
            if metrics.isEmpty {
                emptyStateView
            } else {
                dashboardContent
            }
        }
        .navigationTitle("Model Analytics")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
        #endif
    }

    private var dashboardContent: some View {
        Group {
            // Overview Section
            ChartSection(title: "Overview") {
                overviewCards
            }

            // Performance Section
            ChartSection(
                title: "Performance",
                expandable: true
            ) {
                performanceCards
            }

            // Token Analysis Section
            ChartSection(
                title: "Token Analysis",
                expandable: true
            ) {
                tokenCards
            }

            // Quality Metrics Section (if available)
            if hasQualityMetrics {
                ChartSection(
                    title: "Quality Metrics",
                    expandable: true
                ) {
                    qualityCards
                }
            }

            // Resource Usage Section
            ChartSection(
                title: "Resource Usage",
                expandable: true
            ) {
                resourceCards
            }
        }
    }

    // MARK: - Overview Cards

    private var overviewCards: some View {
        VStack(spacing: ChartConstants.Layout.cardSpacing) {
            // Summary Statistics Card
            ChartCard(
                title: "Summary Statistics",
                subtitle: "Last \(metrics.count) messages",
                systemImage: "chart.bar.doc.horizontal"
            ) {
                summaryStatsContent
            }

            // Model Comparison (if multiple models)
            if uniqueModelNames.count > 1 {
                ModelComparisonChartCard(metrics: metrics)
            }
        }
    }

    private var summaryStatsContent: some View {
        LazyVGrid(
            columns: statsGridColumns,
            spacing: ChartConstants.Layout.sectionSpacing
        ) {
            primaryStatsBoxes
            if let avgQuality = averageQuality {
                StatBox(
                    title: "Avg Quality",
                    value: String(format: "%.2f", avgQuality),
                    icon: "star",
                    color: .purple
                )
            }
            secondaryStatsBoxes
        }
    }

    private var statsGridColumns: [GridItem] {
        [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ]
    }

    @ViewBuilder private var primaryStatsBoxes: some View {
        StatBox(
            title: "Total Messages",
            value: "\(metrics.count)",
            icon: "message",
            color: .blue
        )

        StatBox(
            title: "Avg Speed",
            value: String(format: "%.1f tok/s", averageSpeed),
            icon: "speedometer",
            color: .green
        )

        StatBox(
            title: "Total Tokens",
            value: "\(totalTokens)",
            icon: "number",
            color: .orange
        )
    }

    @ViewBuilder private var secondaryStatsBoxes: some View {
        StatBox(
            title: "Memory Usage",
            value: formatMemory(averageMemory),
            icon: "memorychip",
            color: .red
        )

        StatBox(
            title: "Models Used",
            value: "\(uniqueModelNames.count)",
            icon: "cpu",
            color: .indigo
        )
    }

    // MARK: - Performance Cards

    private var performanceCards: some View {
        VStack(spacing: ChartConstants.Layout.cardSpacing) {
            PerformanceChartCard(metrics: filteredMetrics)
            ProcessingTimeBreakdownCard(metrics: filteredMetrics)
        }
    }

    // MARK: - Token Cards

    private var tokenCards: some View {
        VStack(spacing: ChartConstants.Layout.cardSpacing) {
            TokenTimingChartCard(metrics: filteredMetrics)
            TokenDistributionCard(metrics: filteredMetrics)
            TokenProbabilityScatterPlotCard(metrics: filteredMetrics)
        }
    }

    // MARK: - Quality Cards

    private var qualityCards: some View {
        VStack(spacing: ChartConstants.Layout.cardSpacing) {
            EntropyChartCard(metrics: filteredMetrics)
            PerplexityHeatMapCard(metrics: filteredMetrics)
            RepetitionRateTrendLineCard(metrics: filteredMetrics)
        }
    }

    // MARK: - Resource Cards

    private var resourceCards: some View {
        VStack(spacing: ChartConstants.Layout.cardSpacing) {
            MemoryUsageCard(metrics: filteredMetrics)

            if hasContextData {
                ContextUtilizationCard(metrics: filteredMetrics)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ChartCard(
            title: "No Data Available",
            systemImage: "chart.bar.xaxis"
        ) {
            ContentUnavailableView(
                "No Metrics Yet",
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text("Start a conversation to see analytics")
            )
            .frame(height: ChartConstants.Layout.chartHeight)
        }
    }

    // MARK: - Helper Properties

    private var filteredMetrics: [Metrics] {
        var filtered: [Metrics] = metrics

        if let model = selectedModel {
            filtered = filtered.filter { $0.modelName == model }
        }

        // Note: chatId filtering removed as Metrics doesn't have chatId property
        // This can be added back when the Metrics model is updated

        return filtered
    }

    private var uniqueModelNames: Set<String> {
        Set(metrics.compactMap(\.modelName))
    }

    private var hasQualityMetrics: Bool {
        metrics.contains { metric in
            metric.perplexity != nil ||
                metric.entropy != nil ||
                metric.repetitionRate != nil
        }
    }

    private var hasContextData: Bool {
        metrics.contains { $0.contextUtilization != nil }
    }

    private var averageSpeed: Double {
        let speeds: [Double] = metrics.map(\.tokensPerSecond)
        return speeds.isEmpty ? 0 : speeds.reduce(0, +) / Double(speeds.count)
    }

    private var totalTokens: Int {
        metrics.map(\.totalTokens).reduce(0, +)
    }

    private var averageQuality: Double? {
        let qualities: [Double] = metrics.compactMap(\.perplexity)
        return qualities.isEmpty ? nil : qualities.reduce(0, +) / Double(qualities.count)
    }

    private var averageMemory: UInt64 {
        let memories: [UInt64] = metrics.map(\.activeMemory)
        return memories.isEmpty ? 0 : memories.reduce(0, +) / UInt64(memories.count)
    }

    private func formatMemory(_ bytes: UInt64) -> String {
        let megabytes: Double = Double(bytes) / Constants.bytesToMegabytes
        if megabytes < Constants.megabytesToGigabytes {
            return String(format: "%.1f MB", megabytes)
        }
        return String(format: "%.2f GB", megabytes / Constants.megabytesToGigabytes)
    }

    private func isExpanded(_ section: String) -> Binding<Bool> {
        Binding(
            get: { expandedSections.contains(section) },
            set: { isExpanded in
                if isExpanded {
                    expandedSections.insert(section)
                } else {
                    expandedSections.remove(section)
                }
            }
        )
    }
}

// MARK: - Supporting Views

private struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    private enum Constants {
        static let spacing: CGFloat = 8
        static let iconSize: CGFloat = 24
        static let valueFontSize: CGFloat = 18
        static let verticalPadding: CGFloat = 12
        static let backgroundOpacity: Double = 0.1
        static let cornerRadius: CGFloat = 8
    }

    var body: some View {
        VStack(spacing: Constants.spacing) {
            Image(systemName: icon)
                .font(.system(size: Constants.iconSize))
                .foregroundColor(color)
                .accessibilityHidden(true)

            Text(value)
                .font(.system(size: Constants.valueFontSize, weight: .bold))
                .foregroundColor(.primary)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Constants.verticalPadding)
        .background(color.opacity(Constants.backgroundOpacity))
        .cornerRadius(Constants.cornerRadius)
    }
}

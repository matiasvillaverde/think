import Database
import Foundation
import SwiftUI

internal struct MetricsDashboard: View {
    let metrics: [Metrics]

    private enum Constants {
        static let gridSpacing: CGFloat = 16
        static let minColumnWidth: CGFloat = 300
        static let maxColumnWidth: CGFloat = 500
        static let headerIconSize: CGFloat = 30
        static let cornerRadius: CGFloat = 12
        static let shadowRadius: CGFloat = 2
    }

    @State private var selectedTab: DashboardTab = .overview

    private enum DashboardTab: String, CaseIterable {
        case overview = "Overview"
        case performance = "Performance"
        case quality = "Quality"
        case resources = "Resources"

        var title: String {
            // Raw values are user-facing English strings for the dashboard tabs.
            // If/when we localize them, switch to explicit localization keys.
            rawValue
        }

        var icon: String {
            switch self {
            case .overview:
                "square.grid.2x2"

            case .performance:
                "speedometer"

            case .quality:
                "star"

            case .resources:
                "cpu"
            }
        }
    }

    internal init(metrics: [Metrics]) {
        self.metrics = metrics
    }

    internal var body: some View {
        VStack(spacing: Constants.gridSpacing) {
            headerView
            tabSelector

            ScrollView {
                switch selectedTab {
                case .overview:
                    overviewContent

                case .performance:
                    performanceContent

                case .quality:
                    qualityContent

                case .resources:
                    resourcesContent
                }
            }
        }
        .padding()
    }

    private var headerView: some View {
        HStack {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: Constants.headerIconSize))
                .foregroundStyle(.blue)
                .accessibilityLabel(Text("Dashboard icon", bundle: .module))

            Text("Metrics Dashboard", bundle: .module)
                .font(.largeTitle)
                .fontWeight(.bold)

            Spacer()

            if !metrics.isEmpty {
                Text("\(metrics.count) Messages", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    private var tabSelector: some View {
        Picker(selection: $selectedTab) {
            ForEach(DashboardTab.allCases, id: \.self) { tab in
                Label {
                    Text(tab.title)
                } icon: {
                    Image(systemName: tab.icon)
                        .accessibilityHidden(true)
                }
                    .tag(tab)
            }
        } label: {
            Text("Dashboard Tab", bundle: .module)
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder private var overviewContent: some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .flexible(minimum: Constants.minColumnWidth, maximum: Constants.maxColumnWidth)
                ),
                GridItem(
                    .flexible(minimum: Constants.minColumnWidth, maximum: Constants.maxColumnWidth)
                )
            ],
            spacing: Constants.gridSpacing
        ) {
            if let latestMetric = metrics.last {
                MetricsSummaryCard(metrics: latestMetric)
            }

            PerformanceChartCard(metrics: metrics)
            TokenDistributionCard(metrics: metrics)
            // ContextUtilizationGauge(metric: metrics.last) // Not implemented yet
        }
    }

    @ViewBuilder private var performanceContent: some View {
        VStack(spacing: Constants.gridSpacing) {
            PerformanceChartCard(metrics: metrics)
            TokenTimingChartCard(metrics: metrics)
            ProcessingTimeBreakdownCard(metrics: metrics)
            ModelComparisonChartCard(metrics: metrics)
        }
    }

    @ViewBuilder private var qualityContent: some View {
        VStack(spacing: Constants.gridSpacing) {
            PerplexityHeatMapCard(metrics: metrics)
            EntropyChartCard(metrics: metrics)
            RepetitionRateTrendLineCard(metrics: metrics)
            TokenProbabilityScatterPlotCard(metrics: metrics)
        }
    }

    @ViewBuilder private var resourcesContent: some View {
        VStack(spacing: Constants.gridSpacing) {
            MemoryUsageCard(metrics: metrics)
            TokenDistributionCard(metrics: metrics)
            if let latestMetric = metrics.last {
                ContextUtilizationCard(metrics: [latestMetric])
                MetricsSummaryCard(metrics: latestMetric)
            }
        }
    }
}

#if DEBUG
    #Preview("Metrics Dashboard - With Data") {
        MetricsDashboard(
            metrics: (0 ..< 10).map { index in
                Metrics.preview(
                    totalTime: Double.random(in: 0.5 ... 3.0),
                    timeToFirstToken: Double.random(in: 0.1 ... 0.3),
                    promptTokens: Int.random(in: 100 ... 1_000),
                    generatedTokens: Int.random(in: 500 ... 2_000),
                    totalTokens: Int.random(in: 600 ... 3_000),
                    contextWindowSize: 4_096,
                    contextTokensUsed: Int.random(in: 600 ... 3_000),
                    peakMemory: UInt64.random(in: 10_000_000 ... 100_000_000),
                    createdAt: Date().addingTimeInterval(Double(index) * 3_600)
                )
            }
        )
    }
#endif

#if DEBUG
    #Preview("Metrics Dashboard - Empty") {
        MetricsDashboard(metrics: [])
    }
#endif

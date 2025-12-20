import Charts
import Database
import SwiftUI

/// Charts section of the dashboard
internal struct DashboardChartsSection: View {
    let metrics: [Metrics]

    private var hasQualityMetrics: Bool {
        metrics.contains { metric in
            metric.perplexity != nil ||
                metric.entropy != nil ||
                metric.repetitionRate != nil
        }
    }

    private var hasMultipleModels: Bool {
        Set(metrics.compactMap(\.modelName)).count > 1
    }

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .flexible(
                        minimum: AppWideDashboard.Constants.minColumnWidth,
                        maximum: AppWideDashboard.Constants.maxColumnWidth
                    )
                )
            ],
            spacing: AppWideDashboard.Constants.spacing
        ) {
            PerformanceChartCard(metrics: metrics)
            TokenTimingChartCard(metrics: metrics)

            if hasQualityMetrics {
                EntropyChartCard(metrics: metrics)
                PerplexityHeatMapCard(metrics: metrics)
            }

            MemoryUsageCard(metrics: metrics)
            TokenDistributionCard(metrics: metrics)

            if hasMultipleModels {
                ModelComparisonChartCard(metrics: metrics)
            }
        }
    }
}

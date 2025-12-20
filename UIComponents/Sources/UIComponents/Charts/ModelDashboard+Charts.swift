import Charts
import Database
import SwiftUI

extension ModelDashboard {
    @ViewBuilder var selectedMetricSection: some View {
        VStack(alignment: .leading, spacing: Constants.spacing) {
            Text("\(currentSelectedMetric.rawValue) Analysis")
                .font(.headline)
                .padding(.bottom, Constants.headerSpacing)

            switch currentSelectedMetric {
            case .performance:
                performanceCharts

            case .quality:
                qualityCharts

            case .resources:
                resourceCharts

            case .tokens:
                tokenCharts
            }
        }
    }

    var performanceCharts: some View {
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
            PerformanceChartCard(metrics: filteredMetrics)
            TokenTimingChartCard(metrics: filteredMetrics)
            ProcessingTimeBreakdownCard(metrics: filteredMetrics)
        }
    }

    var qualityCharts: some View {
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
            if hasQualityMetrics {
                EntropyChartCard(metrics: filteredMetrics)
                RepetitionRateTrendLineCard(metrics: filteredMetrics)
                PerplexityHeatMapCard(metrics: filteredMetrics)
            } else {
                ContentUnavailableView(
                    "No Quality Metrics",
                    systemImage: "star",
                    description: Text("Quality metrics not available for this model")
                )
                .frame(minHeight: Constants.minHeight)
            }
        }
    }

    var resourceCharts: some View {
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
            MemoryUsageCard(metrics: filteredMetrics)

            if hasContextData {
                ForEach(filteredMetrics.prefix(1)) { metric in
                    ContextUtilizationCard(metrics: [metric])
                }
            }
        }
    }

    var tokenCharts: some View {
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
            TokenDistributionCard(metrics: filteredMetrics)
            TokenProbabilityScatterPlotCard(metrics: filteredMetrics)
            tokenTrendChart
        }
    }

    var tokenTrendChart: some View {
        VStack(alignment: .leading, spacing: Constants.headerSpacing) {
            Text("Token Generation Trend")
                .font(.headline)

            Chart(Array(filteredMetrics.enumerated()), id: \.offset) { index, metric in
                LineMark(
                    x: .value("Message", index),
                    y: .value("Tokens", metric.generatedTokens)
                )
                .foregroundStyle(.purple)

                PointMark(
                    x: .value("Message", index),
                    y: .value("Tokens", metric.generatedTokens)
                )
                .foregroundStyle(.purple)
            }
            .frame(height: Constants.chartHeight)
            .padding()
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
            .shadow(radius: Constants.shadowRadius)
        }
    }

    var conversationBreakdownSection: some View {
        VStack(alignment: .leading, spacing: Constants.spacing) {
            Text("Top Conversations")
                .font(.headline)
                .padding(.bottom, Constants.headerSpacing)

            ForEach(chatGroups, id: \.0) { chatId, chatMetrics in
                conversationCard(chatId: chatId, metrics: chatMetrics)
            }
        }
    }

    func conversationCard(chatId: String, metrics: [Metrics]) -> some View {
        VStack(alignment: .leading, spacing: Constants.headerSpacing) {
            HStack {
                Text("Chat: \(chatId)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text("\(metrics.count) messages")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: Constants.spacing) {
                statLabel(
                    "Avg Speed",
                    value: String(format: "%.1f tok/s", calculateAverageSpeed(metrics))
                )

                statLabel(
                    "Total Tokens",
                    value: "\(calculateTotalTokens(metrics))"
                )

                if let avgQuality = calculateAverageQuality(metrics) {
                    statLabel(
                        "Avg Quality",
                        value: String(format: "%.1f", avgQuality)
                    )
                }
            }
        }
        .padding(Constants.cardPadding)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .shadow(radius: Constants.shadowRadius)
    }

    func statLabel(_ title: String, value: String) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

import Charts
import Database
import SwiftUI

extension ModelDashboard {
    @ViewBuilder var selectedMetricSection: some View {
        VStack(alignment: .leading, spacing: Constants.spacing) {
            Text("\(currentSelectedMetric.rawValue) Analysis", bundle: .module)
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
                    String(localized: "No Quality Metrics", bundle: .module),
                    systemImage: "star",
                    description: Text(
                        "Quality metrics not available for this model",
                        bundle: .module
                    )
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
            Text("Token Generation Trend", bundle: .module)
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
            Text("Top Conversations", bundle: .module)
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
                Text("Chat: \(chatId)", bundle: .module)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text("\(metrics.count) messages", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }

            HStack(spacing: Constants.spacing) {
                statLabel(
                    String(localized: "Avg Speed", bundle: .module),
                    value: String(format: "%.1f tok/s", calculateAverageSpeed(metrics))
                )

                statLabel(
                    String(localized: "Total Tokens", bundle: .module),
                    value: "\(calculateTotalTokens(metrics))"
                )

                if let avgQuality = calculateAverageQuality(metrics) {
                    statLabel(
                        String(localized: "Avg Quality", bundle: .module),
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
                .foregroundStyle(Color.textSecondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

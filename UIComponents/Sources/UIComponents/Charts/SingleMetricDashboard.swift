import Database
import SwiftUI

internal struct SingleMetricDashboard: View {
    let metric: Metrics
    let modelInfo: String?
    let systemPrompt: String?

    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass: UserInterfaceSizeClass?
    @Environment(\.verticalSizeClass)
    private var verticalSizeClass: UserInterfaceSizeClass?

    enum Constants {
        static let spacing: CGFloat = 16
        static let minColumnWidth: CGFloat = 250
        static let maxColumnWidth: CGFloat = 400
        static let cornerRadius: CGFloat = 12
        static let shadowRadius: CGFloat = 2
        static let headerIconSize: CGFloat = 30
        static let dividerPadding: CGFloat = 8
        static let headerSpacing: CGFloat = 8
        static let cardPadding: CGFloat = 12
        static let maxPromptLines: Int = 3
        static let minWindowWidth: CGFloat = 600
        static let scrollViewPadding: CGFloat = 20
        static let iPhonePadding: CGFloat = 16

        // Platform-specific column counts
        static let iPhoneColumns: Int = 1
        static let iPadPortraitColumns: Int = 2
        static let iPadLandscapeColumns: Int = 3
        static let macOSColumns: Int = 2
        static let visionOSColumns: Int = 3
    }

    internal init(metric: Metrics, modelInfo: String? = nil, systemPrompt: String? = nil) {
        self.metric = metric
        self.modelInfo = modelInfo
        self.systemPrompt = systemPrompt
    }

    internal var body: some View {
        AdaptiveScrollContainer {
            VStack(spacing: Constants.spacing) {
                headerView
                modelInfoView
                systemPromptView

                Divider()
                    .padding(.vertical, Constants.dividerPadding)

                metricsContent
            }
            .padding(scrollPadding)
        }
    }

    private var scrollPadding: CGFloat {
        #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                return Constants.iPhonePadding
            }
            return Constants.scrollViewPadding
        #else
            return Constants.scrollViewPadding
        #endif
    }

    private var headerView: some View {
        HStack {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: Constants.headerIconSize))
                .foregroundStyle(.blue)
                .accessibilityLabel("Dashboard icon")

            VStack(alignment: .leading, spacing: Constants.headerSpacing) {
                Text("Message Metrics")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Created: \(metric.createdAt.formatted())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    @ViewBuilder private var modelInfoView: some View {
        if let modelInfo = modelInfo ?? metric.modelName {
            HStack {
                Label("Model", systemImage: "cpu")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(modelInfo)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(Constants.cardPadding)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
            .shadow(radius: Constants.shadowRadius)
        }
    }

    @ViewBuilder private var systemPromptView: some View {
        if let systemPrompt {
            VStack(alignment: .leading, spacing: Constants.headerSpacing) {
                Label("System Prompt", systemImage: "text.alignleft")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(systemPrompt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(Constants.maxPromptLines)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Constants.cardPadding)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
            .shadow(radius: Constants.shadowRadius)
        }
    }

    private var adaptiveColumns: [GridItem] {
        let columnCount: Int = adaptiveColumnCount
        return Array(
            repeating: GridItem(.flexible(minimum: Constants.minColumnWidth, maximum: .infinity)),
            count: columnCount
        )
    }

    private var adaptiveColumnCount: Int {
        #if os(macOS)
            return Constants.macOSColumns
        #elseif os(visionOS)
            return Constants.visionOSColumns
        #elseif os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                return Constants.iPhoneColumns
            }
            // iPad
            if horizontalSizeClass == .regular, verticalSizeClass == .regular {
                return Constants.iPadLandscapeColumns
            }
            return Constants.iPadPortraitColumns
        #else
            return Constants.macOSColumns // Default fallback
        #endif
    }

    @ViewBuilder private var metricsContent: some View {
        LazyVGrid(
            columns: adaptiveColumns,
            spacing: Constants.spacing
        ) {
            // Summary card always shows
            MetricsSummaryCard(metrics: metric)

            // Context utilization gauge
            ContextUtilizationCard(metrics: [metric])

            // Processing time breakdown
            ProcessingTimeBreakdownCard(metrics: [metric])

            // Token timing (single metric view)
            TokenTimingChartCard(metrics: [metric])

            // Memory usage (if available)
            if metric.peakMemory > 0 {
                MemoryUsageCard(metrics: [metric])
            }

            // Token distribution
            TokenDistributionCard(metrics: [metric])

            // Quality metrics if available
            if metric.perplexity != nil {
                PerplexityHeatMapCard(metrics: [metric])
            }

            if metric.entropy != nil {
                EntropyChartCard(metrics: [metric])
            }

            if metric.repetitionRate != nil {
                RepetitionRateTrendLineCard(metrics: [metric])
            }

            // Token probability scatter plot
            // Note: Currently showing for all metrics, as logProbs is computed internally
            TokenProbabilityScatterPlotCard(metrics: [metric])
        }
    }
}

#if DEBUG
    #Preview("Single Metric Dashboard - Full Data") {
        SingleMetricDashboard(
            metric: Metrics.preview(
                totalTime: 2.5,
                timeToFirstToken: 0.15,
                promptTokens: 500,
                generatedTokens: 1_500,
                totalTokens: 2_000,
                contextWindowSize: 4_096,
                contextTokensUsed: 2_000,
                peakMemory: 52_428_800,
                perplexity: 12.5,
                entropy: 4.2,
                repetitionRate: 0.15,
                modelName: "GPT-4 Turbo",
                createdAt: Date()
            ),
            modelInfo: "GPT-4 Turbo (128k context)",
            systemPrompt: """
            You are a helpful AI assistant. Be concise and clear in your responses. \
            Focus on providing accurate information and helpful suggestions.
            """
        )
        .frame(minWidth: 800)
    }

    #Preview("Single Metric Dashboard - Minimal Data") {
        SingleMetricDashboard(
            metric: Metrics.preview(
                totalTime: 1.5,
                promptTokens: 100,
                generatedTokens: 500,
                totalTokens: 600
            )
        )
        .frame(minWidth: 800)
    }
#endif

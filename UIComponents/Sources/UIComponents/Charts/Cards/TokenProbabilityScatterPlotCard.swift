import Charts
import Database
import SwiftUI

/// Token Probability Scatter Plot wrapped in a card container
internal struct TokenProbabilityScatterPlotCard: View {
    let metrics: [Metrics]

    @State private var selectedTokenType: TokenType = .all
    @State private var showTrendLine: Bool = true
    @State private var showConfidenceBands: Bool = false
    @State private var dataHasAppeared: Bool = false
    @State private var hoveredPoint: TokenProbability?
    @StateObject private var viewModel: TokenProbabilityViewModel

    private enum Constants {
        static let chartHeight: CGFloat = 250
        static let animationDuration: Double = 0.8
        static let animationDelay: Double = 0.2
        static let maxDataPoints: Int = 100
        static let maxMetricsCount: Int = 10
        static let maxTokensPerMetric: Int = 50
        static let minProbability: Double = 0.0
        static let maxProbability: Double = 1.0
        static let minTokenLength: Int = 1
        static let maxTokenLength: Int = 10
        static let highThreshold: Double = 0.7
        static let lowThreshold: Double = 0.3
    }

    init(metrics: [Metrics]) {
        self.metrics = metrics
        _viewModel = StateObject(wrappedValue: TokenProbabilityViewModel(metrics: metrics))
    }

    var body: some View {
        ChartCard(
            title: "Token Probability Distribution",
            subtitle: "Confidence levels across tokens",
            systemImage: "chart.scatter"
        ) {
            chartContent
        } controls: {
            controlsContent
        }
    }

    private var chartContent: some View {
        VStack(spacing: ChartConstants.Layout.cardSpacing) {
            if tokenProbabilities.isEmpty {
                emptyStateView
            } else {
                scatterPlot
                TokenProbabilityLegend(viewModel: viewModel)
                TokenProbabilityStats(
                    filteredProbabilities: filteredProbabilities,
                    viewModel: viewModel
                )
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Probability Data",
            systemImage: "chart.scatter",
            description: Text("Token probabilities will appear here")
        )
        .frame(height: Constants.chartHeight)
    }

    private var scatterPlot: some View {
        TokenProbabilityChart(
            filteredProbabilities: filteredProbabilities,
            showTrendLine: showTrendLine,
            showConfidenceBands: showConfidenceBands,
            dataHasAppeared: dataHasAppeared,
            hoveredPoint: hoveredPoint,
            viewModel: viewModel,
            chartHeight: Constants.chartHeight,
            animationDuration: Constants.animationDuration,
            config: config
        )
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
        TokenProbabilityControls(
            selectedTokenType: $selectedTokenType,
            showTrendLine: $showTrendLine,
            showConfidenceBands: $showConfidenceBands
        )
    }

    private var config: TokenProcessingConfig {
        TokenProcessingConfig(
            maxMetricsCount: Constants.maxMetricsCount,
            maxTokensPerMetric: Constants.maxTokensPerMetric,
            minProbability: Constants.minProbability,
            maxProbability: Constants.maxProbability,
            minTokenLength: Constants.minTokenLength,
            maxTokenLength: Constants.maxTokenLength,
            maxDataPoints: Constants.maxDataPoints
        )
    }

    private var tokenProbabilities: [TokenProbability] {
        viewModel.getTokenProbabilities(config: config)
    }

    private var filteredProbabilities: [TokenProbability] {
        viewModel.filteredProbabilities(
            from: tokenProbabilities,
            selectedType: selectedTokenType,
            highThreshold: Constants.highThreshold,
            lowThreshold: Constants.lowThreshold
        )
    }
}

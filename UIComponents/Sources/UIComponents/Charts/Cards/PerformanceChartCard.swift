import Charts
import Database
import SwiftUI

/// Performance Line Chart wrapped in a card container
public struct PerformanceChartCard: View {
    let metrics: [Metrics]

    @State private var selectedMetrics: Set<PerformanceLineChart.PerformanceMetric> = [
        .totalTime,
        .tokensPerSecond
    ]
    @State private var timeRange: PerformanceLineChart.TimeRange = .lastHour
    @State private var autoRefresh: Bool = false
    @State private var showCustomization: Bool = false
    @State private var dataHasAppeared: Bool = false
    @StateObject private var viewModel: PerformanceChartViewModel

    private enum Constants {
        static let dataAnimationDuration: Double = 0.5
        static let dataAnimationDelay: Double = 0.3
    }

    public init(metrics: [Metrics]) {
        self.metrics = metrics
        _viewModel = StateObject(wrappedValue: PerformanceChartViewModel(metrics: metrics))
    }

    public var body: some View {
        ChartCard(
            title: "Performance Metrics",
            subtitle: "\(filteredMetrics.count) data points",
            systemImage: "chart.line.uptrend.xyaxis"
        ) {
            chartContent
        } controls: {
            controlsContent
        }
    }

    private var chartContent: some View {
        VStack(spacing: ChartConstants.Layout.itemSpacing) {
            if filteredMetrics.isEmpty {
                emptyStateView
            } else {
                performanceChart
                PerformanceLegend(selectedMetrics: $selectedMetrics)
                if !selectedMetrics.isEmpty {
                    PerformanceStats(
                        selectedMetrics: selectedMetrics,
                        timeRange: timeRange,
                        viewModel: viewModel
                    )
                }
            }
        }
    }

    private var emptyStateView: some View {
        EmptyChartView(message: "No performance data available")
            .frame(height: ChartConstants.Layout.chartHeight)
    }

    private var performanceChart: some View {
        PerformanceChart(
            performanceData: performanceData,
            dataHasAppeared: dataHasAppeared
        )
        .animation(
            .easeInOut(duration: Constants.dataAnimationDuration),
            value: dataHasAppeared
        )
        .animation(.easeInOut, value: selectedMetrics)
        .animation(.easeInOut, value: timeRange)
        .onAppear {
            withAnimation(
                .easeInOut(duration: Constants.dataAnimationDuration)
                    .delay(Constants.dataAnimationDelay)
            ) {
                dataHasAppeared = true
            }
        }
    }

    private var controlsContent: some View {
        PerformanceControls(
            timeRange: $timeRange,
            autoRefresh: $autoRefresh,
            showCustomization: $showCustomization,
            selectedMetrics: $selectedMetrics
        )
    }

    private var filteredMetrics: [Metrics] {
        viewModel.filteredMetrics(timeRange: timeRange)
    }

    private var performanceData: [PerformanceLineChart.PerformanceData] {
        viewModel.performanceData(for: selectedMetrics, timeRange: timeRange)
    }
}

import Charts
import Database
import Foundation
import SwiftUI

/// Memory Usage Chart wrapped in a card container
public struct MemoryUsageCard: View {
    let metrics: [Metrics]

    @State private var showPeakMemory: Bool = true
    @State private var showActiveMemory: Bool = true
    @State private var timeRange: MemoryTimeRange = .last10
    @State private var dataHasAppeared: Bool = false
    @StateObject private var viewModel: MemoryUsageViewModel

    private enum Constants {
        static let chartHeight: CGFloat = 200
        static let animationDuration: Double = 0.7
        static let animationDelay: Double = 0.2
    }

    public init(metrics: [Metrics]) {
        self.metrics = metrics
        _viewModel = StateObject(wrappedValue: MemoryUsageViewModel(metrics: metrics))
    }

    public var body: some View {
        ChartCard(
            title: String(localized: "Memory Usage", bundle: .module),
            subtitle: String(localized: "Active and peak memory", bundle: .module),
            systemImage: "memorychip"
        ) {
            chartContent
        } controls: {
            controlsContent
        }
    }

    private var chartContent: some View {
        VStack(spacing: ChartConstants.Layout.cardSpacing) {
            if memoryData.isEmpty {
                emptyStateView
            } else {
                memoryChart
                MemoryUsageLegend()
                MemoryUsageStats(
                    memoryData: memoryData,
                    viewModel: viewModel
                )
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            String(localized: "No Memory Data", bundle: .module),
            systemImage: "memorychip",
            description: Text("Memory usage will appear here", bundle: .module)
        )
        .frame(height: Constants.chartHeight)
    }

    private var memoryChart: some View {
        MemoryUsageChart(
            memoryData: memoryData,
            showPeakMemory: showPeakMemory,
            showActiveMemory: showActiveMemory,
            dataHasAppeared: dataHasAppeared,
            viewModel: viewModel,
            chartHeight: Constants.chartHeight
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
        MemoryUsageControls(
            timeRange: $timeRange,
            showPeakMemory: $showPeakMemory,
            showActiveMemory: $showActiveMemory
        )
    }

    private var memoryData: [MemoryData] {
        viewModel.memoryData(timeRange: timeRange)
    }
}

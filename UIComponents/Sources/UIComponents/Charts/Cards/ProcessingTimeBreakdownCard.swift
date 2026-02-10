import Charts
import Database
import Foundation
import SwiftUI

/// Processing Time Breakdown Chart wrapped in a card container
public struct ProcessingTimeBreakdownCard: View {
    let metrics: [Metrics]

    @State private var sortOrder: ProcessingSortOrder = .byTotal
    @State private var showPercentages: Bool = true
    @State private var maxItems: Int = 5
    @State private var dataHasAppeared: Bool = false
    @StateObject private var viewModel: ProcessingTimeViewModel

    enum Constants {
        static let chartHeight: CGFloat = 250
        static let barHeight: CGFloat = 28
        static let animationDuration: Double = 0.6
        static let animationDelay: Double = 0.1
        static let maxItemsLimit: Int = 10
        static let minItems: Int = 3
        static let verticalSpacing: CGFloat = 2
        static let spacingMultiplier: CGFloat = 3
        static let legendRectSize: CGFloat = 10
    }

    public init(metrics: [Metrics]) {
        self.metrics = metrics
        _viewModel = StateObject(wrappedValue: ProcessingTimeViewModel(metrics: metrics))
    }

    public var body: some View {
        ChartCard(
            title: String(localized: "Processing Time Breakdown", bundle: .module),
            subtitle: String(localized: "Time spent in each stage", bundle: .module),
            systemImage: "clock.arrow.circlepath"
        ) {
            chartContent
        } controls: {
            controlsContent
        }
    }

    private var chartContent: some View {
        VStack(spacing: ChartConstants.Layout.cardSpacing) {
            if processingData.isEmpty {
                emptyStateView
            } else {
                breakdownChart
                ProcessingTimeLegend(
                    processingData: processingData,
                    legendRectSize: Constants.legendRectSize,
                    legendItemSpacing: ChartConstants.Layout.itemSpacing
                )
                ProcessingTimeStats(
                    processingData: processingData,
                    viewModel: viewModel,
                    verticalSpacing: Constants.verticalSpacing
                )
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            String(localized: "No Processing Data", bundle: .module),
            systemImage: "clock.badge.xmark",
            description: Text("Processing time data will appear here", bundle: .module)
        )
        .frame(height: Constants.chartHeight)
    }

    private var breakdownChart: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(
                alignment: .leading,
                spacing: ChartConstants.Layout.itemSpacing * Constants.spacingMultiplier
            ) {
                ForEach(Array(processingData.enumerated()), id: \.offset) { index, data in
                    ProcessingTimeRow(
                        data: data,
                        index: index,
                        showPercentages: showPercentages,
                        dataHasAppeared: dataHasAppeared,
                        maxTotalTime: maxTotalTime
                    )
                }
            }
            .padding(.vertical, ChartConstants.Layout.itemSpacing)
        }
        .frame(height: Constants.chartHeight)
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
        VStack(spacing: ChartConstants.Layout.cardSpacing) {
            ProcessingTimeControls(
                sortOrder: $sortOrder,
                showPercentages: $showPercentages,
                maxItems: $maxItems,
                maxItemsLimit: Constants.maxItemsLimit,
                minItems: Constants.minItems
            )
        }
    }

    private var processingData: [ProcessingData] {
        viewModel.processingData(maxItems: maxItems, sortOrder: sortOrder)
    }

    private var maxTotalTime: Double {
        processingData.map(\.total).max() ?? 1
    }
}

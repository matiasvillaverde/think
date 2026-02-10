import Charts
import Database
import Foundation
import SwiftUI

/// Repetition Rate Trend Line Chart wrapped in a card container
public struct RepetitionRateTrendLineCard: View {
    let metrics: [Metrics]

    @State private var selectedNGram: NGramLevel = .bigram
    @State private var showTrend: Bool = true
    @State private var showBaseline: Bool = true
    @State private var dataHasAppeared: Bool = false
    @StateObject private var viewModel: RepetitionRateViewModel

    private enum Constants {
        static let chartHeight: CGFloat = 200
        static let animationDuration: Double = 0.8
        static let animationDelay: Double = 0.2
        static let maxDataPoints: Int = 30
    }

    public init(metrics: [Metrics]) {
        self.metrics = metrics
        _viewModel = StateObject(wrappedValue: RepetitionRateViewModel(metrics: metrics))
    }

    public var body: some View {
        ChartCard(
            title: String(localized: "Repetition Rate Trend", bundle: .module),
            subtitle: String(localized: "N-gram repetition patterns", bundle: .module),
            systemImage: "repeat"
        ) {
            chartContent
        } controls: {
            controlsContent
        }
    }

    private var chartContent: some View {
        VStack(spacing: ChartConstants.Layout.cardSpacing) {
            if repetitionData.isEmpty {
                emptyStateView
            } else {
                trendChart
                RepetitionRateStats(
                    repetitionData: repetitionData,
                    viewModel: viewModel
                )
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            String(localized: "No Repetition Data", bundle: .module),
            systemImage: "repeat",
            description: Text("Repetition rate trends will appear here", bundle: .module)
        )
        .frame(height: Constants.chartHeight)
    }

    private var trendChart: some View {
        RepetitionRateChart(
            repetitionData: repetitionData,
            showTrend: showTrend,
            showBaseline: showBaseline,
            dataHasAppeared: dataHasAppeared,
            selectedNGram: selectedNGram,
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
        RepetitionRateControls(
            selectedNGram: $selectedNGram,
            showTrend: $showTrend,
            showBaseline: $showBaseline
        )
    }

    private var repetitionData: [RepetitionData] {
        viewModel.repetitionData(for: selectedNGram, maxPoints: Constants.maxDataPoints)
    }
}

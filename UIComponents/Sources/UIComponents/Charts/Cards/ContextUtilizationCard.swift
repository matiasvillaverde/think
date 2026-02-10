import Charts
import Database
import Foundation
import SwiftUI

/// Context Utilization Chart wrapped in a card container
public struct ContextUtilizationCard: View {
    let metrics: [Metrics]

    @State private var showFillArea: Bool = true
    @State private var showDataPoints: Bool = true
    @State private var contextCapacity: Int = 2_048
    @State private var dataHasAppeared: Bool = false
    @StateObject private var viewModel: ContextUtilizationViewModel

    private enum Constants {
        static let chartHeight: CGFloat = 200
        static let animationDuration: Double = 0.8
        static let animationDelay: Double = 0.2
        static let maxDataPoints: Int = 20
        // swiftlint:disable:next no_magic_numbers
        static let capacityOptions: [Int] = [1_024, 2_048, 4_096, 8_192]
    }

    public init(metrics: [Metrics]) {
        self.metrics = metrics
        _viewModel = StateObject(wrappedValue: ContextUtilizationViewModel(metrics: metrics))
    }

    public var body: some View {
        ChartCard(
            title: String(localized: "Context Window Utilization", bundle: .module),
            subtitle: String(localized: "Token usage over time", bundle: .module),
            systemImage: "doc.text.fill"
        ) {
            chartContent
        } controls: {
            controlsContent
        }
    }

    private var chartContent: some View {
        VStack(spacing: ChartConstants.Layout.cardSpacing) {
            if contextData.isEmpty {
                emptyStateView
            } else {
                utilizationChart
                ContextUtilizationStats(
                    contextData: contextData,
                    viewModel: viewModel
                )
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            String(localized: "No Context Data", bundle: .module),
            systemImage: "doc.badge.ellipsis",
            description: Text("Context utilization will appear here", bundle: .module)
        )
        .frame(height: Constants.chartHeight)
    }

    private var utilizationChart: some View {
        ContextUtilizationChart(
            contextData: contextData,
            showFillArea: showFillArea,
            showDataPoints: showDataPoints,
            dataHasAppeared: $dataHasAppeared,
            viewModel: viewModel,
            chartHeight: Constants.chartHeight,
            animationDuration: Constants.animationDuration,
            animationDelay: Constants.animationDelay
        )
    }

    private var controlsContent: some View {
        VStack(spacing: ChartConstants.Layout.cardSpacing) {
            ContextUtilizationControls(
                showFillArea: $showFillArea,
                showDataPoints: $showDataPoints,
                contextCapacity: $contextCapacity,
                capacityOptions: Constants.capacityOptions
            )
        }
    }

    private var contextData: [ContextData] {
        viewModel.contextData(
            maxDataPoints: Constants.maxDataPoints,
            capacityOverride: contextCapacity
        )
    }
}

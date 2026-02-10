import Charts
import Database
import Foundation
import SwiftUI

/// Perplexity Heat Map wrapped in a card container
public struct PerplexityHeatMapCard: View {
    let metrics: [Metrics]

    @State private var colorScheme: HeatMapColorScheme = .viridis
    @State private var showLabels: Bool = true
    @State private var selectedCell: HeatMapCell?
    @State private var dataHasAppeared: Bool = false
    @StateObject private var viewModel: PerplexityHeatMapViewModel

    private enum Constants {
        static let chartHeight: CGFloat = 300
        static let animationDuration: Double = 0.8
        static let animationDelay: Double = 0.2
        static let backgroundOpacity: CGFloat = 0.05
        static let mainSpacing: CGFloat = 8
        static let cornerRadius: CGFloat = 8
    }

    public init(metrics: [Metrics]) {
        self.metrics = metrics
        _viewModel = StateObject(wrappedValue: PerplexityHeatMapViewModel(metrics: metrics))
    }

    public var body: some View {
        ChartCard(
            title: String(localized: "Perplexity Heat Map", bundle: .module),
            subtitle: String(localized: "Token-level complexity visualization", bundle: .module),
            systemImage: "square.grid.3x3"
        ) {
            chartContent
        } controls: {
            controlsContent
        }
    }

    private var chartContent: some View {
        VStack(spacing: ChartConstants.Layout.cardSpacing) {
            if heatMapData.isEmpty {
                emptyStateView
            } else {
                heatMapContent
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            String(localized: "No Perplexity Data", bundle: .module),
            systemImage: "square.grid.3x3",
            description: Text("Perplexity heat map will appear here", bundle: .module)
        )
        .frame(height: Constants.chartHeight)
    }

    private var heatMapContent: some View {
        VStack(spacing: Constants.mainSpacing) {
            heatMapGrid
            PerplexityColorScale(
                colorScheme: colorScheme,
                viewModel: viewModel
            )
            PerplexityHeatMapStats(
                heatMapData: heatMapData,
                selectedCell: selectedCell,
                viewModel: viewModel
            )
        }
    }

    private var heatMapGrid: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: false) {
            PerplexityHeatMapGrid(
                heatMapData: heatMapData,
                colorScheme: colorScheme,
                showLabels: showLabels,
                selectedCell: $selectedCell,
                dataHasAppeared: dataHasAppeared,
                viewModel: viewModel
            )
            .padding()
            .background(Color.paletteGray.opacity(Constants.backgroundOpacity))
            .cornerRadius(Constants.cornerRadius)
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
        PerplexityHeatMapControls(
            colorScheme: $colorScheme,
            showLabels: $showLabels
        )
    }

    private var heatMapData: [[HeatMapCell]] {
        viewModel.heatMapData()
    }
}

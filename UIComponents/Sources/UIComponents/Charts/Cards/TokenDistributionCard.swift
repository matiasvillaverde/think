import Charts
import Database
import Foundation
import SwiftUI

private struct TokenDistributionTokenData: Identifiable {
    let id: UUID = .init()
    let category: String
    let count: Int
    let percentage: Double
    let color: Color
}

/// Token Distribution Donut Chart wrapped in a card container
public struct TokenDistributionCard: View {
    let metrics: [Metrics]

    @State private var selectedCategory: String?
    @State private var showDetails: Bool = true
    @State private var dataHasAppeared: Bool = false

    private enum Constants {
        static let chartSize: CGFloat = 200
        static let innerRadiusRatio: Double = 0.6
        static let legendCircleSize: CGFloat = 12
        static let legendItemSpacing: CGFloat = 8
        static let percentageThreshold: Double = 5.0
        static let percentageMultiplier: Double = 100.0
        static let angularInset: Double = 1.0
        static let opacity: Double = 0.9
        static let animationDuration: Double = 0.8
        static let animationDelay: Double = 0.2
        static let dimmedOpacity: Double = 0.3
        static let backgroundOpacity: Double = 0.1
        static let selectedBackgroundOpacity: Double = 0.1
        static let cornerRadius: CGFloat = 4
        static let legendCornerRadius: CGFloat = 8
        static let legendPadding: CGFloat = 8
        static let scaleEffectMin: CGFloat = 0.8
        static let spacingMultiplier: CGFloat = 2
        static let springDamping: Double = 0.7
        static let centerLabelSpacing: CGFloat = 4
        static let centerLabelAnimationDuration: Double = 0.5
        static let centerLabelAnimationDelay: Double = 0.3
        static let legendItemsSpacing: CGFloat = 2
        static let legendStatsSpacing: CGFloat = 4
    }

    public init(metrics: [Metrics]) {
        self.metrics = metrics
    }

    public var body: some View {
        ChartCard(
            title: String(localized: "Token Distribution", bundle: .module),
            subtitle: String(localized: "Prompt vs Generated tokens", bundle: .module),
            systemImage: "chart.pie"
        ) {
            chartContent
        } controls: {
            controlsContent
        }
    }

    private var chartContent: some View {
        VStack(spacing: ChartConstants.Layout.cardSpacing) {
            if tokenData.isEmpty {
                ContentUnavailableView(
                    String(localized: "No Token Data", bundle: .module),
                    systemImage: "chart.pie",
                    description: Text("Token distribution will appear here", bundle: .module)
                )
                .frame(height: Constants.chartSize)
            } else {
                HStack(spacing: ChartConstants.Layout.sectionSpacing) {
                    // Donut chart
                    ZStack {
                        donutChart
                        centerLabel
                    }
                    .frame(width: Constants.chartSize, height: Constants.chartSize)

                    // Legend and stats
                    VStack(alignment: .leading, spacing: ChartConstants.Layout.cardSpacing) {
                        tokenLegend

                        if showDetails {
                            Divider()
                            tokenStats
                        }
                    }

                    Spacer()
                }
            }
        }
    }

    private var donutChart: some View {
        Chart(tokenData) { data in
            SectorMark(
                angle: .value("Count", dataHasAppeared ? data.count : 0),
                innerRadius: .ratio(Constants.innerRadiusRatio),
                angularInset: Constants.angularInset
            )
            .foregroundStyle(data.color)
            .opacity(selectedCategory == nil || selectedCategory == data.category ? Constants
                .opacity : Constants.dimmedOpacity)
            .cornerRadius(Constants.cornerRadius)
        }
        .chartBackground { _ in
            Circle()
                .fill(Color.paletteGray.opacity(Constants.backgroundOpacity))
        }
        .scaleEffect(dataHasAppeared ? 1 : Constants.scaleEffectMin)
        .animation(
            .spring(
                response: Constants.animationDuration,
                dampingFraction: Constants.springDamping
            ),
            value: dataHasAppeared
        )
        .onAppear {
            withAnimation(.easeInOut(duration: Constants.animationDuration)
                .delay(Constants.animationDelay)) {
                dataHasAppeared = true
            }
        }
    }

    private var centerLabel: some View {
        VStack(spacing: Constants.centerLabelSpacing) {
            Text(verbatim: "\(totalTokens)")
                .font(.title2.weight(.bold))
                .foregroundColor(Color.textPrimary)

            Text("Total", bundle: .module)
                .font(.caption)
                .foregroundColor(Color.textSecondary)
        }
        .opacity(dataHasAppeared ? 1 : 0)
        .animation(
            .easeInOut(duration: Constants.centerLabelAnimationDuration)
                .delay(Constants.animationDelay + Constants.centerLabelAnimationDelay),
            value: dataHasAppeared
        )
    }

    private var tokenLegend: some View {
        VStack(
            alignment: .leading,
            spacing: ChartConstants.Layout.itemSpacing * Constants.spacingMultiplier
        ) {
            ForEach(tokenData) { data in
                tokenLegendItem(for: data)
            }
        }
    }

    @ViewBuilder
    private func tokenLegendItem(for data: TokenDistributionTokenData) -> some View {
        Button {
            withAnimation(.spring()) {
                if selectedCategory == data.category {
                    selectedCategory = nil
                } else {
                    selectedCategory = data.category
                }
            }
        } label: {
            HStack(spacing: Constants.legendItemSpacing) {
                Circle()
                    .fill(data.color)
                    .frame(
                        width: Constants.legendCircleSize,
                        height: Constants.legendCircleSize
                    )

                tokenLegendItemText(for: data)
                Spacer()
            }
            .padding(Constants.legendPadding)
            .background(
                RoundedRectangle(cornerRadius: Constants.legendCornerRadius)
                    .fill(selectedCategory == data.category ? data.color
                        .opacity(Constants.selectedBackgroundOpacity) : Color.paletteClear)
            )
        }
        .buttonStyle(.plain)
    }

    private func tokenLegendItemText(for data: TokenDistributionTokenData) -> some View {
        VStack(alignment: .leading, spacing: Constants.legendItemsSpacing) {
            Text(verbatim: data.category)
                .font(.subheadline)
                .foregroundColor(Color.textPrimary)

            HStack(spacing: Constants.legendStatsSpacing) {
                Text(verbatim: "\(data.count)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(Color.textPrimary)

                Text(verbatim: "(\(String(format: "%.1f%%", data.percentage)))")
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
            }
        }
    }

    private var tokenStats: some View {
        VStack(
            alignment: .leading,
            spacing: ChartConstants.Layout.itemSpacing * Constants.spacingMultiplier
        ) {
            // Average tokens per message
            if !metrics.isEmpty {
                let averageTokens: Int = totalTokens / metrics.count
                TokenStatRow(
                    label: String(localized: "Avg per message", bundle: .module),
                    value: String(
                        localized: "\(averageTokens) tokens",
                        bundle: .module
                    )
                )
            }

            // Token efficiency
            if let efficiency = tokenEfficiency {
                TokenStatRow(
                    label: String(localized: "Efficiency", bundle: .module),
                    value: String(format: "%.1f%%", efficiency)
                )
            }

            // Messages analyzed
            StatRow(
                label: String(localized: "Messages", bundle: .module),
                value: "\(metrics.count)"
            )
        }
    }

    private var controlsContent: some View {
        VStack(spacing: ChartConstants.Layout.cardSpacing) {
            Toggle(isOn: $showDetails) {
                Text("Show detailed statistics", bundle: .module)
            }
            .font(.subheadline)
        }
    }

    // MARK: - Data Processing

    private var tokenData: [TokenDistributionTokenData] {
        let totalPrompt: Int = metrics.reduce(0) { $0 + $1.promptTokens }
        let totalGenerated: Int = metrics.reduce(0) { $0 + $1.generatedTokens }
        let grandTotal: Int = totalPrompt + totalGenerated

        guard grandTotal > 0 else {
            return []
        }

        return [
            TokenDistributionTokenData(
                category: "Prompt",
                count: totalPrompt,
                percentage: Double(totalPrompt) / Double(grandTotal) * Constants
                    .percentageMultiplier,
                color: .blue
            ),
            TokenDistributionTokenData(
                category: "Generated",
                count: totalGenerated,
                percentage: Double(totalGenerated) / Double(grandTotal) * Constants
                    .percentageMultiplier,
                color: .green
            )
        ]
    }

    private var totalTokens: Int {
        tokenData.reduce(0) { $0 + $1.count }
    }

    private var tokenEfficiency: Double? {
        let totalPrompt: Int = metrics.reduce(0) { $0 + $1.promptTokens }
        let totalGenerated: Int = metrics.reduce(0) { $0 + $1.generatedTokens }

        guard totalPrompt > 0 else {
            return nil
        }
        return Double(totalGenerated) / Double(totalPrompt) * 100
    }
}

// MARK: - Supporting Views

private struct TokenStatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(Color.textSecondary)

            Spacer()

            Text(value)
                .font(.caption.weight(.bold))
                .foregroundColor(Color.textPrimary)
        }
    }
}

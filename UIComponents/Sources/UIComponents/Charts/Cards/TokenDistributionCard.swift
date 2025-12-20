import Charts
import Database
import SwiftUI

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

    private struct TokenData: Identifiable {
        let id: UUID = .init()
        let category: String
        let count: Int
        let percentage: Double
        let color: Color
    }

    public init(metrics: [Metrics]) {
        self.metrics = metrics
    }

    public var body: some View {
        ChartCard(
            title: "Token Distribution",
            subtitle: "Prompt vs Generated tokens",
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
                    "No Token Data",
                    systemImage: "chart.pie",
                    description: Text("Token distribution will appear here")
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
                .fill(Color.gray.opacity(Constants.backgroundOpacity))
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
            Text("\(totalTokens)")
                .font(.title2.weight(.bold))
                .foregroundColor(.primary)

            Text("Total")
                .font(.caption)
                .foregroundColor(.secondary)
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
    private func tokenLegendItem(for data: TokenData) -> some View {
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
                        .opacity(Constants.selectedBackgroundOpacity) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func tokenLegendItemText(for data: TokenData) -> some View {
        VStack(alignment: .leading, spacing: Constants.legendItemsSpacing) {
            Text(data.category)
                .font(.subheadline)
                .foregroundColor(.primary)

            HStack(spacing: Constants.legendStatsSpacing) {
                Text("\(data.count)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.primary)

                Text("(\(String(format: "%.1f%%", data.percentage)))")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                TokenStatRow(
                    label: "Avg per message",
                    value: "\(totalTokens / metrics.count) tokens"
                )
            }

            // Token efficiency
            if let efficiency = tokenEfficiency {
                TokenStatRow(
                    label: "Efficiency",
                    value: String(format: "%.1f%%", efficiency)
                )
            }

            // Messages analyzed
            StatRow(
                label: "Messages",
                value: "\(metrics.count)"
            )
        }
    }

    private var controlsContent: some View {
        VStack(spacing: ChartConstants.Layout.cardSpacing) {
            Toggle("Show detailed statistics", isOn: $showDetails)
                .font(.subheadline)
        }
    }

    // MARK: - Data Processing

    private var tokenData: [TokenData] {
        let totalPrompt: Int = metrics.reduce(0) { $0 + $1.promptTokens }
        let totalGenerated: Int = metrics.reduce(0) { $0 + $1.generatedTokens }
        let grandTotal: Int = totalPrompt + totalGenerated

        guard grandTotal > 0 else {
            return []
        }

        return [
            TokenData(
                category: "Prompt",
                count: totalPrompt,
                percentage: Double(totalPrompt) / Double(grandTotal) * Constants
                    .percentageMultiplier,
                color: .blue
            ),
            TokenData(
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
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.caption.weight(.bold))
                .foregroundColor(.primary)
        }
    }
}

import Charts
import Database
import SwiftUI

/// Overview statistics section of the dashboard
internal struct DashboardOverviewSection: View {
    @ObservedObject var processor: MetricsProcessor
    let metrics: [Metrics]

    var body: some View {
        VStack(alignment: .leading, spacing: AppWideDashboard.Constants.spacing) {
            Text("Overview Statistics")
                .font(.headline)
                .padding(.bottom, AppWideDashboard.Constants.headerSpacing)

            overviewGrid
        }
    }

    private var overviewGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .flexible(
                        minimum: AppWideDashboard.Constants.minColumnWidth /
                            AppWideDashboard.Constants.halfDivisor,
                        maximum: AppWideDashboard.Constants.maxColumnWidth /
                            AppWideDashboard.Constants.halfDivisor
                    )
                ),
                GridItem(
                    .flexible(
                        minimum: AppWideDashboard.Constants.minColumnWidth /
                            AppWideDashboard.Constants.halfDivisor,
                        maximum: AppWideDashboard.Constants.maxColumnWidth /
                            AppWideDashboard.Constants.halfDivisor
                    )
                )
            ],
            spacing: AppWideDashboard.Constants.spacing
        ) {
            StatCard(
                title: "Avg Tokens/Second",
                value: String(format: "%.1f", processor.cachedStatistics.averageTokensPerSecond),
                icon: "speedometer",
                color: .blue
            )
            StatCard(
                title: "Total Tokens",
                value: formatNumber(processor.cachedStatistics.totalTokens),
                icon: "number",
                color: .green
            )
            StatCard(
                title: "Avg Response Time",
                value: String(format: "%.2fs", processor.cachedStatistics.averageResponseTime),
                icon: "timer",
                color: .orange
            )
            StatCard(
                title: "Active Models",
                value: "\(processor.cachedStatistics.uniqueModelsCount)",
                icon: "cpu",
                color: .purple
            )
        }
    }

    private func formatNumber(_ number: Int) -> String {
        if number >= Int(AppWideDashboard.Constants.megabyte) {
            return String(
                format: "%.1fM",
                Double(number) / AppWideDashboard.Constants.megabyte
            )
        }
        if number >= Int(AppWideDashboard.Constants.kilobyte) {
            return String(
                format: "%.1fK",
                Double(number) / AppWideDashboard.Constants.kilobyte
            )
        }
        return "\(number)"
    }
}

/// Individual statistics card
private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: AppWideDashboard.Constants.iconWidth)
                .accessibilityLabel("\(title) icon")

            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            Spacer()
        }
        .padding(AppWideDashboard.Constants.cardPadding)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: AppWideDashboard.Constants.cornerRadius))
        .shadow(radius: AppWideDashboard.Constants.shadowRadius)
    }
}

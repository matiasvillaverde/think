import Charts
import Database
import Foundation
import SwiftUI

/// Overview statistics section of the dashboard
internal struct DashboardOverviewSection: View {
    @ObservedObject var processor: MetricsProcessor
    let metrics: [Metrics]

    var body: some View {
        VStack(alignment: .leading, spacing: AppWideDashboard.Constants.spacing) {
            Text("Overview Statistics", bundle: .module)
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
                title: String(localized: "Avg Tokens/Second", bundle: .module),
                value: String(format: "%.1f", processor.cachedStatistics.averageTokensPerSecond),
                icon: "speedometer",
                color: .blue
            )
            StatCard(
                title: String(localized: "Total Tokens", bundle: .module),
                value: formatNumber(processor.cachedStatistics.totalTokens),
                icon: "number",
                color: .green
            )
            StatCard(
                title: String(localized: "Avg Response Time", bundle: .module),
                value: String(format: "%.2fs", processor.cachedStatistics.averageResponseTime),
                icon: "timer",
                color: .orange
            )
            StatCard(
                title: String(localized: "Active Models", bundle: .module),
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
                .accessibilityLabel(Text("\(title) icon", bundle: .module))

            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
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

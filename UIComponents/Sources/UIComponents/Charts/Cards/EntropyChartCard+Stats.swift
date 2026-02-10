import Charts
import Database
import SwiftUI

/// Stats extension for EntropyChartCard
extension EntropyChartCard {
    var statsView: some View {
        HStack(spacing: ChartConstants.Layout.sectionSpacing) {
            averageStatView
            trendStatView
            minStatView
            maxStatView
            Spacer()
        }
    }

    private var averageStatView: some View {
        VStack(alignment: .leading, spacing: Constants.statSpacing) {
            Text("Average", bundle: .module)
                .font(.caption)
                .foregroundColor(Color.textSecondary)
            Text(String(format: "%.2f", averageEntropy))
                .font(.subheadline.weight(.bold))
                .foregroundColor(.blue)
        }
    }

    private var trendStatView: some View {
        VStack(alignment: .leading, spacing: Constants.statSpacing) {
            Text("Trend", bundle: .module)
                .font(.caption)
                .foregroundColor(Color.textSecondary)
            Text(entropyTrend.displayName)
                .font(.subheadline.weight(.bold))
                .foregroundColor(trendColor)
        }
    }

    @ViewBuilder private var minStatView: some View {
        if let min = entropyData.map(\.entropy).min() {
            VStack(alignment: .leading, spacing: Constants.statSpacing) {
                Text("Min", bundle: .module)
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
                Text(String(format: "%.2f", min))
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.green)
            }
        }
    }

    @ViewBuilder private var maxStatView: some View {
        if let max = entropyData.map(\.entropy).max() {
            VStack(alignment: .leading, spacing: Constants.statSpacing) {
                Text("Max", bundle: .module)
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
                Text(String(format: "%.2f", max))
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.red)
            }
        }
    }
}

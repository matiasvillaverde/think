import SwiftUI

internal struct MemoryUsageStats: View {
    let memoryData: [MemoryData]
    let viewModel: MemoryUsageViewModel

    private enum Constants {
        static let statsSpacing: CGFloat = 2
    }

    var body: some View {
        HStack(spacing: ChartConstants.Layout.sectionSpacing) {
            averageMemoryView
            peakMemoryView
            efficiencyView
            Spacer()
        }
    }

    private var averageMemoryView: some View {
        VStack(alignment: .leading, spacing: Constants.statsSpacing) {
            Text("Average", bundle: .module)
                .font(.caption)
                .foregroundColor(Color.textSecondary)

            let avgMemory: Double = viewModel.averageMemory(for: memoryData)
            Text(viewModel.formatMemory(avgMemory))
                .font(.subheadline.weight(.bold))
                .foregroundColor(viewModel.memoryColor(for: avgMemory))
        }
    }

    private var peakMemoryView: some View {
        VStack(alignment: .leading, spacing: Constants.statsSpacing) {
            Text("Peak", bundle: .module)
                .font(.caption)
                .foregroundColor(Color.textSecondary)

            let peak: Double = viewModel.peakMemory(for: memoryData)
            Text(viewModel.formatMemory(peak))
                .font(.subheadline.weight(.bold))
                .foregroundColor(viewModel.memoryColor(for: peak))
        }
    }

    private var efficiencyView: some View {
        VStack(alignment: .leading, spacing: Constants.statsSpacing) {
            Text("Efficiency", bundle: .module)
                .font(.caption)
                .foregroundColor(Color.textSecondary)

            Text(String(format: "%.0f%%", viewModel.memoryEfficiency(for: memoryData)))
                .font(.subheadline.weight(.bold))
                .foregroundColor(Color.textPrimary)
        }
    }
}

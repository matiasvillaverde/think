import SwiftUI

internal struct ProcessingTimeStats: View {
    let processingData: [ProcessingData]
    let viewModel: ProcessingTimeViewModel
    let verticalSpacing: CGFloat

    var body: some View {
        HStack(spacing: ChartConstants.Layout.sectionSpacing) {
            totalTimeView
            averageTimeView
            slowestTimeView
            Spacer()
        }
    }

    private var totalTimeView: some View {
        VStack(alignment: .leading, spacing: verticalSpacing) {
            Text("Total")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(viewModel.formatTime(
                viewModel.totalProcessingTime(for: processingData)
            ))
            .font(.subheadline.weight(.bold))
            .foregroundColor(.blue)
        }
    }

    private var averageTimeView: some View {
        VStack(alignment: .leading, spacing: verticalSpacing) {
            Text("Average")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(viewModel.formatTime(
                viewModel.averageProcessingTime(for: processingData)
            ))
            .font(.subheadline.weight(.bold))
            .foregroundColor(.green)
        }
    }

    @ViewBuilder private var slowestTimeView: some View {
        if let slowest = processingData.max(by: { $0.total < $1.total }) {
            VStack(alignment: .leading, spacing: verticalSpacing) {
                Text("Slowest")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(viewModel.formatTime(slowest.total))
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.orange)
            }
        }
    }
}

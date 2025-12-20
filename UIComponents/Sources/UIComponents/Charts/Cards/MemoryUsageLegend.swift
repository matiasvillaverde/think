import SwiftUI

internal struct MemoryUsageLegend: View {
    private enum Constants {
        static let legendCircleSize: CGFloat = 10
        static let legendSpacing: CGFloat = 8
        static let peakOpacity: Double = 0.7
    }

    var body: some View {
        HStack(spacing: ChartConstants.Layout.sectionSpacing) {
            legendItem(color: .blue, label: "Active Memory")
            legendItem(color: .red.opacity(Constants.peakOpacity), label: "Peak Memory")
            Spacer()
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: Constants.legendSpacing) {
            Circle()
                .fill(color)
                .frame(width: Constants.legendCircleSize, height: Constants.legendCircleSize)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

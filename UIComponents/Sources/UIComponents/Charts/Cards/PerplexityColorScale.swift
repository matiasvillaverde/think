import SwiftUI

internal struct PerplexityColorScale: View {
    let colorScheme: HeatMapColorScheme
    let viewModel: PerplexityHeatMapViewModel

    private enum Constants {
        static let colorScalePrecision: Int = 50
        static let colorScaleHeight: CGFloat = 20
        static let cornerRadius: CGFloat = 4
    }

    var body: some View {
        VStack(spacing: ChartConstants.Layout.itemSpacing) {
            colorScaleLabels
            colorScaleGradient
        }
    }

    private var colorScaleLabels: some View {
        HStack {
            Text("0.0")
                .font(.caption)
                .foregroundColor(Color.textSecondary)

            Spacer()

            Text("Perplexity")
                .font(.caption)
                .foregroundColor(Color.textSecondary)

            Spacer()

            Text("1.0")
                .font(.caption)
                .foregroundColor(Color.textSecondary)
        }
    }

    private var colorScaleGradient: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(0..<Constants.colorScalePrecision, id: \.self) { index in
                    colorRectangle(at: index, width: geometry.size.width)
                }
            }
            .cornerRadius(Constants.cornerRadius)
        }
        .frame(height: Constants.colorScaleHeight)
    }

    private func colorRectangle(at index: Int, width: CGFloat) -> some View {
        Rectangle()
            .fill(
                viewModel.colorForValue(
                    Double(index) / Double(Constants.colorScalePrecision - 1),
                    scheme: colorScheme
                )
            )
            .frame(
                width: width / CGFloat(Constants.colorScalePrecision),
                height: Constants.colorScaleHeight
            )
    }
}

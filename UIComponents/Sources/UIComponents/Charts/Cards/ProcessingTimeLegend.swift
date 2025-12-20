import SwiftUI

internal struct ProcessingTimeLegend: View {
    let processingData: [ProcessingData]
    let legendRectSize: CGFloat
    let legendItemSpacing: CGFloat

    private enum Constants {
        static let legendCornerRadius: CGFloat = 2
    }

    var body: some View {
        HStack(spacing: ChartConstants.Layout.sectionSpacing) {
            // Legend items
            ForEach([
                ("Inference", Color.blue),
                ("Tokenization", Color.green),
                ("Post-processing", Color.orange)
            ], id: \.0) { label, color in
                HStack(spacing: legendItemSpacing) {
                    RoundedRectangle(cornerRadius: Constants.legendCornerRadius)
                        .fill(color)
                        .frame(width: legendRectSize, height: legendRectSize)

                    Text(label)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }

            Spacer()

            // Data point count
            Text("\(processingData.count) metrics")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

import Foundation
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
                (String(localized: "Inference", bundle: .module), Color.paletteBlue),
                (String(localized: "Tokenization", bundle: .module), Color.paletteGreen),
                (String(localized: "Post-processing", bundle: .module), Color.paletteOrange)
            ], id: \.0) { label, color in
                HStack(spacing: legendItemSpacing) {
                    RoundedRectangle(cornerRadius: Constants.legendCornerRadius)
                        .fill(color)
                        .frame(width: legendRectSize, height: legendRectSize)

                    Text(label)
                        .font(.caption)
                        .foregroundColor(Color.textPrimary)
                }
            }

            Spacer()

            // Data point count
            Text("\(processingData.count) metrics", bundle: .module)
                .font(.caption)
                .foregroundColor(Color.textSecondary)
        }
    }
}

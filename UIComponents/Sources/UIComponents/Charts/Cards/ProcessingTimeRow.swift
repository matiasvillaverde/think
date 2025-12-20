import SwiftUI

internal struct ProcessingTimeRow: View {
    let data: ProcessingData
    let index: Int
    let showPercentages: Bool
    let dataHasAppeared: Bool
    let maxTotalTime: Double

    private enum Constants {
        static let barHeight: CGFloat = 28
        static let barCornerRadius: CGFloat = 6
        static let labelPadding: CGFloat = 4
        static let percentageThreshold: Double = 10.0
        static let maxBarWidth: CGFloat = 300
        static let animationDuration: Double = 0.6
        static let animationDelay: Double = 0.1
        static let springResponse: Double = 0.5
        static let dampingFraction: Double = 0.7
        static let grayOpacity: Double = 0.1
        static let shadowRadius: CGFloat = 1
        static let minimumFrameWidth: CGFloat = 30
        static let labelWidth: CGFloat = 80
        static let totalTimeWidth: CGFloat = 60
        static let strokeOpacity: Double = 0.2
        static let strokeWidth: CGFloat = 0.5
        static let smallTimeThreshold: Double = 1.0
        static let mediumTimeThreshold: Double = 1_000
    }

    var body: some View {
        HStack(alignment: .center, spacing: ChartConstants.Layout.itemSpacing) {
            // Label
            Text(data.label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: Constants.labelWidth, alignment: .leading)

            // Stacked bar
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(data.components) { component in
                        componentBar(for: component, geometry: geometry)
                    }
                }
                .frame(height: Constants.barHeight)
                .background(
                    RoundedRectangle(cornerRadius: Constants.barCornerRadius)
                        .fill(Color.gray.opacity(Constants.grayOpacity))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Constants.barCornerRadius)
                        .stroke(
                            Color.gray.opacity(Constants.strokeOpacity),
                            lineWidth: Constants.strokeWidth
                        )
                )
            }
            .frame(height: Constants.barHeight)
            .frame(maxWidth: Constants.maxBarWidth)

            // Total time
            Text(formatTime(data.total))
                .font(.caption.monospacedDigit())
                .foregroundColor(.primary)
                .frame(width: Constants.totalTimeWidth, alignment: .trailing)
        }
        .opacity(dataHasAppeared ? 1 : 0)
        .animation(
            .spring(
                response: Constants.springResponse,
                dampingFraction: Constants.dampingFraction
            )
            .delay(Double(index) * Constants.animationDelay),
            value: dataHasAppeared
        )
    }

    @ViewBuilder
    private func componentBar(
        for component: ProcessingComponent,
        geometry: GeometryProxy
    ) -> some View {
        let width: CGFloat = calculateWidth(for: component, geometry: geometry)

        if width > Constants.minimumFrameWidth {
            ZStack {
                Rectangle()
                    .fill(component.color)
                    .frame(width: dataHasAppeared ? width : 0)

                if showPercentages,
                    data.percentage(for: component) > Constants.percentageThreshold {
                    Text(String(format: "%.0f%%", data.percentage(for: component)))
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, Constants.labelPadding)
                }
            }
            .animation(
                .spring(
                    response: Constants.springResponse,
                    dampingFraction: Constants.dampingFraction
                )
                .delay(Double(index) * Constants.animationDelay),
                value: dataHasAppeared
            )
        }
    }

    private func calculateWidth(
        for component: ProcessingComponent,
        geometry: GeometryProxy
    ) -> CGFloat {
        let ratio: Double = data.total / maxTotalTime
        let availableWidth: CGFloat = geometry.size.width * ratio
        let componentRatio: Double = component.value / data.total
        return availableWidth * componentRatio
    }

    private func formatTime(_ milliseconds: Double) -> String {
        if milliseconds < Constants.smallTimeThreshold {
            String(format: "%.2f ms", milliseconds)
        } else if milliseconds < Constants.mediumTimeThreshold {
            String(format: "%.0f ms", milliseconds)
        } else {
            String(
                format: "%.1f s",
                milliseconds / Constants.mediumTimeThreshold
            )
        }
    }
}

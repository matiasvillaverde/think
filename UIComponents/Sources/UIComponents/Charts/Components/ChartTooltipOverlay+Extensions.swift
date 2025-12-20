import Charts
import Database
import SwiftUI

/// View extensions for ChartDataPointOverlay
extension ChartTooltipOverlay {
    var tooltipContent: some View {
        VStack(alignment: .leading, spacing: ChartDataPointOverlay.Constants.tooltipSpacing) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(.primary)

            ForEach(values, id: \.label) { tooltipValue in
                tooltipValueRow(tooltipValue)
            }
        }
        .padding(ChartDataPointOverlay.Constants.tooltipLargePadding)
        .background(tooltipBackground)
        .position(position)
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(), value: isVisible)
    }

    private func tooltipValueRow(_ tooltipValue: TooltipValue) -> some View {
        HStack(spacing: ChartDataPointOverlay.Constants.annotationSpacing) {
            Circle()
                .fill(tooltipValue.color)
                .frame(
                    width: ChartDataPointOverlay.Constants.circleSize,
                    height: ChartDataPointOverlay.Constants.circleSize
                )

            Text("\(tooltipValue.label):")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(tooltipValue.value)
                .font(.caption2.bold())
                .foregroundColor(.primary)
        }
    }

    private var tooltipBackground: some View {
        RoundedRectangle(
            cornerRadius: ChartDataPointOverlay.Constants.tooltipLargeCornerRadius
        )
        .fill(Color.backgroundPrimary)
        .shadow(radius: ChartDataPointOverlay.Constants.tooltipLargeShadowRadius)
    }
}

extension ChartRulerOverlay {
    var rulerContent: some View {
        ZStack {
            verticalRulerLine
            horizontalRulerLine
            crosshairCenter
            xAxisLabel
            yAxisLabel
        }
    }

    private var verticalRulerLine: some View {
        Path { path in
            guard let position else {
                return
            }
            path.move(to: CGPoint(x: position.x, y: chartBounds.minY))
            path.addLine(to: CGPoint(x: position.x, y: chartBounds.maxY))
        }
        .stroke(
            Color.blue.opacity(ChartDataPointOverlay.Constants.rulerOpacity),
            lineWidth: ChartDataPointOverlay.Constants.rulerLineWidth
        )
    }

    private var horizontalRulerLine: some View {
        Path { path in
            guard let position else {
                return
            }
            path.move(to: CGPoint(x: chartBounds.minX, y: position.y))
            path.addLine(to: CGPoint(x: chartBounds.maxX, y: position.y))
        }
        .stroke(
            Color.blue.opacity(ChartDataPointOverlay.Constants.rulerOpacity),
            lineWidth: ChartDataPointOverlay.Constants.rulerLineWidth
        )
    }

    private var crosshairCenter: some View {
        Circle()
            .fill(Color.blue)
            .frame(
                width: ChartDataPointOverlay.Constants.crosshairSize,
                height: ChartDataPointOverlay.Constants.crosshairSize
            )
            .position(position ?? .zero)
    }

    private var xAxisLabel: some View {
        Text(xValue)
            .font(.caption2)
            .padding(ChartDataPointOverlay.Constants.axisLabelPadding)
            .background(
                Capsule()
                    .fill(Color.blue)
            )
            .foregroundColor(.white)
            .position(
                x: position?.x ?? 0,
                y: chartBounds.maxY + ChartDataPointOverlay.Constants.axisLabelOffset
            )
    }

    private var yAxisLabel: some View {
        Text(yValue)
            .font(.caption2)
            .padding(ChartDataPointOverlay.Constants.axisLabelPadding)
            .background(
                Capsule()
                    .fill(Color.blue)
            )
            .foregroundColor(.white)
            .position(
                x: chartBounds.minX + ChartDataPointOverlay.Constants.axisLabelSideOffset,
                y: position?.y ?? 0
            )
    }
}

import Charts
import Database
import SwiftUI

/// Interactive overlay for chart data points
public struct ChartDataPointOverlay: View {
    enum Constants {
        static let selectionOpacity: Double = 0.2
        static let selectionSize: CGFloat = 40
        static let animationDuration: Double = 0.3
        static let selectedPointSize: CGFloat = 12
        static let defaultPointSize: CGFloat = 8
        static let strokeWidth: CGFloat = 2
        static let shadowRadius: CGFloat = 2
        static let tooltipPadding: CGFloat = 8
        static let tooltipCornerRadius: CGFloat = 8
        static let tooltipShadowRadius: CGFloat = 4
        static let tooltipOffset: CGFloat = -50
        static let circleSize: CGFloat = 6
        static let tooltipSpacing: CGFloat = 6
        static let tooltipLargePadding: CGFloat = 10
        static let tooltipLargeCornerRadius: CGFloat = 10
        static let tooltipLargeShadowRadius: CGFloat = 6
        static let rulerOpacity: Double = 0.5
        static let rulerLineWidth: CGFloat = 1
        static let crosshairSize: CGFloat = 8
        static let axisLabelOffset: CGFloat = 20
        static let axisLabelSideOffset: CGFloat = -30
        static let axisLabelPadding: CGFloat = 4
        static let selectionOpacityRect: Double = 0.2
        static let selectionStrokeWidth: CGFloat = 2
        static let annotationSpacing: CGFloat = 4
        static let annotationPadding: CGFloat = 4
        static let annotationStrokeWidth: CGFloat = 1
        static let halfDivisor: Double = 2
    }

    let dataPoint: DataPoint
    let isSelected: Bool
    let onTap: () -> Void

    public struct DataPoint {
        public let xCoordinate: Double
        public let yCoordinate: Double
        public let label: String
        public let value: String
        public let color: Color

        public init(
            xCoordinate: Double,
            yCoordinate: Double,
            label: String,
            value: String,
            color: Color
        ) {
            self.xCoordinate = xCoordinate
            self.yCoordinate = yCoordinate
            self.label = label
            self.value = value
            self.color = color
        }
    }

    public init(
        dataPoint: DataPoint,
        isSelected: Bool,
        onTap: @escaping () -> Void
    ) {
        self.dataPoint = dataPoint
        self.isSelected = isSelected
        self.onTap = onTap
    }

    public var body: some View {
        ZStack {
            // Selection indicator
            if isSelected {
                Circle()
                    .fill(dataPoint.color.opacity(Constants.selectionOpacity))
                    .frame(width: Constants.selectionSize, height: Constants.selectionSize)
                    .animation(.easeInOut(duration: Constants.animationDuration), value: isSelected)
            }

            // Data point
            Circle()
                .fill(dataPoint.color)
                .frame(
                    width: isSelected ? Constants.selectedPointSize : Constants.defaultPointSize,
                    height: isSelected ? Constants.selectedPointSize : Constants.defaultPointSize
                )
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: Constants.strokeWidth)
                )
                .shadow(radius: Constants.shadowRadius)

            // Tooltip
            if isSelected {
                tooltipView
            }
        }
        .onTapGesture {
            withAnimation(.spring()) {
                onTap()
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(dataPoint.label): \(dataPoint.value)")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double tap to select")
    }

    private var tooltipView: some View {
        VStack(alignment: .leading, spacing: Constants.annotationSpacing) {
            Text(dataPoint.label)
                .font(.caption2.bold())
                .foregroundColor(.primary)

            Text(dataPoint.value)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(Constants.tooltipPadding)
        .background(
            RoundedRectangle(cornerRadius: Constants.tooltipCornerRadius)
                .fill(Color.backgroundPrimary)
                .shadow(radius: Constants.tooltipShadowRadius)
        )
        .offset(y: Constants.tooltipOffset)
        .transition(.scale.combined(with: .opacity))
    }
}

/// Chart tooltip overlay
public struct ChartTooltipOverlay: View {
    let position: CGPoint
    let title: String
    let values: [TooltipValue]

    public struct TooltipValue {
        public let label: String
        public let value: String
        public let color: Color

        public init(label: String, value: String, color: Color) {
            self.label = label
            self.value = value
            self.color = color
        }
    }

    let isVisible: Bool

    public init(
        position: CGPoint,
        title: String,
        values: [TooltipValue],
        isVisible: Bool
    ) {
        self.position = position
        self.title = title
        self.values = values
        self.isVisible = isVisible
    }

    public var body: some View {
        if isVisible {
            tooltipContent
        }
    }
}

/// Interactive chart ruler
public struct ChartRulerOverlay: View {
    @Binding var position: CGPoint?
    let chartBounds: CGRect
    let xValue: String
    let yValue: String

    public init(
        position: Binding<CGPoint?>,
        chartBounds: CGRect,
        xValue: String,
        yValue: String
    ) {
        _position = position
        self.chartBounds = chartBounds
        self.xValue = xValue
        self.yValue = yValue
    }

    public var body: some View {
        if position != nil {
            rulerContent
        }
    }
}

/// Selection range overlay
public struct ChartSelectionOverlay: View {
    @Binding var selectionRange: ClosedRange<Double>?
    let chartBounds: CGRect
    let color: Color

    public init(
        selectionRange: Binding<ClosedRange<Double>?>,
        chartBounds: CGRect,
        color: Color = .blue
    ) {
        _selectionRange = selectionRange
        self.chartBounds = chartBounds
        self.color = color
    }

    public var body: some View {
        if let range = selectionRange {
            Rectangle()
                .fill(color.opacity(ChartDataPointOverlay.Constants.selectionOpacityRect))
                .overlay(
                    Rectangle()
                        .stroke(
                            color,
                            lineWidth: ChartDataPointOverlay.Constants.selectionStrokeWidth
                        )
                )
                .frame(
                    width: CGFloat(range.upperBound - range.lowerBound),
                    height: chartBounds.height
                )
                .position(
                    x: CGFloat(
                        range.lowerBound +
                            (range.upperBound - range.lowerBound) / ChartDataPointOverlay.Constants
                            .halfDivisor
                    ),
                    y: chartBounds.midY
                )
                .allowsHitTesting(false)
        }
    }
}

/// Annotation overlay for important points
public struct ChartAnnotationOverlay: View {
    let annotations: [Annotation]

    public struct Annotation: Identifiable {
        public let id: UUID = .init()
        public let position: CGPoint
        public let text: String
        public let icon: String?
        public let color: Color

        public init(
            position: CGPoint,
            text: String,
            icon: String? = nil,
            color: Color = .blue
        ) {
            self.position = position
            self.text = text
            self.icon = icon
            self.color = color
        }
    }

    public init(annotations: [Annotation]) {
        self.annotations = annotations
    }

    public var body: some View {
        ForEach(annotations) { annotation in
            VStack(spacing: ChartDataPointOverlay.Constants.annotationSpacing) {
                if let icon = annotation.icon {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundColor(annotation.color)
                        .accessibilityLabel("Annotation icon")
                }

                Text(annotation.text)
                    .font(.caption2)
                    .foregroundColor(.primary)
                    .padding(ChartDataPointOverlay.Constants.annotationPadding)
                    .background(
                        Capsule()
                            .fill(Color.backgroundPrimary)
                            .overlay(
                                Capsule()
                                    .stroke(
                                        annotation.color,
                                        lineWidth: ChartDataPointOverlay.Constants
                                            .annotationStrokeWidth
                                    )
                            )
                    )
            }
            .position(annotation.position)
        }
    }
}

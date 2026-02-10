import Charts
import Database
import SwiftUI

/// Accessibility support for chart components
public enum ChartAccessibility {
    /// Create an accessibility label for a performance metric
    public static func performanceLabel(
        metric: String,
        value: Double,
        unit: String,
        date: Date
    ) -> String {
        let formatter: DateFormatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short

        let formattedValue: String = String(format: "%.2f", value)
        let formattedDate: String = formatter.string(from: date)
        return "\(metric): \(formattedValue) \(unit) at \(formattedDate)"
    }

    /// Create an accessibility label for chart statistics
    public static func statsLabel(
        title: String,
        value: String,
        trend: String? = nil
    ) -> String {
        if let trend {
            return "\(title): \(value), trend: \(trend)"
        }
        return "\(title): \(value)"
    }

    /// Create a summary description for a chart
    public static func chartSummary(
        title: String,
        dataPointCount: Int,
        timeRange: String? = nil
    ) -> String {
        var summary: String = "\(title) chart with \(dataPointCount) data points"
        if let timeRange {
            summary += " for \(timeRange)"
        }
        return summary
    }

    /// Create accessibility hints for interactive elements
    public static func interactionHint(for action: ChartAction) -> String {
        switch action {
        case .adjustTimeRange:
            String(localized: "Swipe to adjust time range", bundle: .module)

        case .collapse:
            String(localized: "Double tap to collapse chart", bundle: .module)

        case .expand:
            String(localized: "Double tap to expand chart", bundle: .module)

        case .selectMetric:
            String(localized: "Double tap to change metric", bundle: .module)

        case .toggleOption:
            String(localized: "Double tap to toggle option", bundle: .module)
        }
    }

    /// Represents different types of chart interactions for accessibility
    public enum ChartAction {
        /// Action to adjust the time range of the chart
        case adjustTimeRange
        /// Action to collapse a chart to compact size
        case collapse
        /// Action to expand a chart to full size
        case expand
        /// Action to select or change chart metric
        case selectMetric
        /// Action to toggle chart display options
        case toggleOption
    }
}

/// Accessibility modifier for chart components
public struct ChartAccessibilityModifier: ViewModifier {
    let label: String
    let hint: String?
    let value: String?
    let traits: AccessibilityTraits

    public init(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = []
    ) {
        self.label = label
        self.hint = hint
        self.value = value
        self.traits = traits
    }

    public func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(traits)
    }
}

/// Extension to add accessibility to charts
extension View {
    /// Applies accessibility modifiers specific to chart components
    /// - Parameters:
    ///   - label: Accessibility label for the chart
    ///   - hint: Optional hint for user interaction
    ///   - value: Optional value description
    ///   - traits: Accessibility traits to apply
    /// - Returns: View with chart accessibility modifiers
    func chartAccessibility(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        modifier(
            ChartAccessibilityModifier(
                label: label,
                hint: hint,
                value: value,
                traits: traits
            )
        )
    }
}

/// Accessibility-enhanced chart legend
public struct AccessibleChartLegend: View {
    let items: [LegendItem]

    private enum Constants {
        static let legendSpacing: CGFloat = 8
        static let legendItemSpacing: CGFloat = 8
        static let circleSize: CGFloat = 10
    }

    public struct LegendItem: Identifiable {
        public let id: UUID = .init()
        public let color: Color
        public let label: String
        public let value: String?

        public init(color: Color, label: String, value: String? = nil) {
            self.color = color
            self.label = label
            self.value = value
        }
    }

    public init(items: [LegendItem]) {
        self.items = items
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Constants.legendSpacing) {
            ForEach(items) { item in
                HStack(spacing: Constants.legendItemSpacing) {
                    Circle()
                        .fill(item.color)
                        .frame(width: Constants.circleSize, height: Constants.circleSize)
                        .accessibilityHidden(true)

                    Text(item.label)
                        .font(.caption)

                    if let value = item.value {
                        Text(verbatim: "(\(value))")
                            .font(.caption)
                            .foregroundColor(Color.textSecondary)
                    }

                    Spacer()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    item.value.map { "\(item.label): \($0)" } ?? item.label
                )
            }
        }
    }
}

/// Voice-over optimized chart description
public struct ChartVoiceOverDescription: View {
    let title: String
    let summary: String
    let details: [String]

    public init(
        title: String,
        summary: String,
        details: [String]
    ) {
        self.title = title
        self.summary = summary
        self.details = details
    }

    public var body: some View {
        Text(verbatim: "")
            .frame(width: 0, height: 0)
            .accessibilityElement()
            .accessibilityLabel(title)
            .accessibilityValue(summary + ". " + details.joined(separator: ". "))
            .accessibilityHint(Text("Chart data summary", bundle: .module))
    }
}

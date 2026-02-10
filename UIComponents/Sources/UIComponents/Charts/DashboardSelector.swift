import Database
import SwiftData
import SwiftUI

// MARK: - Dashboard Type

/// Represents different types of dashboard views available
public enum DashboardType: String, CaseIterable, Identifiable {
    case appWide = "app_wide"
    case chatMetrics = "chat_metrics"
    case modelMetrics = "model_metrics"
    case singleMetric = "single_metric"

    public var id: String { rawValue }

    var title: String {
        switch self {
        case .appWide:
            return String(localized: "All Metrics", bundle: .module)

        case .chatMetrics:
            return String(localized: "Chat Metrics", bundle: .module)

        case .modelMetrics:
            return String(localized: "Model Analytics", bundle: .module)

        case .singleMetric:
            return String(localized: "Single Metric", bundle: .module)
        }
    }

    var accessibilityLabel: String {
        String(localized: "Dashboard type: \(title)", bundle: .module)
    }

    var icon: String {
        switch self {
        case .appWide:
            "chart.bar.doc.horizontal"

        case .chatMetrics:
            "bubble.left.and.bubble.right"

        case .modelMetrics:
            "cpu"

        case .singleMetric:
            "chart.line.uptrend.xyaxis.circle"
        }
    }

    var description: String {
        switch self {
        case .appWide:
            return String(
                localized: "Global metrics across all interactions",
                bundle: .module
            )

        case .chatMetrics:
            return String(
                localized: "Analyze metrics across a conversation",
                bundle: .module
            )

        case .modelMetrics:
            return String(
                localized: "Compare performance across model usage",
                bundle: .module
            )

        case .singleMetric:
            return String(
                localized: "View metrics for a single message",
                bundle: .module
            )
        }
    }
}

// MARK: - Dashboard Selector

/// A selector component for switching between different dashboard types
public struct DashboardSelector: View {
    @Binding var selectedType: DashboardType
    @State private var isExpanded: Bool = false
    let context: DashboardContext
    let availableTypes: [DashboardType]

    // MARK: - Constants

    private enum Constants {
        static let cornerRadius: CGFloat = 12
        static let padding: CGFloat = 16
        static let spacing: CGFloat = 12
        static let iconSize: CGFloat = 20
        static let animationDuration: Double = 0.3
        static let shadowRadius: CGFloat = 5
        static let shadowOpacity: Double = 0.1
        static let dividerSpacing: CGFloat = 6
        static let captionSpacing: CGFloat = 2
        static let badgePaddingHorizontal: CGFloat = 6
        static let badgePaddingVertical: CGFloat = 2
        static let badgeCornerRadius: CGFloat = 4
        static let badgeOpacity: Double = 0.1
        static let disabledOpacity: Double = 0.5
        static let borderOpacity: Double = 0.2
        static let borderWidth: CGFloat = 1
        static let shadowY: CGFloat = 2
    }

    public init(
        selectedType: Binding<DashboardType>,
        context: DashboardContext,
        availableTypes: [DashboardType] = DashboardType.allCases
    ) {
        _selectedType = selectedType
        self.context = context
        self.availableTypes = availableTypes
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Current Selection
            currentSelectionButton

            // Expanded Options
            if isExpanded {
                Divider()
                    .padding(.vertical, Constants.dividerSpacing)

                expandedOptions
            }
        }
        .background(backgroundView)
        .overlay(borderOverlay)
        .animation(.spring(duration: Constants.animationDuration), value: isExpanded)
    }

    // MARK: - Current Selection

    private var currentSelectionButton: some View {
        Button {
            withAnimation {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                Image(systemName: selectedType.icon)
                    .font(.system(size: Constants.iconSize))
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: Constants.iconSize, height: Constants.iconSize)
                    .accessibilityLabel(
                        Text("Dashboard type: \(selectedType.title)", bundle: .module)
                    )

                VStack(alignment: .leading, spacing: Constants.captionSpacing) {
                    Text(selectedType.title)
                        .font(.headline)
                        .foregroundColor(Color.textPrimary)

                    Text(selectedType.description)
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                }

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
                    .rotationEffect(.degrees(isExpanded ? 0 : 0))
                    .accessibilityLabel(
                        isExpanded
                            ? Text("Collapse", bundle: .module)
                            : Text("Expand", bundle: .module)
                    )
            }
            .padding(Constants.padding)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Expanded Options

    private var expandedOptions: some View {
        VStack(spacing: 0) {
            ForEach(availableTypes.filter { $0 != selectedType }) { type in
                optionButton(for: type)

                if type != availableTypes.last(where: { $0 != selectedType }) {
                    Divider()
                        .padding(.horizontal, Constants.padding)
                }
            }
        }
    }

    private func optionButton(for type: DashboardType) -> some View {
        Button {
            withAnimation {
                selectedType = type
                isExpanded = false
            }
        } label: {
            HStack {
                Image(systemName: type.icon)
                    .font(.system(size: Constants.iconSize))
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: Constants.iconSize, height: Constants.iconSize)
                    .accessibilityLabel(
                        Text("Dashboard type: \(type.title)", bundle: .module)
                    )

                VStack(alignment: .leading, spacing: Constants.captionSpacing) {
                    Text(type.title)
                        .font(.subheadline)
                        .foregroundColor(Color.textPrimary)

                    Text(type.description)
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                }

                Spacer()

                if !isAvailable(type) {
                    Text("Not Available", bundle: .module)
                        .font(.caption2)
                        .foregroundColor(Color.textSecondary)
                        .padding(.horizontal, Constants.badgePaddingHorizontal)
                        .padding(.vertical, Constants.badgePaddingVertical)
                        .background(Color.textSecondary.opacity(Constants.badgeOpacity))
                        .cornerRadius(Constants.badgeCornerRadius)
                }
            }
            .padding(Constants.padding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable(type))
        .opacity(isAvailable(type) ? Constants.borderWidth : Constants.disabledOpacity)
    }

    // MARK: - Helpers

    private func isAvailable(_ type: DashboardType) -> Bool {
        switch type {
        case .appWide:
            true // Always available

        case .chatMetrics:
            !context.metrics.isEmpty || context.chatId != nil

        case .modelMetrics:
            context.modelName != nil || !context.metrics.isEmpty

        case .singleMetric:
            context.metric != nil
        }
    }

    // MARK: - Background & Border

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: Constants.cornerRadius)
            .fill(Color.backgroundSecondary)
            .shadow(
                color: Color.paletteBlack.opacity(Constants.shadowOpacity),
                radius: Constants.shadowRadius,
                x: 0,
                y: Constants.shadowY
            )
    }

    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: Constants.cornerRadius)
            .stroke(
                Color.paletteGray.opacity(Constants.borderOpacity),
                lineWidth: Constants.borderWidth
            )
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("Dashboard Selector") {
        VStack {
            DashboardSelector(
                selectedType: .constant(.appWide),
                context: DashboardContext(
                    metric: Metrics.preview(),
                    chatId: "123",
                    chatTitle: "Test Chat",
                    modelName: "GPT-4",
                    metrics: [Metrics.preview()]
                )
            )
            .padding()

            Spacer()
        }
    }
#endif

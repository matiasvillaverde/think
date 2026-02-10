import Database
import SwiftData
import SwiftUI

// MARK: - Dashboard Container

/// Container view that hosts the dashboard selector and content
public struct DashboardContainer: View {
    @State private var selectedType: DashboardType
    @Query private var allMetrics: [Metrics]

    let context: DashboardContext

    // MARK: - Constants

    private enum Constants {
        static let spacing: CGFloat = 20
        static let animationDuration: Double = 0.3
        static let emptyStateIconSize: CGFloat = 48
        static let emptyStateSpacing: CGFloat = 16
    }

    public init(context: DashboardContext, initialType: DashboardType = .appWide) {
        self.context = context
        _selectedType = State(initialValue: initialType)
    }

    public var body: some View {
        AdaptiveScrollContainer {
            VStack(spacing: Constants.spacing) {
                // Dashboard Selector
                DashboardSelector(
                    selectedType: $selectedType,
                    context: context
                )
                .padding(.horizontal)

                // Dashboard Content
                dashboardContent
                    .animation(.spring(duration: Constants.animationDuration), value: selectedType)
            }
        }
    }

    @ViewBuilder private var dashboardContent: some View {
        switch selectedType {
        case .appWide:
            AppWideDashboard()

        case .chatMetrics:
            if !context.metrics.isEmpty {
                ChatMetricsDashboard(
                    metrics: context.metrics,
                    chatId: context.chatId,
                    chatTitle: context.chatTitle
                )
            } else {
                emptyStateView("No chat metrics available")
            }

        case .modelMetrics:
            if let modelName = context.modelName {
                ModelDashboard(
                    metrics: context.metrics.isEmpty ?
                        allMetrics.filter { $0.modelName == modelName } :
                        context.metrics,
                    modelName: modelName
                )
            } else {
                emptyStateView(
                    String(localized: "No model selected", bundle: .module)
                )
            }

        case .singleMetric:
            if let metric = context.metric {
                SingleMetricDashboard(
                    metric: metric,
                    modelInfo: context.modelName,
                    systemPrompt: nil
                )
            } else {
                emptyStateView(
                    String(localized: "No single metric available", bundle: .module)
                )
            }
        }
    }

    private func emptyStateView(_ message: String) -> some View {
        VStack(spacing: Constants.emptyStateSpacing) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: Constants.emptyStateIconSize))
                .foregroundColor(Color.textSecondary)
                .accessibilityLabel(Text("Empty chart", bundle: .module))

            Text(message)
                .font(.headline)
                .foregroundColor(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("Dashboard Container") {
        DashboardContainer(
            context: DashboardContext(
                metric: Metrics.preview(),
                chatId: "123",
                chatTitle: "Test Chat",
                modelName: "GPT-4",
                metrics: [Metrics.preview()]
            )
        )
    }
#endif

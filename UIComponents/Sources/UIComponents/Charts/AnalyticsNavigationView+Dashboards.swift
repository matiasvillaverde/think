import Database
import SwiftUI

// MARK: - Dashboard Views Extension

extension AnalyticsNavigationView {
    @ViewBuilder var chatMetricsDashboard: some View {
        ChatMetricsDashboard(
            metrics: currentContext.metrics,
            chatId: currentContext.chatId,
            chatTitle: currentContext.chatTitle
        )
    }

    @ViewBuilder var modelMetricsDashboard: some View {
        if let modelName = selectedModelNameValue ?? currentContext.modelName {
            ModelDashboard(
                metrics: allMetrics.filter { $0.modelName == modelName },
                modelName: modelName
            )
        } else {
            EmptyStateView(
                message: String(
                    localized: "Select a model to view analytics",
                    bundle: .module
                )
            )
        }
    }

    @ViewBuilder var singleMetricDashboard: some View {
        if let metric = currentContext.metric {
            SingleMetricDashboard(
                metric: metric,
                modelInfo: currentContext.modelName,
                systemPrompt: nil
            )
        } else {
            EmptyStateView(
                message: String(
                    localized: "No single metric available",
                    bundle: .module
                )
            )
        }
    }

    func dashboardView(for type: DashboardType) -> some View {
        Group {
            switch type {
            case .appWide:
                AppWideDashboard()

            case .chatMetrics:
                chatMetricsDashboard

            case .modelMetrics:
                modelMetricsDashboard

            case .singleMetric:
                singleMetricDashboard
            }
        }
    }

    func chatRowView(for chat: Chat) -> some View {
        HStack {
            Image(systemName: "bubble.left.and.bubble.right")
                .foregroundColor(Color.textSecondary)
                .accessibilityLabel(Text("Chat icon", bundle: .module))
            VStack(alignment: .leading) {
                Text(chat.name)
                    .lineLimit(1)
                if !chat.messages.isEmpty {
                    let messageCount: Int = chat.messages.count
                    Text("\(messageCount) messages", bundle: .module)
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                }
            }
        }
    }
}

// MARK: - Empty State View

private struct EmptyStateView: View {
    let message: String

    var body: some View {
        VStack(spacing: AnalyticsNavigationView.Constants.emptyStateSpacing) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: AnalyticsNavigationView.Constants.emptyStateIconSize))
                .foregroundColor(Color.textSecondary)
                .accessibilityLabel(Text("Empty chart icon", bundle: .module))
            Text(message)
                .font(.headline)
                .foregroundColor(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

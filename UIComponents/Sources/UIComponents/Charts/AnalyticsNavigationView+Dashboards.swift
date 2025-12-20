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
            EmptyStateView(message: "Select a model to view analytics")
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
            EmptyStateView(message: "No single metric available")
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
                .foregroundColor(.secondary)
                .accessibilityLabel("Chat icon")
            VStack(alignment: .leading) {
                Text(chat.name)
                    .lineLimit(1)
                if !chat.messages.isEmpty {
                    let messageCount: Int = chat.messages.count
                    Text("\(messageCount) messages")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                .foregroundColor(.secondary)
                .accessibilityLabel("Empty chart icon")
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

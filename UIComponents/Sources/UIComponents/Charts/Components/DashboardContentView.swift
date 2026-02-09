import Charts
import Database
import SwiftUI

/// Main content view for the dashboard
internal struct DashboardContentView: View {
    @ObservedObject var processor: MetricsProcessor
    let allMetrics: [Metrics]
    let selectedTimeRange: AppWideDashboard.TimeRange

    var body: some View {
        Group {
            switch processor.loadingState {
            case .idle:
                idleView

            case let .loading(progress):
                DashboardLoadingView(
                    message: "Processing \(allMetrics.count) metrics...",
                    progress: progress
                )

            case let .loaded(metrics):
                loadedView(metrics: metrics)

            case let .error(error):
                errorView(error: error)
            }
        }
    }

    @ViewBuilder private var idleView: some View {
        ChartSkeletonView()
            .task {
                await processor.loadMetrics(
                    allMetrics: allMetrics,
                    timeRange: selectedTimeRange
                )
            }
    }

    @ViewBuilder
    private func loadedView(metrics: [Metrics]) -> some View {
        if !metrics.isEmpty {
            VStack(spacing: AppWideDashboard.Constants.spacing) {
                DashboardOverviewSection(
                    processor: processor,
                    metrics: metrics
                )
                DashboardChartsSection(metrics: metrics)
            }
        } else {
            DashboardEmptyStateView(constants: .init(
                spacing: AppWideDashboard.Constants.spacing,
                iconWidth: AppWideDashboard.Constants.iconWidth
            ))
        }
    }

    @ViewBuilder
    private func errorView(error: Error) -> some View {
        ErrorView(error: error) {
            Task {
                await processor.loadMetrics(
                    allMetrics: allMetrics,
                    timeRange: selectedTimeRange
                )
            }
        }
    }
}

/// Empty state view when no metrics are available
private struct DashboardEmptyStateView: View {
    let constants: EmptyStateConstants

    struct EmptyStateConstants {
        let spacing: CGFloat
        let iconWidth: CGFloat
    }

    var body: some View {
        VStack(spacing: constants.spacing) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: constants.iconWidth))
                .foregroundColor(Color.textSecondary)
                .accessibilityLabel("Empty chart icon")

            Text("No Metrics Available")
                .font(.headline)
                .foregroundColor(Color.textSecondary)

            Text("Start using the app to generate metrics")
                .font(.caption)
                .foregroundColor(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(constants.iconWidth)
    }
}

import Charts
import Database
import SwiftData
import SwiftUI

internal struct AppWideDashboard: View {
    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass: UserInterfaceSizeClass?
    @Environment(\.verticalSizeClass)
    private var verticalSizeClass: UserInterfaceSizeClass?

    enum Constants {
        static let spacing: CGFloat = 16
        static let minColumnWidth: CGFloat = 300
        static let maxColumnWidth: CGFloat = 500
        static let cornerRadius: CGFloat = 12
        static let shadowRadius: CGFloat = 2
        static let headerIconSize: CGFloat = 30
        static let dividerPadding: CGFloat = 8
        static let headerSpacing: CGFloat = 8
        static let cardPadding: CGFloat = 12
        static let iconWidth: CGFloat = 40
        static let percentMultiplier: Double = 100
        static let halfDivisor: CGFloat = 2
        static let minHeight: CGFloat = 300
        static let minWidth: CGFloat = 900
        static let chartHeight: CGFloat = 300
        static let recentDays: Int = 7
        static let recentHours: Double = -168
        static let lastDayHours: Double = -24
        static let lastMonthDays: Double = -30
        static let hoursPerDay: Double = 24
        static let secondsPerHour: Double = 3_600
        static let topModelsLimit: Int = 5
        static let kilobyte: Double = 1_000
        static let megabyte: Double = 1_000_000
        // Adaptive column counts
        static let iPhoneColumns: Int = 1
        static let iPadPortraitColumns: Int = 2
        static let iPadLandscapeColumns: Int = 3
        static let macOSColumns: Int = 2
        static let visionOSColumns: Int = 3
        static let iPhonePadding: CGFloat = 16
        static let defaultPadding: CGFloat = 20
        static let selectedOpacity: Double = 0.2
        static let unselectedOpacity: Double = 0.1
    }

    // MARK: - Queries

    @Query(sort: \Metrics.createdAt, order: .reverse)
    var allMetrics: [Metrics]

    @Query(sort: \Message.createdAt, order: .reverse)
    var messages: [Message]

    @Query(sort: \Model.name)
    var models: [Model]

    @State private var selectedTimeRange: TimeRange = .week
    @StateObject private var processor: MetricsProcessor = .init()

    public enum TimeRange: String, CaseIterable {
        case day = "24 Hours"
        case week = "7 Days"
        case month = "30 Days"
        case all = "All Time"

        var icon: String {
            switch self {
            case .day:
                "clock"

            case .week:
                "calendar"

            case .month:
                "calendar.badge.clock"

            case .all:
                "infinity"
            }
        }
    }

    internal init() {
        // Initialize dashboard
    }

    internal var body: some View {
        AdaptiveScrollContainer {
            VStack(spacing: Constants.spacing) {
                DashboardHeaderView(
                    allMetricsCount: allMetrics.count,
                    messagesWithMetricsCount: messages.count { $0.metrics != nil },
                    activeModelsCount: processor.cachedStatistics.uniqueModelsCount,
                    constants: .init(
                        headerIconSize: Constants.headerIconSize,
                        headerSpacing: Constants.headerSpacing
                    )
                )

                TimeRangeSelectorView(
                    selectedTimeRange: $selectedTimeRange,
                    constants: .init(
                        spacing: Constants.spacing,
                        cardPadding: Constants.cardPadding,
                        dividerPadding: Constants.dividerPadding,
                        cornerRadius: Constants.cornerRadius,
                        selectedOpacity: Constants.selectedOpacity,
                        unselectedOpacity: Constants.unselectedOpacity
                    )
                )

                Divider()
                    .padding(.vertical, Constants.dividerPadding)

                DashboardContentView(
                    processor: processor,
                    allMetrics: allMetrics,
                    selectedTimeRange: selectedTimeRange
                )
            }
            .padding(adaptivePadding)
        }
        .task(id: selectedTimeRange) {
            await processor.loadMetrics(
                allMetrics: allMetrics,
                timeRange: selectedTimeRange
            )
        }
    }

    private var adaptivePadding: CGFloat {
        #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                return Constants.iPhonePadding
            }
        #endif
        return Constants.defaultPadding
    }
}

#if DEBUG
    #Preview("App Dashboard") {
        AppWideDashboard()
            .frame(minWidth: AppWideDashboard.Constants.minWidth)
            .modelContainer(for: [Metrics.self, Message.self, Model.self])
    }
#endif

import Database
import SwiftData
import SwiftUI

// MARK: - Analytics Navigation View

/// Main navigation view for analytics dashboards with platform-specific UI
public struct AnalyticsNavigationView: View {
    @Environment(\.dismiss)
    private var dismiss: DismissAction

    @Query(sort: \Metrics.createdAt, order: .reverse)
    var allMetrics: [Metrics]

    @Query(sort: \Chat.createdAt, order: .reverse)
    private var allChats: [Chat]

    @State private var selectedDashboard: DashboardType = .appWide
    @State private var selectedChat: Chat?
    @State private var selectedModelName: String?

    let initialContext: DashboardContext?
    let initialType: DashboardType

    // MARK: - Constants

    enum Constants {
        static let sidebarWidth: CGFloat = 280
        static let minWindowWidth: CGFloat = 800
        static let minWindowHeight: CGFloat = 600
        static let toolbarSpacing: CGFloat = 20
        static let iPadSidebarFraction: CGFloat = 0.35
        static let visionOSDepth: CGFloat = 50
        static let sidebarMaxWidthMultiplier: CGFloat = 1.5
        static let pickerWidth: CGFloat = 400
        static let ornamentSpacing: CGFloat = 20
        static let maxChatsInSidebar: Int = 10
        static let animationDuration: Double = 0.3
        static let statCardSpacing: CGFloat = 4
        static let statCardMinWidth: CGFloat = 80
        static let statCardCornerRadius: CGFloat = 12
        static let emptyStateIconSize: CGFloat = 48
        static let emptyStateSpacing: CGFloat = 16
    }

    public init(
        initialContext: DashboardContext? = nil,
        initialType: DashboardType = .appWide
    ) {
        self.initialContext = initialContext
        self.initialType = initialType
    }

    // MARK: - Computed Properties for Extensions

    var selectedModelNameValue: String? { selectedModelName }
    var selectedChatValue: Chat? { selectedChat }

    public var body: some View {
        #if os(macOS)
            macOSLayout
        #elseif os(iOS)
            iOSLayout
        #elseif os(visionOS)
            visionOSLayout
        #endif
    }

    // MARK: - macOS Layout

    #if os(macOS)
        private var macOSLayout: some View {
            NavigationSplitView {
                sidebarContent
                    .navigationSplitViewColumnWidth(
                        min: Constants.sidebarWidth,
                        ideal: Constants.sidebarWidth,
                        max: Constants.sidebarWidth * Constants.sidebarMaxWidthMultiplier
                    )
            } detail: {
                dashboardDetailView
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Picker("Dashboard Type", selection: $selectedDashboard) {
                                ForEach(DashboardType.allCases) { type in
                                    Label(type.rawValue, systemImage: type.icon)
                                        .tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: Constants.pickerWidth)
                        }
                    }
            }
            .frame(minWidth: Constants.minWindowWidth, minHeight: Constants.minWindowHeight)
        }
    #endif

    // MARK: - iOS Layout

    #if os(iOS)
        private var iOSLayout: some View {
            Group {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    // iPad: Split view
                    NavigationSplitView {
                        sidebarContent
                            .navigationTitle("Analytics")
                    } detail: {
                        dashboardDetailView
                    }
                } else {
                    // iPhone: Tab-based navigation
                    TabView(selection: $selectedDashboard) {
                        ForEach(DashboardType.allCases) { type in
                            dashboardView(for: type)
                                .tabItem {
                                    Label(type.rawValue, systemImage: type.icon)
                                }
                                .tag(type)
                        }
                    }
                }
            }
        }
    #endif

    // MARK: - visionOS Layout

    #if os(visionOS)
        private var visionOSLayout: some View {
            NavigationStack {
                ZStack {
                    // Background depth layer
                    dashboardDetailView
                        .offset(z: -Constants.visionOSDepth)

                    // Floating control ornament
                    VStack {
                        Spacer()
                        HStack {
                            DashboardSelector(
                                selectedType: $selectedDashboard,
                                context: currentContext
                            )
                            .frame(maxWidth: Constants.pickerWidth)
                            .glassBackgroundEffect()
                        }
                        .padding()
                    }
                }
                .navigationTitle("Analytics Dashboard")
                .ornament(attachmentAnchor: .scene(.bottom)) {
                    quickStatsOrnament
                }
            }
        }

        private var quickStatsOrnament: some View {
            HStack(spacing: Constants.ornamentSpacing) {
                StatCard(
                    title: "Total Metrics",
                    value: "\(allMetrics.count)",
                    icon: "chart.bar"
                )
                StatCard(
                    title: "Active Chats",
                    value: "\(allChats.count)",
                    icon: "bubble.left.and.bubble.right"
                )
                if let avgTokens = averageTokens {
                    StatCard(
                        title: "Avg Tokens",
                        value: "\(Int(avgTokens))",
                        icon: "number"
                    )
                }
            }
            .padding()
            .glassBackgroundEffect()
        }
    #endif

    // MARK: - Shared Components

    private var sidebarContent: some View {
        List(selection: $selectedChat) {
            Section("Quick Access") {
                NavigationLink(value: DashboardType.appWide) {
                    Label("All Metrics", systemImage: "chart.bar.doc.horizontal")
                }
            }

            if !allChats.isEmpty {
                Section("Recent Chats") {
                    ForEach(allChats.prefix(Constants.maxChatsInSidebar)) { chat in
                        NavigationLink(value: chat) {
                            chatRowView(for: chat)
                        }
                    }
                }
            }

            Section("Models") {
                ForEach(uniqueModelNames, id: \.self) { modelName in
                    NavigationLink(value: modelName) {
                        Label(modelName, systemImage: "cpu")
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private var dashboardDetailView: some View {
        DashboardContainer(
            context: currentContext,
            initialType: selectedDashboard
        )
        .id(selectedDashboard)
        .animation(.spring(response: Constants.animationDuration), value: selectedDashboard)
    }

    // MARK: - Helper Properties

    var currentContext: DashboardContext {
        if let initial = initialContext {
            return initial
        }

        return DashboardContext(
            metric: allMetrics.first,
            chatId: selectedChat?.id.uuidString,
            chatTitle: selectedChat?.name,
            modelName: selectedModelName,
            metrics: selectedChat?.messages.compactMap(\.metrics) ?? []
        )
    }

    private var uniqueModelNames: [String] {
        let names: Set<String> = Set(allMetrics.compactMap(\.modelName))
        return Array(names).sorted()
    }

    private var averageTokens: Double? {
        guard !allMetrics.isEmpty else {
            return nil
        }
        let totalTokens: Int = allMetrics.reduce(0) { $0 + $1.totalTokens }
        return Double(totalTokens) / Double(allMetrics.count)
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: AnalyticsNavigationView.Constants.statCardSpacing) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.secondary)
                .accessibilityLabel("\(title) icon")
            Text(value)
                .font(.title3.bold())
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(minWidth: AnalyticsNavigationView.Constants.statCardMinWidth)
        .background(.regularMaterial)
        .cornerRadius(AnalyticsNavigationView.Constants.statCardCornerRadius)
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("Analytics Navigation") {
        AnalyticsNavigationView()
    }
#endif

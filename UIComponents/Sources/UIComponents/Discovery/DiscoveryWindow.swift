import Abstractions
import Database
import OSLog
import SwiftUI

/// A window view for displaying the discovery carousel on macOS
public struct DiscoveryWindow: View {
    // MARK: - Properties

    @Binding var selectedChat: Chat?
    @State private var selectedSection: Section? = .discovery

    // MARK: - Types

    enum Section: String, CaseIterable {
        case discovery = "Discover"
        case myModels = "My Models"
        case analytics = "Analytics"
    }

    // MARK: - Constants

    private enum Layout {
        static let minWidth: CGFloat = 800
        static let minHeight: CGFloat = 600
        static let sidebarMinWidth: CGFloat = 200
        static let sidebarIdealWidth: CGFloat = 250
    }

    public init(selectedChat: Binding<Chat?>) {
        _selectedChat = selectedChat
    }

    public var body: some View {
        NavigationSplitView {
            // Sidebar
            List(Section.allCases, id: \.self, selection: $selectedSection) { section in
                Label(
                    section.rawValue,
                    systemImage: sectionIcon(for: section)
                )
            }
            .navigationSplitViewColumnWidth(
                min: Layout.sidebarMinWidth,
                ideal: Layout.sidebarIdealWidth
            )
        } detail: {
            detailView
        }
        .frame(minWidth: Layout.minWidth, minHeight: Layout.minHeight)
        .background(Color.backgroundPrimary)
    }

    // MARK: - Helper Methods

    @ViewBuilder private var detailView: some View {
        switch selectedSection {
        case .discovery:
            NavigationStack {
                DiscoveryCarouselView()
                    .navigationDestination(for: DiscoveredModel.self) { model in
                        DiscoveryModelDetailView(model: model)
                    }
            }

        case .myModels:
            if let chat = selectedChat {
                MyModelsView(chat: chat)
            } else {
                ContentUnavailableView(
                    "No Chat Selected",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Select a chat in the main window to manage its models")
                )
            }

        case .analytics:
            AnalyticsNavigationView(
                initialContext: selectedChat.map { chat in
                    DashboardContext(
                        chatId: chat.id.uuidString,
                        chatTitle: chat.name
                    )
                },
                initialType: .appWide
            )

        case .none:
            EmptyView()
        }
    }

    private func sectionIcon(for section: Section) -> String {
        switch section {
        case .discovery:
            return "sparkles"

        case .myModels:
            return "tray.full"

        case .analytics:
            return "chart.line.uptrend.xyaxis"
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        @Previewable @State var selectedChat: Chat?
        DiscoveryWindow(selectedChat: $selectedChat)
    }
#endif

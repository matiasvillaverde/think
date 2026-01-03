import Abstractions
import Database
import SwiftData
import SwiftUI

/// Container view that manages and displays multiple channel messages
internal struct ChannelContainerView: View {
    // MARK: - Constants

    private enum Constants {
        static let containerSpacing: CGFloat = 8
        static let sectionSpacing: CGFloat = 8
        static let toolSpacing: CGFloat = 6
        static let animationDuration: Double = 0.2
        static let finalChannelOrder: Int = 2
        static let uuidPrefixLength: Int = 8
    }

    // MARK: - Properties

    let toolExecutions: [ToolExecution]

    // Properties for context menu support
    @Bindable var message: Message
    @Binding var showingSelectionView: Bool
    @Binding var showingThinkingView: Bool
    @Binding var showingStatsView: Bool
    let copyTextAction: ((String) -> Void)?
    let shareTextAction: ((String) -> Void)?

    // MARK: - Query

    @Query private var channels: [Channel]

    // MARK: - Initialization

    internal init(
        message: Message,
        toolExecutions: [ToolExecution] = [],
        showingSelectionView: Binding<Bool> = .constant(false),
        showingThinkingView: Binding<Bool> = .constant(false),
        showingStatsView: Binding<Bool> = .constant(false),
        copyTextAction: ((String) -> Void)? = nil,
        shareTextAction: ((String) -> Void)? = nil
    ) {
        self.toolExecutions = toolExecutions
        self.message = message
        self._showingSelectionView = showingSelectionView
        self._showingThinkingView = showingThinkingView
        self._showingStatsView = showingStatsView
        self.copyTextAction = copyTextAction
        self.shareTextAction = shareTextAction

        // Initialize @Query with predicate, sorting, and limit
        let messageId: UUID = message.id
        let descriptor: FetchDescriptor<Channel> = FetchDescriptor<Channel>(
            predicate: #Predicate<Channel> { channel in
                channel.message?.id == messageId
            },
            sortBy: [SortDescriptor(\.order)]
        )

        self._channels = Query(
            descriptor,
            animation: .easeInOut(duration: Constants.animationDuration)
        )
    }

    // MARK: - Body

    internal var body: some View {
        VStack(alignment: .leading, spacing: Constants.containerSpacing) {
            // Channels are already sorted by the query
            ForEach(channels, id: \.id) { channel in
                VStack(alignment: .leading, spacing: Constants.toolSpacing) {
                    ChannelMessageView(
                        channel: channel,
                        message: message,
                        associatedToolStatus: getToolStatus(for: channel),
                        showingSelectionView: $showingSelectionView,
                        showingThinkingView: $showingThinkingView,
                        showingStatsView: $showingStatsView,
                        copyTextAction: copyTextAction,
                        shareTextAction: shareTextAction
                    )
                    .equatable()
                    .id(channel.id) // Stable identity allows SwiftUI to diff

                    // Render associated tool right after its commentary channel
                    if let toolExecution = channel.toolExecution {
                        ToolExecutionView(toolExecution: toolExecution)
                    }
                }
            }

            // Render any remaining tools that aren't associated with channels
            let unassociatedTools: [ToolExecution] = toolExecutions.filter { execution in
                !channels.contains { $0.toolExecution?.id == execution.id }
            }

            if !unassociatedTools.isEmpty {
                VStack(alignment: .leading, spacing: Constants.toolSpacing) {
                    ForEach(unassociatedTools, id: \.id) { toolExecution in
                        ToolExecutionView(toolExecution: toolExecution)
                    }
                }
            }
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets())
    }

    private func getToolStatus(for channel: Channel) -> ToolExecutionState? {
        channel.toolExecution?.state
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("Channels Container") {
        @Previewable @State var message: Message = Message.previewComplexConversation
        @Previewable @State var showingSelection: Bool = false
        @Previewable @State var showingThinking: Bool = false
        @Previewable @State var showingStats: Bool = false

        ChannelContainerView(
            message: message,
            toolExecutions: [],
            showingSelectionView: $showingSelection,
            showingThinkingView: $showingThinking,
            showingStatsView: $showingStats,
            copyTextAction: { _ in },
            shareTextAction: { _ in }
        )
        .padding()
    }
#endif

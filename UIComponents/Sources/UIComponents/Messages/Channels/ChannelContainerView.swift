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
        static let queryAnimationDuration: Double = 0
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
            // Streaming channel updates can be very frequent; avoid implicit animations here.
            animation: .linear(duration: Constants.queryAnimationDuration)
        )
    }

    // MARK: - Body

    internal var body: some View {
        VStack(alignment: .leading, spacing: Constants.containerSpacing) {
            // Channels are already sorted by the query
            ForEach(channels, id: \.id) { channel in
                channelRow(channel)
            }

            // Render any remaining tools that aren't associated with channels
            let unassociatedTools: [ToolExecution] = toolExecutions.filter { execution in
                !channels.contains { $0.toolExecution?.id == execution.id }
            }

            if !unassociatedTools.isEmpty {
                VStack(alignment: .leading, spacing: Constants.toolSpacing) {
                    ForEach(unassociatedTools, id: \.id) { toolExecution in
                        ToolExecutionView(toolExecution: toolExecution)
                            .id(toolExecution.id)
                    }
                }
            }
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets())
    }

    @ViewBuilder
    private func channelRow(_ channel: Channel) -> some View {
        VStack(alignment: .leading, spacing: Constants.toolSpacing) {
            if channel.type == .tool {
                // Tool channels are rendered via ToolExecutionView to avoid duplicate tool blocks.
                if let toolExecution = channel.toolExecution {
                    // ToolExecutionView keeps local disclosure state.
                    // Provide a stable identity so it doesn't reset during frequent SwiftData
                    // re-fetches or streaming updates.
                    ToolExecutionView(toolExecution: toolExecution)
                        .id(toolExecution.id)
                } else {
                    channelMessageView(channel)
                }
            } else {
                channelMessageView(channel)

                // Render associated tool right after its commentary channel
                if let toolExecution = channel.toolExecution {
                    ToolExecutionView(toolExecution: toolExecution)
                        .id(toolExecution.id)
                }
            }
        }
    }

    @ViewBuilder
    private func channelMessageView(_ channel: Channel) -> some View {
        if channel.type == .analysis {
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
            .id(channel.id) // Stable identity allows SwiftUI to diff
        } else {
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
        }
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
            copyTextAction: { _ in
                // no-op
            },
            shareTextAction: { _ in
                // no-op
            }
        )
        .padding()
    }
#endif

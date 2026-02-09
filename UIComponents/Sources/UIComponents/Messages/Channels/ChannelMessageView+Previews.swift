import Database
import SwiftUI

// MARK: - Preview

#if DEBUG
    #Preview("Final Response") {
        @Previewable @State var channel: Channel = Channel(
            type: .final,
            content: """
                Here's the solution to your problem:

                ```swift
                func calculate() -> Int {
                    return 42
                }
                ```
                """,
            order: 0,
            isComplete: true
        )
        @Previewable @State var message: Message = Message.previewWithResponse
        @Previewable @State var showingSelection: Bool = false
        @Previewable @State var showingThinking: Bool = false
        @Previewable @State var showingStats: Bool = false

        ChannelMessageView(
            channel: channel,
            message: message,
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

    #Preview("Analysis Thinking") {
        @Previewable @State var channel: Channel = Channel(
            type: .analysis,
            content: """
                Analyzing the request... This involves multiple steps to solve the problem.
                """,
            order: 0,
            isComplete: false
        )
        @Previewable @State var message: Message = Message.previewWithThinking

        ChannelMessageView(
            channel: channel,
            message: message
        )
        .padding()
    }

    #Preview("Commentary with Tool") {
        @Previewable @State var channel: Channel = Channel(
            type: .commentary,
            content: "Running calculation to determine the result...",
            order: 0,
            isComplete: false
        )
        @Previewable @State var message: Message = Message.previewWithResponse

        ChannelMessageView(
            channel: channel,
            message: message,
            associatedToolStatus: .executing
        )
        .padding()
    }
#endif

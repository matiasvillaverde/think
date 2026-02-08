import Abstractions
@testable import AgentOrchestrator
@testable import Database
import Foundation

// MARK: - Test Data Creation Helpers

internal enum MessagePersistorTestHelpers {
    private enum ChannelIds {
        static let analysis: UUID = UUID(
            uuidString: "00000000-0000-0000-0000-00000000A001"
        ) ?? UUID()
        static let commentary: UUID = UUID(
            uuidString: "00000000-0000-0000-0000-00000000C001"
        ) ?? UUID()
        static let final: UUID = UUID(
            uuidString: "00000000-0000-0000-0000-00000000F001"
        ) ?? UUID()
    }

    internal static func createFullProcessedOutput() -> ProcessedOutput {
        ProcessedOutput(channels: createFullChannels())
    }

    internal static func createFullChannels() -> [ChannelMessage] {
        let orderFirst: Int = 0
        let orderSecond: Int = 1
        let orderThird: Int = 2
        return [
            createAnalysisChannel(content: "Analysis content", order: orderFirst),
            createCommentaryChannel(
                content: "Commentary content",
                order: orderSecond,
                recipient: "user"
            ),
            createFinalChannel(content: "Final content", order: orderThird)
        ]
    }

    private static func createAnalysisChannel(content: String, order: Int) -> ChannelMessage {
        ChannelMessage(
            id: ChannelIds.analysis,
            type: .analysis,
            content: content,
            order: order,
            recipient: nil
        )
    }

    private static func createCommentaryChannel(
        content: String,
        order: Int,
        recipient: String
    ) -> ChannelMessage {
        ChannelMessage(
            id: ChannelIds.commentary,
            type: .commentary,
            content: content,
            order: order,
            recipient: recipient
        )
    }

    private static func createFinalChannel(content: String, order: Int) -> ChannelMessage {
        ChannelMessage(
            id: ChannelIds.final,
            type: .final,
            content: content,
            order: order,
            recipient: nil
        )
    }

    internal static func createInitialOutput() -> ProcessedOutput {
        ProcessedOutput(
            channels: [
                ChannelMessage(
                    id: ChannelIds.final,
                    type: .final,
                    content: "Initial content",
                    order: 0,
                    recipient: nil
                )
            ]
        )
    }

    internal static func createUpdatedOutput() -> ProcessedOutput {
        ProcessedOutput(
            channels: [
                ChannelMessage(
                    id: ChannelIds.final,
                    type: .final,
                    content: "Updated content",
                    order: 0,
                    recipient: nil
                )
            ]
        )
    }

    internal static func createStreamingUpdates() -> [ProcessedOutput] {
        [
            createFirstUpdate(),
            createSecondUpdate(),
            createThirdUpdate(),
            createFinalUpdate()
        ]
    }

    internal static func createFirstUpdate() -> ProcessedOutput {
        ProcessedOutput(
            channels: [
                ChannelMessage(
                    id: ChannelIds.analysis,
                    type: .analysis,
                    content: "Analyzing",
                    order: 0,
                    recipient: nil
                )
            ]
        )
    }

    internal static func createSecondUpdate() -> ProcessedOutput {
        let orderFirst: Int = 0
        let orderSecond: Int = 1
        return ProcessedOutput(
            channels: [
                ChannelMessage(
                    id: ChannelIds.analysis,
                    type: .analysis,
                    content: "Analyzing...",
                    order: orderFirst,
                    recipient: nil
                ),
                ChannelMessage(
                    id: ChannelIds.commentary,
                    type: .commentary,
                    content: "Processing",
                    order: orderSecond,
                    recipient: "user"
                )
            ]
        )
    }

    internal static func createThirdUpdate() -> ProcessedOutput {
        let orderFirst: Int = 0
        let orderSecond: Int = 1
        let orderThird: Int = 2
        return ProcessedOutput(
            channels: [
                createAnalysisChannel(content: "Analyzing... done", order: orderFirst),
                createCommentaryChannel(
                    content: "Processing request",
                    order: orderSecond,
                    recipient: "user"
                ),
                createFinalChannel(content: "Here is", order: orderThird)
            ]
        )
    }

    internal static func createFinalUpdate() -> ProcessedOutput {
        let orderFirst: Int = 0
        let orderSecond: Int = 1
        let orderThird: Int = 2
        return ProcessedOutput(
            channels: [
                createAnalysisChannel(content: "Analyzing... done", order: orderFirst),
                createCommentaryChannel(
                    content: "Processing completed",
                    order: orderSecond,
                    recipient: "user"
                ),
                createFinalChannel(content: "Here is the answer", order: orderThird)
            ]
        )
    }

    internal static func createIncompleteChannelOutput() -> ProcessedOutput {
        ProcessedOutput(
            channels: [
                ChannelMessage(
                    id: ChannelIds.final,
                    type: .final,
                    content: "Streaming...",
                    order: 0,
                    isComplete: false,
                    recipient: nil
                )
            ]
        )
    }

    internal static func createCompleteChannelOutput() -> ProcessedOutput {
        ProcessedOutput(
            channels: [
                ChannelMessage(
                    id: ChannelIds.final,
                    type: .final,
                    content: "Streaming... done!",
                    order: 0,
                    isComplete: true,
                    recipient: nil
                )
            ]
        )
    }
}

import Abstractions
@testable import AgentOrchestrator
@testable import Database
import Foundation
import Testing

extension MessagePersistorTests {
    private enum Constants {
        static let analysisIndex: Int = 0
        static let commentaryIndex: Int = 1
        static let finalIndex: Int = 2

        static let analysisOrder: Int = 0
        static let commentaryOrder: Int = 1
        static let finalOrder: Int = 2

        static let channelCount: Int = 3
    }

    private enum StreamingChannelIds {
        static let analysis: UUID = UUID(
            uuidString: "00000000-0000-0000-0000-00000000A101"
        ) ?? UUID()
        static let commentary: UUID = UUID(
            uuidString: "00000000-0000-0000-0000-00000000C101"
        ) ?? UUID()
        static let final: UUID = UUID(
            uuidString: "00000000-0000-0000-0000-00000000F101"
        ) ?? UUID()
    }

    @Test("MessagePersistor only updates changed channels during streaming")
    @MainActor
    internal func messagePersistorOnlyUpdatesChangedChannels() async throws {
        let database: Database = try Self.setupTestDatabase()
        let messageId: UUID = try await Self.createTestMessage(database)
        let persistor: MessagePersistor = MessagePersistor(database: database)

        let initialOutput: ProcessedOutput = createThreeChannelOutput(finalContent: "Initial response")
        try await persistor.updateMessage(messageId: messageId, output: initialOutput)

        let partialUpdate: ProcessedOutput = createThreeChannelOutput(finalContent: "Updated response text")
        try await persistor.updateMessage(messageId: messageId, output: partialUpdate)

        try await verifySelectiveChannelUpdate(database: database, messageId: messageId)
    }

    @Test("MessagePersistor can update only the final channel for streaming without reprocessing")
    @MainActor
    internal func messagePersistorUpdatesStreamingFinalChannel() async throws {
        let database: Database = try Self.setupTestDatabase()
        let messageId: UUID = try await Self.createTestMessage(database)
        let persistor: MessagePersistor = MessagePersistor(database: database)

        let initialOutput: ProcessedOutput = createThreeChannelOutput(finalContent: "Initial response")
        try await persistor.updateMessage(messageId: messageId, output: initialOutput)

        let updates: [String] = ["Streaming update 1", "Streaming update 2"]
        for update in updates {
            try await persistor.updateStreamingFinalChannel(
                messageId: messageId,
                content: update,
                isComplete: false
            )
        }

        let updatedMessage: Message = try await database.read(MessageCommands.Read(id: messageId))
        let channels: [Channel] = updatedMessage.sortedChannels
        assertFinalChannelState(channels: channels)
    }

    private func assertFinalChannelState(channels: [Channel]) {
        #expect(channels.count == Constants.channelCount)
        #expect(channels[Constants.analysisIndex].type == .analysis)
        #expect(channels[Constants.commentaryIndex].type == .commentary)
        #expect(channels[Constants.finalIndex].type == .final)
        #expect(channels[Constants.finalIndex].content == "Streaming update 2")
        #expect(channels[Constants.finalIndex].isComplete == false)
    }

    private func createThreeChannelOutput(finalContent: String) -> ProcessedOutput {
        ProcessedOutput(
            channels: [
                makeChannel(type: .analysis, content: "Initial analysis", order: Constants.analysisOrder),
                makeChannel(
                    type: .commentary,
                    content: "Initial comment",
                    order: Constants.commentaryOrder,
                    recipient: "user"
                ),
                makeChannel(type: .final, content: finalContent, order: Constants.finalOrder)
            ]
        )
    }

    private func makeChannel(
        type: ChannelMessage.ChannelType,
        content: String,
        order: Int,
        recipient: String? = nil
    ) -> ChannelMessage {
        ChannelMessage(
            id: stableId(for: type),
            type: type,
            content: content,
            order: order,
            recipient: recipient
        )
    }

    private func stableId(for type: ChannelMessage.ChannelType) -> UUID {
        switch type {
        case .analysis:
            return StreamingChannelIds.analysis

        case .commentary:
            return StreamingChannelIds.commentary

        case .final:
            return StreamingChannelIds.final

        case .tool:
            // Not used by these tests.
            return UUID()
        }
    }

    @MainActor
    private func verifySelectiveChannelUpdate(database: Database, messageId: UUID) async throws {
        let updatedMessage: Message = try await database.read(MessageCommands.Read(id: messageId))
        #expect(
            updatedMessage.channels?.count == Constants.channelCount,
            "Should still have 3 channels"
        )

        if let channels: [Channel] = updatedMessage.channels?.sorted(by: { $0.order < $1.order }) {
            #expect(
                channels[Constants.analysisIndex].content == "Initial analysis",
                "Analysis channel should remain unchanged"
            )
            #expect(
                channels[Constants.commentaryIndex].content == "Initial comment",
                "Commentary channel should remain unchanged"
            )
            #expect(
                channels[Constants.finalIndex].content == "Updated response text",
                "Final channel should be updated"
            )
        }
    }
}

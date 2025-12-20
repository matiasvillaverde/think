import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
@testable import Database
import Foundation
import Testing

@Suite("MessagePersistor Tests")
internal struct MessagePersistorTests {
    // MARK: - Test Helpers

    private enum ChannelIds {
        static let analysis: UUID = UUID(
            uuidString: "00000000-0000-0000-0000-00000000A101"
        ) ?? UUID()
        static let commentary: UUID = UUID(
            uuidString: "00000000-0000-0000-0000-00000000C101"
        ) ?? UUID()
        static let final: UUID = UUID(
            uuidString: "00000000-0000-0000-0000-00000000F101"
        ) ?? UUID()
        static let tool: UUID = UUID(
            uuidString: "00000000-0000-0000-0000-00000000D101"
        ) ?? UUID()
    }

    internal static func setupTestDatabase() throws -> Database {
        let config: DatabaseConfiguration = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        return try Database.new(configuration: config)
    }

    internal static func createTestMessage(_ database: Database) async throws -> UUID {
        try await addTestModels(database)
        let personalityId: UUID = getTestPersonalityId()
        let chatId: UUID = try await createTestChat(database, personalityId: personalityId)
        return try await createMessage(database, chatId: chatId)
    }

    private static func addTestModels(_ database: Database) async throws {
        let models: [ModelDTO] = [createLanguageModel(), createImageModel()]
        try await database.write(ModelCommands.AddModels(modelDTOs: models))
    }

    private static func createLanguageModel() -> ModelDTO {
        ModelDTO(
            type: .language,
            backend: .mlx,
            name: "test-llm",
            displayName: "Test LLM",
            displayDescription: "A test language model",
            skills: ["text-generation"],
            parameters: 100_000,
            ramNeeded: 100.megabytes,
            size: 50.megabytes,
            locationHuggingface: "test/llm",
            version: 1
        )
    }

    private static func createImageModel() -> ModelDTO {
        ModelDTO(
            type: .diffusion,
            backend: .mlx,
            name: "test-image",
            displayName: "Test Image",
            displayDescription: "A test image model",
            skills: ["image-generation"],
            parameters: 50_000,
            ramNeeded: 200.megabytes,
            size: 100.megabytes,
            locationHuggingface: "test/image",
            version: 1
        )
    }

    private static func getTestPersonalityId() -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
    }

    private static func createTestChat(
        _ database: Database,
        personalityId: UUID
    ) async throws -> UUID {
        try await database.write(ChatCommands.Create(personality: personalityId))
    }

    private static func createMessage(
        _ database: Database,
        chatId: UUID
    ) async throws -> UUID {
        try await database.write(
            MessageCommands.Create(
                chatId: chatId,
                userInput: "Test message",
                isDeepThinker: false
            )
        )
    }

    // MARK: - Tests

    @Test("MessagePersistor creates Channel entities from ProcessedOutput")
    @MainActor
    internal func messagePersistorCreatesChannelEntities() async throws {
        // Given
        let database: Database = try Self.setupTestDatabase()
        let messageId: UUID = try await Self.createTestMessage(database)
        let persistor: MessagePersistor = MessagePersistor(database: database)
        let processedOutput: ProcessedOutput = MessagePersistorTestHelpers.createFullProcessedOutput()

        // When
        try await persistor.updateMessage(messageId: messageId, output: processedOutput)

        // Then - verify channels were created as entities
        let message: Message = try await database.read(MessageCommands.Read(id: messageId))

        #expect(message.channels != nil, "Message should have channels")
        #expect(message.channels?.count == processedOutput.channels.count,
            "Should create exactly \(processedOutput.channels.count) channels")

        // Verify each channel has correct properties
        verifyChannelProperties(message.channels ?? [], expectedChannels: processedOutput.channels)
    }

    private func verifyChannelProperties(_ actualChannels: [Channel], expectedChannels: [ChannelMessage]) {
        // Sort both arrays by order to ensure proper comparison
        let sortedActual: [Channel] = actualChannels.sorted { $0.order < $1.order }
        let sortedExpected: [ChannelMessage] = expectedChannels.sorted { $0.order < $1.order }

        for (index, expectedChannel) in sortedExpected.enumerated() {
            guard index < sortedActual.count else {
                Issue.record("Missing channel at index \(index)")
                continue
            }
            let actualChannel: Channel = sortedActual[index]

            #expect(actualChannel.type.rawValue == expectedChannel.type.rawValue,
                "Channel \(index) type should be \(expectedChannel.type)")
            #expect(actualChannel.content == expectedChannel.content,
                "Channel \(index) content should match expected")
            #expect(actualChannel.order == expectedChannel.order,
                "Channel \(index) order should be \(expectedChannel.order)")
            #expect(actualChannel.recipient == expectedChannel.recipient,
                "Channel \(index) recipient should match")
        }
    }

    @Test("MessagePersistor updates existing Channel entities")
    @MainActor
    internal func messagePersistorUpdatesExistingChannelEntities() async throws {
        // Given
        let database: Database = try Self.setupTestDatabase()
        let messageId: UUID = try await Self.createTestMessage(database)
        let persistor: MessagePersistor = MessagePersistor(database: database)

        // Create initial channels
        let initialOutput: ProcessedOutput = MessagePersistorTestHelpers.createInitialOutput()
        try await persistor.updateMessage(
            messageId: messageId,
            output: initialOutput
        )

        // Verify initial state
        let initialMessage: Message = try await database.read(MessageCommands.Read(id: messageId))
        #expect(initialMessage.channels?.count == initialOutput.channels.count)

        // When - update with new content
        let updatedOutput: ProcessedOutput = MessagePersistorTestHelpers.createUpdatedOutput()
        try await persistor.updateMessage(
            messageId: messageId,
            output: updatedOutput
        )

        // Then - verify update worked
        let updatedMessage: Message = try await database.read(MessageCommands.Read(id: messageId))
        #expect(updatedMessage.channels?.count == updatedOutput.channels.count,
            "Channel count should match updated output")

        // Verify content was actually updated
        verifyChannelProperties(updatedMessage.channels ?? [], expectedChannels: updatedOutput.channels)
    }

    @Test("MessagePersistor handles empty channels")
    @MainActor
    internal func messagePersistorHandlesEmptyChannels() async throws {
        // Given
        let database: Database = try Self.setupTestDatabase()
        let messageId: UUID = try await Self.createTestMessage(database)
        let persistor: MessagePersistor = MessagePersistor(database: database)

        let processedOutput: ProcessedOutput = ProcessedOutput(
            channels: []
        )

        // When
        try await persistor.updateMessage(messageId: messageId, output: processedOutput)

        // Then - should not throw and channels should be empty or nil
        let message: Message = try await database.read(MessageCommands.Read(id: messageId))
        #expect(message.channels == nil || message.channels?.isEmpty == true,
            "Message should have no channels when ProcessedOutput has empty channels")
    }

    @Test("MessagePersistor handles incremental updates during streaming")
    @MainActor
    internal func messagePersistorHandlesIncrementalUpdates() async throws {
        // Given
        let database: Database = try Self.setupTestDatabase()
        let messageId: UUID = try await Self.createTestMessage(database)
        let persistor: MessagePersistor = MessagePersistor(database: database)

        // When - apply updates incrementally
        let streamingUpdates: [ProcessedOutput] = MessagePersistorTestHelpers.createStreamingUpdates()
        for update in streamingUpdates {
            try await persistor.updateMessage(messageId: messageId, output: update)
        }

        // Then - final state should have all channels with latest content
        let message: Message = try await database.read(MessageCommands.Read(id: messageId))
        let finalUpdate: ProcessedOutput = streamingUpdates.last ?? ProcessedOutput(channels: [])

        #expect(message.channels?.count == finalUpdate.channels.count,
            "Should have final channel count")

        // Verify final content matches last update
        verifyChannelProperties(message.channels ?? [], expectedChannels: finalUpdate.channels)
    }

    @Test("MessagePersistor only updates changed channels during streaming")
    @MainActor
    internal func messagePersistorOnlyUpdatesChangedChannels() async throws {
        // Given
        let database: Database = try Self.setupTestDatabase()
        let messageId: UUID = try await Self.createTestMessage(database)
        let persistor: MessagePersistor = MessagePersistor(database: database)

        // Create initial channels
        let initialOutput: ProcessedOutput = createThreeChannelOutput(finalContent: "Initial response")
        try await persistor.updateMessage(messageId: messageId, output: initialOutput)

        // When - update only the final channel
        let partialUpdate: ProcessedOutput = createThreeChannelOutput(finalContent: "Updated response text")
        try await persistor.updateMessage(messageId: messageId, output: partialUpdate)

        // Then - verify selective update
        try await verifySelectiveChannelUpdate(database: database, messageId: messageId)
    }

    private func createThreeChannelOutput(finalContent: String) -> ProcessedOutput {
        ProcessedOutput(
            channels: [
                makeChannel(type: .analysis, content: "Initial analysis", order: 0),
                makeChannel(type: .commentary, content: "Initial comment", order: 1, recipient: "user"),
                makeChannel(type: .final, content: finalContent, order: 2)
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
            return ChannelIds.analysis

        case .commentary:
            return ChannelIds.commentary

        case .final:
            return ChannelIds.final

        case .tool:
            return ChannelIds.tool
        }
    }

    @MainActor
    private func verifySelectiveChannelUpdate(database: Database, messageId: UUID) async throws {
        let updatedMessage: Message = try await database.read(MessageCommands.Read(id: messageId))
        #expect(updatedMessage.channels?.count == 3, "Should still have 3 channels")

        // Verify analysis and commentary unchanged, final updated
        if let channels = updatedMessage.channels?.sorted(by: { $0.order < $1.order }) {
            #expect(channels[0].content == "Initial analysis",
                "Analysis channel should remain unchanged")
            #expect(channels[1].content == "Initial comment",
                "Commentary channel should remain unchanged")
            #expect(channels[2].content == "Updated response text",
                "Final channel should be updated")
        }
    }

    @Test("MessagePersistor marks channels as complete appropriately")
    @MainActor
    internal func messagePersistorMarksChannelsAsComplete() async throws {
        // Given
        let database: Database = try Self.setupTestDatabase()
        let messageId: UUID = try await Self.createTestMessage(database)
        let persistor: MessagePersistor = MessagePersistor(database: database)

        // When - create incomplete channels
        let incompleteOutput: ProcessedOutput = MessagePersistorTestHelpers.createIncompleteChannelOutput()
        try await persistor.updateMessage(messageId: messageId, output: incompleteOutput)

        // Then update to complete
        let completeOutput: ProcessedOutput = MessagePersistorTestHelpers.createCompleteChannelOutput()
        try await persistor.updateMessage(messageId: messageId, output: completeOutput)

        // Then - channels should be marked as complete appropriately
        let message: Message = try await database.read(MessageCommands.Read(id: messageId))
        #expect(message.channels != nil, "Message should have channels")

        // Verify completion status based on channel type and content
        if let channels = message.channels {
            for channel in channels where channel.type == .final && !channel.content.isEmpty {
                #expect(channel.isComplete,
                    "Final channel with content should be marked complete")
            }
        }
    }
}

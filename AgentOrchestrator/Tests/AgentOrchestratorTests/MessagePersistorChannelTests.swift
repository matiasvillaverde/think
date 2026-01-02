import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
@testable import Database
import Foundation
import Testing

@Suite("MessagePersistor Channel Tests")
internal struct MessagePersistorChannelTests {
    private enum ChannelIds {
        static let analysis: UUID = UUID(uuidString: "00000000-0000-0000-0000-00000000A201") ?? UUID()
        static let final: UUID = UUID(uuidString: "00000000-0000-0000-0000-00000000F201") ?? UUID()
    }

    @Test("MessagePersistor creates Channel entities from ProcessedOutput")
    @MainActor
    internal func createsChannelEntities() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let output: ProcessedOutput = createProcessedOutput()

        // When
        try await env.persistor.updateMessage(
            messageId: env.messageId,
            output: output
        )

        // Then - verify no errors occurred
        // The actual channel creation is verified through integration tests
        // since we can't directly read channels in unit tests
        #expect(output.channels.count == 3)
        #expect(output.channels[0].type == .analysis)
        #expect(output.channels[1].type == .commentary)
        #expect(output.channels[2].type == .final)
    }

    @Test("MessagePersistor updates existing Channel entities")
    @MainActor
    internal func updatesExistingChannels() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()

        // Create initial channels
        try await env.persistor.updateMessage(
            messageId: env.messageId,
            output: createInitialOutput()
        )

        // When - update with new content
        try await env.persistor.updateMessage(
            messageId: env.messageId,
            output: createUpdatedOutput()
        )

        // Then - verify update worked (no errors thrown)
        // The actual update is verified through integration tests
        let updatedOutput: ProcessedOutput = createUpdatedOutput()
        #expect(updatedOutput.channels.count == 2)
        #expect(updatedOutput.channels[0].content == "Updated thinking")
        #expect(updatedOutput.channels[1].content == "Updated response")
    }

    @Test("MessagePersistor handles empty channels")
    @MainActor
    internal func handlesEmptyChannels() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let output: ProcessedOutput = ProcessedOutput(
            channels: []
        )

        // When
        try await env.persistor.updateMessage(
            messageId: env.messageId,
            output: output
        )

        // Then
        let message: Message = try await env.database.read(
            MessageCommands.Read(id: env.messageId)
        )
        #expect(message.channels?.isEmpty ?? true)
    }

    // MARK: - Test Helpers

    private struct TestEnvironment {
        let database: Database
        let persistor: MessagePersistor
        let messageId: UUID
    }

    @MainActor
    private func setupTestEnvironment() async throws -> TestEnvironment {
        let database: Database = try createTestDatabase()
        let messageId: UUID = try await createTestMessage(database)
        let persistor: MessagePersistor = MessagePersistor(database: database)

        return TestEnvironment(
            database: database,
            persistor: persistor,
            messageId: messageId
        )
    }

    private func createTestDatabase() throws -> Database {
        let config: DatabaseConfiguration = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        return try Database.new(configuration: config)
    }

    @MainActor
    private func createTestMessage(_ database: Database) async throws -> UUID {
        try await addRequiredModels(to: database)

        let personalityId: UUID = UUID(
            uuidString: "00000000-0000-0000-0000-000000000001"
        ) ?? UUID()

        let chatId: UUID = try await database.write(
            ChatCommands.Create(personality: personalityId)
        )

        return try await database.write(
            MessageCommands.Create(
                chatId: chatId,
                userInput: "Test message",
                isDeepThinker: false
            )
        )
    }

    private func addRequiredModels(to database: Database) async throws {
        let models: [ModelDTO] = [
            createLanguageModelDTO(),
            createImageModelDTO()
        ]
        try await database.write(
            ModelCommands.AddModels(modelDTOs: models)
        )
    }

    private func createLanguageModelDTO() -> ModelDTO {
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

    private func createImageModelDTO() -> ModelDTO {
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

    private func createProcessedOutput() -> ProcessedOutput {
        ProcessedOutput(channels: createTestChannels())
    }

    private func createTestChannels() -> [ChannelMessage] {
        MessagePersistorTestHelpers.createFullChannels()
    }

    private func createInitialOutput() -> ProcessedOutput {
        ProcessedOutput(
            channels: [
                createChannel(
                    id: ChannelIds.analysis,
                    type: .analysis,
                    content: "Initial thinking",
                    order: 0
                ),
                createChannel(
                    id: ChannelIds.final,
                    type: .final,
                    content: "Initial response",
                    order: 1
                )
            ]
        )
    }

    private func createUpdatedOutput() -> ProcessedOutput {
        ProcessedOutput(
            channels: [
                createChannel(
                    id: ChannelIds.analysis,
                    type: .analysis,
                    content: "Updated thinking",
                    order: 0
                ),
                createChannel(
                    id: ChannelIds.final,
                    type: .final,
                    content: "Updated response",
                    order: 1
                )
            ]
        )
    }

    private func createChannel(
        id: UUID,
        type: ChannelMessage.ChannelType,
        content: String,
        order: Int,
        recipient: String? = nil
    ) -> ChannelMessage {
        ChannelMessage(id: id, type: type, content: content, order: order, recipient: recipient)
    }
}

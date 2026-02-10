import Abstractions
import AbstractionsTestUtilities
import Foundation
import Testing
@testable import Database

@Suite("UpdateProcessedOutput Deduping Tests")
@MainActor
struct UpdateProcessedOutputDedupingTests {
    @Test("Streaming final channel is merged with processed output (no duplicate final channels)")
    func streamingFinalMergedWithProcessedOutput() async throws {
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)

        try await database.write(PersonalityCommands.WriteDefault())
        try await addRequiredModelsForMessageCommands(database)

        let defaultPersonalityId = try await database.read(PersonalityCommands.GetDefault())
        let models = try await database.read(ModelCommands.FetchAll())
        let languageModel = try #require(models.first(where: { $0.modelType == .language }))

        let chatId = try await database.write(
            ChatCommands.CreateWithModel(
                modelId: languageModel.id,
                personalityId: defaultPersonalityId
            )
        )

        let messageId = try await database.write(
            MessageCommands.Create(
                chatId: chatId,
                userInput: "Hello",
                isDeepThinker: false
            )
        )

        // Simulate early streaming before any ProcessedOutput is persisted.
        _ = try await database.write(
            MessageCommands.UpdateFinalChannelContent(
                messageId: messageId,
                content: "Streaming...",
                isComplete: false
            )
        )

        let processed = ProcessedOutput(
            channels: [
                ChannelMessage(
                    id: UUID(),
                    type: .analysis,
                    content: "Thinking",
                    order: 0,
                    isComplete: true
                ),
                // Intentionally different UUID and order from the streaming-created channel.
                ChannelMessage(
                    id: UUID(),
                    type: .final,
                    content: "Done",
                    order: 1,
                    isComplete: true
                )
            ]
        )

        _ = try await database.write(
            MessageCommands.UpdateProcessedOutput(
                messageId: messageId,
                processedOutput: processed
            )
        )

        let message = try await database.read(MessageCommands.Read(id: messageId))
        let finals = message.channels?.filter { $0.type == .final } ?? []
        #expect(finals.count == 1)
        #expect(finals.first?.content == "Done")
        #expect(message.channels?.contains(where: { $0.type == .analysis }) == true)
    }

    @Test("Tool channels are matched by identity (type/recipient/order), preserving existing tool execution and tool id")
    func toolChannelIdMismatchDoesNotDuplicateToolExecution() async throws {
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)

        try await database.write(PersonalityCommands.WriteDefault())
        try await addRequiredModelsForMessageCommands(database)

        let defaultPersonalityId = try await database.read(PersonalityCommands.GetDefault())
        let models = try await database.read(ModelCommands.FetchAll())
        let languageModel = try #require(models.first(where: { $0.modelType == .language }))

        let chatId = try await database.write(
            ChatCommands.CreateWithModel(
                modelId: languageModel.id,
                personalityId: defaultPersonalityId
            )
        )

        let messageId = try await database.write(
            MessageCommands.Create(
                chatId: chatId,
                userInput: "Hello",
                isDeepThinker: false
            )
        )

        let toolRequestId1 = UUID()
        let toolRequestId2 = UUID()

        let toolRequest1 = ToolRequest(
            name: "calculator",
            arguments: "{\"a\":1}",
            isComplete: true,
            displayName: "Calculator",
            recipient: "functions.calculator",
            id: toolRequestId1
        )
        let toolRequest2 = ToolRequest(
            name: "calculator",
            arguments: "{\"a\":2}",
            isComplete: true,
            displayName: "Calculator",
            recipient: "functions.calculator",
            id: toolRequestId2
        )

        let first = ProcessedOutput(
            channels: [
                ChannelMessage(
                    id: UUID(),
                    type: .tool,
                    content: "Tool: Calculator",
                    order: 0,
                    isComplete: true,
                    recipient: "functions.calculator",
                    toolRequest: toolRequest1
                ),
                ChannelMessage(
                    id: UUID(),
                    type: .final,
                    content: "Waiting",
                    order: 1,
                    isComplete: false
                )
            ]
        )

        _ = try await database.write(
            MessageCommands.UpdateProcessedOutput(messageId: messageId, processedOutput: first)
        )

        let second = ProcessedOutput(
            channels: [
                // Different ChannelMessage.id and ToolRequest.id, but same conceptual tool channel identity.
                ChannelMessage(
                    id: UUID(),
                    type: .tool,
                    content: "Tool: Calculator",
                    order: 0,
                    isComplete: true,
                    recipient: "functions.calculator",
                    toolRequest: toolRequest2
                ),
                ChannelMessage(
                    id: UUID(),
                    type: .final,
                    content: "Done",
                    order: 1,
                    isComplete: true
                )
            ]
        )

        _ = try await database.write(
            MessageCommands.UpdateProcessedOutput(messageId: messageId, processedOutput: second)
        )

        let message = try await database.read(MessageCommands.Read(id: messageId))
        let tools = message.channels?.filter { $0.type == .tool } ?? []
        #expect(tools.count == 1)
        let toolChannel = try #require(tools.first)
        #expect(toolChannel.toolExecution != nil)
        #expect(toolChannel.associatedToolId == toolRequestId1)
    }
}


import Abstractions
import AbstractionsTestUtilities
import Foundation
import SwiftData
import Testing
@testable import Database

@Suite("UpdateFinalChannelContent Tests")
@MainActor
struct UpdateFinalChannelContentTests {
    @Test("Updates final channel without removing other channels or tool executions")
    func updatesFinalChannelPreservingTools() async throws {
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
                userInput: "Test",
                isDeepThinker: false
            )
        )

        let toolRequestId = UUID()
        let toolChannelId = UUID()
        let finalChannelId = UUID()
        let toolRequest = ToolRequest(
            name: "calculator",
            arguments: "{}",
            isComplete: true,
            displayName: "Calculator",
            recipient: "functions.calculator",
            id: toolRequestId
        )

        let initial = ProcessedOutput(
            channels: [
                ChannelMessage(
                    id: toolChannelId,
                    type: .tool,
                    content: "Tool: Calculator",
                    order: 0,
                    isComplete: true,
                    recipient: "functions.calculator",
                    toolRequest: toolRequest
                ),
                ChannelMessage(
                    id: finalChannelId,
                    type: .final,
                    content: "Hello",
                    order: 1,
                    isComplete: false
                )
            ]
        )

        _ = try await database.write(
            MessageCommands.UpdateProcessedOutput(messageId: messageId, processedOutput: initial)
        )

        // Sanity: tool execution exists and is attached.
        let before = try await database.read(MessageCommands.Read(id: messageId))
        #expect(before.channels?.count == 2)
        #expect(before.channels?.contains(where: { $0.type == .tool }) == true)
        #expect(before.channels?.compactMap(\.toolExecution).count == 1)

        _ = try await database.write(
            MessageCommands.UpdateFinalChannelContent(
                messageId: messageId,
                content: "Hello world",
                isComplete: false
            )
        )

        let after = try await database.read(MessageCommands.Read(id: messageId))
        let sorted = after.sortedChannels
        #expect(sorted.count == 2)
        #expect(sorted[0].type == .tool)
        #expect(sorted[0].toolExecution != nil)
        #expect(sorted[1].type == .final)
        #expect(sorted[1].content == "Hello world")
    }

    @Test("Marks final channel complete when requested")
    func marksFinalChannelComplete() async throws {
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
                userInput: "Test",
                isDeepThinker: false
            )
        )

        let finalChannelId = UUID()
        let initial = ProcessedOutput(
            channels: [
                ChannelMessage(
                    id: finalChannelId,
                    type: .final,
                    content: "Partial",
                    order: 0,
                    isComplete: false
                )
            ]
        )
        _ = try await database.write(
            MessageCommands.UpdateProcessedOutput(messageId: messageId, processedOutput: initial)
        )

        _ = try await database.write(
            MessageCommands.UpdateFinalChannelContent(
                messageId: messageId,
                content: "Done",
                isComplete: true
            )
        )

        let message = try await database.read(MessageCommands.Read(id: messageId))
        let final = try #require(message.channels?.first(where: { $0.type == .final }))
        #expect(final.content == "Done")
        #expect(final.isComplete == true)
    }
}


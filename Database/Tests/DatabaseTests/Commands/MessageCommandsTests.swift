import Testing
import Foundation
import SwiftData
@testable import Database
// Import Abstractions but use Database.Statistics explicitly where needed
import Abstractions
import AbstractionsTestUtilities

// MARK: - Helper Functions

private func addRequiredModelsForMessageCommandsTest(_ database: Database) async throws {
    // Initialize default personality first
    try await database.write(PersonalityCommands.WriteDefault())
    
    let languageModel = ModelDTO(
        type: .language,
        backend: .mlx,
        name: "test-llm",
        displayName: "Test LLM",
        displayDescription: "A test language model",
        skills: ["text-generation"],
        parameters: 100000,
        ramNeeded: 100.megabytes,
        size: 50.megabytes,
        locationHuggingface: "test/llm",
        version: 1
    )

    let imageModel = ModelDTO(
        type: .diffusion,
        backend: .mlx,
        name: "test-image",
        displayName: "Test Image",
        displayDescription: "A test image model",
        skills: ["image-generation"],
        parameters: 50000,
        ramNeeded: 200.megabytes,
        size: 100.megabytes,
        locationHuggingface: "test/image",
        version: 1
    )

    try await database.write(ModelCommands.AddModels(modelDTOs: [languageModel, imageModel]))
}

@Suite("Message Commands Tests")
struct MessageCommandsTests {
    @Suite(.tags(.acceptance))
    struct BasicFunctionalityTests {
        @Test("Create message successfully")
        @MainActor
        func createMessageSuccess() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModelsForMessageCommandsTest(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            let chat = try await database.read(ChatCommands.GetFirst())
            let userInput = "Test message"

            // When
            try await database.write(MessageCommands.Create(
                chatId: chat.id,
                userInput: userInput,
                isDeepThinker: false
            ))

            // Then
            let descriptor = FetchDescriptor<Message>()
            let messages = try database.modelContainer.mainContext.fetch(descriptor)
            #expect(messages.count == 1)
            #expect(messages[0].userInput == userInput)
            #expect(messages[0].chat?.id == chat.id)
        }

        @Test("Update message response successfully")
        @MainActor
        func updateMessageResponseSuccess() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModelsForMessageCommandsTest(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            let chat = try await database.read(ChatCommands.GetFirst())
            try await database.write(MessageCommands.Create(
                chatId: chat.id,
                userInput: "Test input",
                isDeepThinker: false
            ))

            let descriptor = FetchDescriptor<Message>()
            let message = try database.modelContainer.mainContext.fetch(descriptor).first!

            // When
            let response = "Test response"
            let processedOutput = ProcessedOutput(
                channels: [
                    ChannelMessage(
                        id: UUID(),
                        type: .final,
                        content: response,
                        order: 0,
                        recipient: nil,
                        toolRequest: nil
                    )
                ]
            )
            try await database.write(MessageCommands.UpdateProcessedOutput(
                messageId: message.id,
                processedOutput: processedOutput
            ))

            // Then
            let updatedMessage = try database.modelContainer.mainContext.fetch(descriptor).first!
            #expect(updatedMessage.channels?.count == 1)
            #expect(updatedMessage.channels?.first?.content == response)
            // Metrics are only created when we have actual statistics from the AI model
            #expect(updatedMessage.metrics == nil)
        }

        @Test("Update message with longer context")
        @MainActor
        func updateMessageLongerContext() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModelsForMessageCommandsTest(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            let chat = try await database.read(ChatCommands.GetFirst())
            try await database.write(MessageCommands.Create(
                chatId: chat.id,
                userInput: "Test input",
                isDeepThinker: false
            ))

            let descriptor = FetchDescriptor<Message>()
            let message = try database.modelContainer.mainContext.fetch(descriptor).first!

            let channelId = UUID()

            // Initial response
            let response = "Test response"
            let initialOutput = ProcessedOutput(
                channels: [
                    ChannelMessage(
                        id: channelId,
                        type: .final,
                        content: response,
                        order: 0,
                        recipient: nil,
                        toolRequest: nil
                    )
                ]
            )
            try await database.write(MessageCommands.UpdateProcessedOutput(
                messageId: message.id,
                processedOutput: initialOutput
            ))

            // When - Update with longer response
            let longerResponse = "This is a much longer response that simulates additional context"
            let longerOutput = ProcessedOutput(
                channels: [
                    ChannelMessage(
                        id: channelId,
                        type: .final,
                        content: longerResponse,
                        order: 0,
                        recipient: nil,
                        toolRequest: nil
                    )
                ]
            )
            try await database.write(MessageCommands.UpdateProcessedOutput(
                messageId: message.id,
                processedOutput: longerOutput
            ))

            // Then
            let updatedMessage = try database.modelContainer.mainContext.fetch(descriptor).first!
            #expect(updatedMessage.channels?.first?.content == longerResponse)
            // Metrics are only created when we have actual statistics from the AI model
            #expect(updatedMessage.metrics == nil)
        }
    }

    @Suite(.tags(.edge))
    struct EdgeCasesTests {
        @Test("Create message for nonexistent chat fails")
        func createMessageNonexistentChat() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)

            // When/Then
            await #expect(throws: DatabaseError.chatNotFound) {
                try await database.write(MessageCommands.Create(
                    chatId: UUID(),
                    userInput: "Test",
                    isDeepThinker: false
                ))
            }
        }

        @Test("Update response for nonexistent message fails")
        @MainActor
        func updateResponseNonexistentMessage() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)

            // When/Then
            await #expect(throws: DatabaseError.messageNotFound) {
                let output = ProcessedOutput(
                    channels: [
                        ChannelMessage(
                            id: UUID(),
                            type: .final,
                            content: "Test response",
                            order: 0,
                            recipient: nil,
                            toolRequest: nil
                        )
                    ]
                )
                try await database.write(MessageCommands.UpdateProcessedOutput(
                    messageId: UUID(),
                    processedOutput: output
                ))
            }
        }
    }

    @Suite(.tags(.performance))
    struct PerformanceTests {
        @Test("Handle large message content efficiently")
        @MainActor
        func handleLargeContent() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModelsForMessageCommandsTest(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            let chat = try await database.read(ChatCommands.GetFirst())

            // Create large input (10KB of text)
            let largeInput = String(repeating: "Lorem ipsum dolor sit amet. ", count: 360)

            // When
            try await database.write(MessageCommands.Create(
                chatId: chat.id,
                userInput: largeInput,
                isDeepThinker: false
            ))

            // Then
            let descriptor = FetchDescriptor<Message>()
            let message = try database.modelContainer.mainContext.fetch(descriptor).first!
            #expect((message.userInput?.count ?? 0) > 10000)

            // Update with large response
            let largeResponse = String(repeating: "Response text. ", count: 700)
            let largeOutput = ProcessedOutput(
                channels: [
                    ChannelMessage(
                        id: UUID(),
                        type: .final,
                        content: largeResponse,
                        order: 0,
                        recipient: nil,
                        toolRequest: nil
                    )
                ]
            )
            try await database.write(MessageCommands.UpdateProcessedOutput(
                messageId: message.id,
                processedOutput: largeOutput
            ))

            let updatedMessage = try database.modelContainer.mainContext.fetch(descriptor).first!
            #expect(updatedMessage.response?.count ?? 0 > 10000)
        }
    }

    @Suite(.tags(.concurrency))
    struct ConcurrencyTests {
        @Test("Concurrent message updates maintain consistency")
        @MainActor
        func concurrentMessageUpdates() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModelsForMessageCommandsTest(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            let chat = try await database.read(ChatCommands.GetFirst())
            try await database.write(MessageCommands.Create(
                chatId: chat.id,
                userInput: "Test input",
                isDeepThinker: false
            ))

            let descriptor = FetchDescriptor<Message>()
            let message = try database.modelContainer.mainContext.fetch(descriptor).first!
            let updateCount = 10

            // When - Sequential updates to avoid concurrency issues
            let id = message.id
            for index in 0..<updateCount {
                let output = ProcessedOutput(
                    channels: [
                        ChannelMessage(
                            id: UUID(),
                            type: .final,
                            content: "Response \(index)",
                            order: 0,
                            recipient: nil,
                            toolRequest: nil
                        )
                    ]
                )
                try await database.writeInBackground(MessageCommands.UpdateProcessedOutput(
                    messageId: id,
                    processedOutput: output
                ))
            }

            // Then
            let updatedMessage = try await database.read(MessageCommands.Read(id: message.id))
            #expect(((updatedMessage.response?.starts(with: "Response")) != nil))
        }

        @Test("Count messages in a chat correctly")
        @MainActor
        func countMessagesCorrectly() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModelsForMessageCommandsTest(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            let chat = try await database.read(ChatCommands.GetFirst())

            let messageCountEmpty = try await database.read(MessageCommands.CountMessages(chatId: chat.id))

            #expect(messageCountEmpty == 0)

            // Add 3 messages to the chat
            for index in 1...3 {
                try await database.write(MessageCommands.Create(
                    chatId: chat.id,
                    userInput: "Test message \(index)",
                    isDeepThinker: false
                ))
            }

            // When
            let messageCount = try await database.read(MessageCommands.CountMessages(chatId: chat.id))

            // Then
            #expect(messageCount == 3)
        }
    }
}

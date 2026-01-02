import Testing
import Foundation
import SwiftData
import Abstractions
@testable import Database

// swiftlint:disable line_length
import AbstractionsTestUtilities

// MARK: - Helper Functions

private func updateMessageWithResponse(_ database: Database, messageId: UUID, response: String) async throws {
    let output = ProcessedOutput(
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
        messageId: messageId,
        processedOutput: output
    ))
}

private func addRequiredModelsForAutoRenameTest(_ database: Database) async throws {
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

@Suite("AutoRenameFromContent Tests")
struct AutoRenameFromContentTests {
    @Suite(.tags(.acceptance))
    struct BasicFunctionalityTests {
        @Test("Auto rename chat with default name using second message")
        @MainActor
        func autoRenameChatWithDefaultName() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModelsForAutoRenameTest(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            // Add first message (user input)
            _ = try await database.write(MessageCommands.Create(
                chatId: chatId,
                userInput: "Hello",
                isDeepThinker: false
            ))

            let message2Id = try await database.write(MessageCommands.Create(
                chatId: chatId,
                userInput: "Tell me about quantum computing",
                isDeepThinker: false
            ))

            try await updateMessageWithResponse(
                database,
                messageId: message2Id,
                response: "Quantum computing is a form of computing that uses quantum mechanical phenomena."
            )

            // When
            try await database.write(ChatCommands.AutoRenameFromContent(chatId: chatId))

            // Then
            let updatedChat = try await database.read(ChatCommands.Read(chatId: chatId))
            #expect(updatedChat.name != "New Chat")
            #expect(updatedChat.name.starts(with: "Quantum computing is a form of computing"))
        }

        @Test("Does not rename chat that already has custom name")
        @MainActor
        func doesNotRenameCustomNamedChat() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModelsForAutoRenameTest(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            // Set a custom name
            let customName = "My Custom Chat Name"
            try await database.write(ChatCommands.Rename(chatId: chatId, newName: customName))

            // Add messages
            let message1Id = try await database.write(MessageCommands.Create(
                chatId: chatId,
                userInput: "Tell me about AI ethics",
                isDeepThinker: false
            ))

            try await updateMessageWithResponse(
                database,
                messageId: message1Id,
                response: "AI ethics concerns the moral behavior and responsible use of artificial intelligence systems."
            )

            // When
            try await database.write(ChatCommands.AutoRenameFromContent(chatId: chatId))

            // Then
            let updatedChat = try await database.read(ChatCommands.Read(chatId: chatId))
            #expect(updatedChat.name == customName)
        }
    }

    @Suite(.tags(.edge))
    struct EdgeCasesTests {
        @Test("No rename when chat has no messages")
        @MainActor
        func noRenameWithoutMessages() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModelsForAutoRenameTest(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            // When
            try await database.write(ChatCommands.AutoRenameFromContent(chatId: chatId))

            // Then
            let chat = try await database.read(ChatCommands.Read(chatId: chatId))
            #expect(chat.name == "New Chat")
        }

        @Test("No rename when chat has only one message")
        @MainActor
        func noRenameWithOnlyOneMessage() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModelsForAutoRenameTest(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            // Add just one message
            _ = try await database.write(MessageCommands.Create(
                chatId: chatId,
                userInput: "Hello there",
                isDeepThinker: false
            ))

            // No response added

            // When
            try await database.write(ChatCommands.AutoRenameFromContent(chatId: chatId))

            // Then
            let chat = try await database.read(ChatCommands.Read(chatId: chatId))
            #expect(chat.name == "New Chat")
        }
    }

    @Suite(.tags(.core))
    struct ValidationTests {
        @Test("Generated name respects maximum length")
        @MainActor
        func generatedNameRespectsMaxLength() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModelsForAutoRenameTest(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            // Add first message
            let message1Id = try await database.write(MessageCommands.Create(
                chatId: chatId,
                userInput: "Tell me about history",
                isDeepThinker: false
            ))

            // Add a very long response
            let longText = """
            The study of history encompasses a vast range of human experiences, civilizations, and events spanning from prehistory to the present day. It includes the examination of documents, archaeological findings, and other sources to understand how societies, cultures, and technologies have evolved over time.
            """

            try await updateMessageWithResponse(
                database,
                messageId: message1Id,
                response: longText
            )

            // When
            try await database.write(ChatCommands.AutoRenameFromContent(chatId: chatId))

            // Then
            let chat = try await database.read(ChatCommands.Read(chatId: chatId))
            #expect(chat.name.count <= 33) // 30 chars + "..." if truncated
        }

        @Test("Generated name has valid characters")
        @MainActor
        func generatedNameHasValidCharacters() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModelsForAutoRenameTest(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            // Add first message with special characters
            let message1Id = try await database.write(MessageCommands.Create(
                chatId: chatId,
                userInput: "What is C++?",
                isDeepThinker: false
            ))

            try await updateMessageWithResponse(
                database,
                messageId: message1Id,
                response: "C++ is a programming language used for systems programming, game development, and other performance-critical applications."
            )

            // When
            try await database.write(ChatCommands.AutoRenameFromContent(chatId: chatId))

            // Then
            let chat = try await database.read(ChatCommands.Read(chatId: chatId))

            // Check that the name contains valid characters
            let validCharacterSet = CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: "-_"))
            let nameContainsOnlyValidChars = chat.name.unicodeScalars.allSatisfy { validCharacterSet.contains($0) }

            #expect(nameContainsOnlyValidChars)
        }
    }

    @Suite(.tags(.performance))
    struct PerformanceTests {
        @Test("Auto rename performance is acceptable")
        @MainActor
        func autoRenamePerformance() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModelsForAutoRenameTest(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)

            // Create multiple chats with messages
            var chatIds: [UUID] = []
            for _ in 0..<5 {
                let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))
                chatIds.append(chatId)

                let messageId = try await database.write(MessageCommands.Create(
                    chatId: chatId,
                    userInput: "Tell me something interesting",
                    isDeepThinker: false
                ))

                try await updateMessageWithResponse(
                    database,
                    messageId: messageId,
                    response: "Technology continues to advance at an exponential rate, following Moore's Law which predicts computing power doubles approximately every two years."
                )
            }

            // When
            let start = ProcessInfo.processInfo.systemUptime

            for chatId in chatIds {
                try await database.write(ChatCommands.AutoRenameFromContent(chatId: chatId))
            }

            let duration = ProcessInfo.processInfo.systemUptime - start

            // Then
            #expect(duration < 0.5) // Auto rename should be very fast now, under half a second
        }
    }

    @Suite(.tags(.state))
    struct MessageOrderingTests {
        @Test("Uses second message by creation date")
        @MainActor
        func usesSecondMessageByCreationDate() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModelsForAutoRenameTest(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            // Create messages in chronological order
            let message1Id = try await database.write(MessageCommands.Create(
                chatId: chatId,
                userInput: "Tell me about climate change",
                isDeepThinker: false
            ))

            // Sleep to ensure different timestamps
            try await Task.sleep(for: .milliseconds(100))

            let message2Id = try await database.write(MessageCommands.Create(
                chatId: chatId,
                userInput: "What about renewable energy?",
                isDeepThinker: false
            ))

            // Add responses
            try await updateMessageWithResponse(
                database,
                messageId: message1Id,
                response: "Climate change refers to long-term shifts in temperatures and weather patterns."
            )

            try await updateMessageWithResponse(
                database,
                messageId: message2Id,
                response: "Renewable energy is energy from sources that are naturally replenishing."
            )

            // When
            try await database.write(ChatCommands.AutoRenameFromContent(chatId: chatId))

            // Then
            let chat = try await database.read(ChatCommands.Read(chatId: chatId))
            #expect(chat.name.contains("Renewable energy"))
        }
    }
}

import Testing
import Foundation
import SwiftData
@testable import Database
import AbstractionsTestUtilities
import Abstractions

// swiftlint:disable non_optional_string_data_conversion

// MARK: - Helper Functions

private func addRequiredModelsForComplexTests(_ database: Database) async throws {
    // Initialize default personality first
    try await database.write(PersonalityCommands.WriteDefault())
    
    // Add language models
    let languageModel = ModelDTO(
        type: .language,
        backend: .mlx,
        name: "test-llm",
        displayName: "Test LLM",
        displayDescription: "A test language model",
        skills: ["text-generation"],
        parameters: 100000,
        ramNeeded: 100_000_000,
        size: 50_000_000,
        locationHuggingface: "test/llm",
        version: 1
    )

    // Add image model
    let imageModel = ModelDTO(
        type: .diffusion,
        backend: .mlx,
        name: "test-image",
        displayName: "Test Image",
        displayDescription: "A test image model",
        skills: ["image-generation"],
        parameters: 50000,
        ramNeeded: 200_000_000,
        size: 100_000_000,
        locationHuggingface: "test/image",
        version: 1
    )

    try await database.write(ModelCommands.AddModels(models: [languageModel, imageModel]))
}

@Suite("Complex Chat Session Acceptance Tests")
struct ComplexChatSessionTests {
    @Test("Complete chat session with multiple message types and attachments")
    @MainActor
    func complexChatSession() async throws {
        // Given - Setup database and required models
        let mockRag = MockRagging()
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: mockRag)
        )

        let database = try Database.new(configuration: config)
        try await addRequiredModelsForComplexTests(database)

        // Step 1: Create a new chat
        let defaultPersonalityId = try await getDefaultPersonalityId(database)
        try await database.write(ChatCommands.Create(personality: defaultPersonalityId))
        var chat = try await database.read(ChatCommands.GetFirst())

        // Step 2: Rename the chat
        let newChatName = "Project Discussion"
        try await database.write(ChatCommands.Rename(chatId: chat.id, newName: newChatName))
        chat = try await database.read(ChatCommands.GetFirst())
        #expect(chat.name == newChatName)

        // Step 3: Add initial message
        try await database.write(MessageCommands.Create(
            chatId: chat.id,
            userInput: "Let's discuss the project requirements",
            isDeepThinker: false
        ))

        // Step 4: Create and attach a file
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("requirements.txt")
        try "Project requirements document".write(to: fileURL, atomically: true, encoding: .utf8)

        try await database.write(FileCommands.Create(
            fileURL: fileURL,
            chatId: chat.id,
            database: database
        ))

        // Verify file attachment
        let hasAttachments = try await database.read(ChatCommands.HasAttachments(chatId: chat.id))
        #expect(hasAttachments == true)

        // Step 5: Add a response with image
        let messages = chat.messages
        guard let firstMessage = messages.first else {
            throw DatabaseError.modelNotFound
        }

        let imageData = "Test image data".data(using: .utf8)!
        try await database.write(ImageCommands.AddResponse(
            messageId: firstMessage.id,
            imageData: imageData,
            configuration: chat.imageModelConfig.id,
            prompt: "Project visualization"
        ))

        // Step 6: Add follow-up messages
        try await database.write(MessageCommands.Create(
            chatId: chat.id,
            userInput: "Can you analyze the requirements?",
            isDeepThinker: false
        ))

        // Verify final state
        let finalMessages = chat.messages
        #expect(finalMessages.count == 2)

        // Metrics are only created when we have actual statistics from the AI model
        // Since we didn't provide statistics in UpdateResponse, metrics should be nil
        #expect(firstMessage.metrics == nil)

        let responseImage = try await database.read(ImageCommands.GetResponse(messageId: firstMessage.id))
        #expect(responseImage != nil)

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test("Edge cases in complex chat session")
    @MainActor
    func complexChatSessionEdgeCases() async throws {
        // Given
        let mockRag = MockRagging()
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: mockRag)
        )

        let database = try Database.new(configuration: config)
        try await addRequiredModelsForComplexTests(database)

        // Create chat with maximum allowed attachments
        let defaultPersonalityId = try await getDefaultPersonalityId(database)
        try await database.write(ChatCommands.Create(personality: defaultPersonalityId))
        let chat = try await database.read(ChatCommands.GetFirst())

        // Add multiple files
        var fileURLs: [URL] = []
        for index in 0..<10 {
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("file\(index).txt")
            try "Content for file \(index)".write(to: fileURL, atomically: true, encoding: .utf8)
            fileURLs.append(fileURL)

            try await database.write(FileCommands.Create(
                fileURL: fileURL,
                chatId: chat.id,
                database: database
            ))
        }

        // Try concurrent operations
        let id = chat.id
        await withThrowingTaskGroup(of: Void.self) { group in
            // Add messages concurrently
            for index in 0..<5 {
                group.addTask {
                    try await database.writeInBackground(MessageCommands.Create(
                        chatId: id,
                        userInput: "Concurrent message \(index)",
                        isDeepThinker: false
                    ))
                }
            }

            // Try to rename chat concurrently
            for index in 0..<3 {
                group.addTask {
                    try await database.writeInBackground(ChatCommands.Rename(
                        chatId: id,
                        newName: "New name \(index)"
                    ))
                }
            }
        }

        // Verify final state
        let messages = try await database.read(MessageCommands.GetAll(chatId: chat.id))
        #expect(messages.count == 5)

        let hasAttachments = try await database.read(ChatCommands.HasAttachments(chatId: chat.id))
        #expect(hasAttachments == true)

        // Test error cases
        // Try to add file to nonexistent chat
        let invalidFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("invalid.txt")
        try "Invalid content".write(to: invalidFileURL, atomically: true, encoding: .utf8)

        await #expect(throws: DatabaseError.chatNotFound) {
            try await database.write(FileCommands.Create(
                fileURL: invalidFileURL,
                chatId: UUID(),
                database: database
            ))
        }

        // Cleanup
        for fileURL in fileURLs {
            try? FileManager.default.removeItem(at: fileURL)
        }
        try? FileManager.default.removeItem(at: invalidFileURL)
    }
}

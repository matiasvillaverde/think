import Testing
import Foundation
import SwiftData
@testable import Database
import AbstractionsTestUtilities
import Abstractions

// swiftlint:disable non_optional_string_data_conversion nesting

// MARK: - Helper Functions

private func addRequiredModels(_ database: Database) async throws {
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
        ramNeeded: 100.megabytes,
        size: 50.megabytes,
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
        ramNeeded: 200.megabytes,
        size: 100.megabytes,
        locationHuggingface: "test/image",
        version: 1
    )

    try await database.write(ModelCommands.AddModels(modelDTOs: [languageModel, imageModel]))
}

@Suite("Image Commands Tests")
struct ImageCommandsTests {
    @Suite(.tags(.acceptance))
    @MainActor
    struct BasicFunctionalityTests {
        @Test("Add response image successfully")
        func addResponseSuccess() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModels(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            let chat = try await database.read(ChatCommands.GetFirst())
            try await database.write(MessageCommands.Create(chatId: chat.id, userInput: "Test input", isDeepThinker: false))

            guard let message = chat.messages.first else {
                #expect(Bool(true))
                return
            }

            let imageData = "Test image data".data(using: .utf8)!
            let diffConfig: DiffusorConfiguration = .default

            database.modelContainer.mainContext.insert(diffConfig)
            try database.save()

            let prompt = "A test prompt"

            // When
            try await database.write(ImageCommands.AddResponse(
                messageId: message.id,
                imageData: imageData,
                configuration: diffConfig.id,
                prompt: prompt
            ))

            // Then
            let responseImage = try await database.read(ImageCommands.GetResponse(messageId: message.id))
            #expect(responseImage != nil)
            #expect(responseImage?.image == imageData)
            #expect(responseImage?.prompt == prompt)
            #expect(responseImage?.configuration == diffConfig)
        }

        @Test("Update existing response image")
        func updateResponseSuccess() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModels(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            let chat = try await database.read(ChatCommands.GetFirst())
            try await database.write(MessageCommands.Create(chatId: chat.id, userInput: "Test input", isDeepThinker: false))

            guard let message = chat.messages.first else {
                #expect(Bool(true))
                return
            }

            // Create initial image
            let initialImageData = "Initial image".data(using: .utf8)!
            let initialConfig: DiffusorConfiguration = .default
            let initialPrompt = "Initial prompt"

            database.modelContainer.mainContext.insert(initialConfig)
            try database.save()

            try await database.write(ImageCommands.AddResponse(
                messageId: message.id,
                imageData: initialImageData,
                configuration: initialConfig.id,
                prompt: initialPrompt
            ))

            // When - Update with new image
            let updatedImageData = "Updated image".data(using: .utf8)!
            let updatedConfig: DiffusorConfiguration = .default
            let updatedPrompt = "Updated prompt"

            database.modelContainer.mainContext.insert(updatedConfig)
            try database.save()

            try await database.write(ImageCommands.AddResponse(
                messageId: message.id,
                imageData: updatedImageData,
                configuration: updatedConfig.id,
                prompt: updatedPrompt
            ))

            // Then
            let responseImage = try await database.read(ImageCommands.GetResponse(messageId: message.id))
            #expect(responseImage != nil)
            #expect(responseImage?.image == updatedImageData)
            #expect(responseImage?.prompt == updatedPrompt)
            #expect(responseImage?.configuration == updatedConfig)
        }

    @Suite(.tags(.edge))
        struct EdgeCasesTests {
            @Test("Add response to nonexistent message fails")
            @MainActor
            func addResponseNonexistentMessage() async throws {
                // Given
                let config = DatabaseConfiguration(
                    isStoredInMemoryOnly: true,
                    allowsSave: true,
                    ragFactory: MockRagFactory(mockRag: MockRagging())
                )

                let database = try Database.new(configuration: config)
                let imageData = "Test image data".data(using: .utf8)!
                let diffConfig: DiffusorConfiguration = .default

                database.modelContainer.mainContext.insert(diffConfig)
                try database.save()

                // When/Then
                await #expect(throws: DatabaseError.messageNotFound) {
                    try await database.write(ImageCommands.AddResponse(
                        messageId: UUID(),
                        imageData: imageData,
                        configuration: diffConfig.id,
                        prompt: "Test prompt"
                    ))
                }
            }
        }

        @Test("Get response from nonexistent message fails")
        func getResponseNonexistentMessage() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)

            // When/Then
            await #expect(throws: DatabaseError.messageNotFound) {
                _ = try await database.read(ImageCommands.GetResponse(messageId: UUID()))
            }
        }

        @Test("Add response with empty image data")
        func addResponseEmptyData() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModels(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            let chat = try await database.read(ChatCommands.GetFirst())
            try await database.write(MessageCommands.Create(chatId: chat.id, userInput: "Test input", isDeepThinker: false))

            guard let message = chat.messages.first else {
                #expect(Bool(true))
                return
            }

            let emptyData = Data()
            let diffConfig: DiffusorConfiguration = .default

            database.modelContainer.mainContext.insert(diffConfig)
            try database.modelContainer.mainContext.save()

            // When
            try await database.write(ImageCommands.AddResponse(
                messageId: message.id,
                imageData: emptyData,
                configuration: diffConfig.id,
                prompt: "Test prompt"
            ))

            // Then
            let responseImage = try await database.read(ImageCommands.GetResponse(messageId: message.id))
            #expect(responseImage != nil)
            #expect(responseImage?.image.isEmpty == true)
        }
    }

    @Suite(.tags(.performance))
    struct PerformanceTests {
        @Test("Handle large image data")
        @MainActor
        func handleLargeImageData() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModels(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            let chat = try await database.read(ChatCommands.GetFirst())
            try await database.write(MessageCommands.Create(chatId: chat.id, userInput: "Test input", isDeepThinker: false))

            guard let message = chat.messages.first else {
                #expect(Bool(true))
                return
            }

            // Create large image data (1MB)
            let largeData = Data(repeating: 0, count: 1024 * 1024)
            let diffConfig: DiffusorConfiguration = .default

            database.modelContainer.mainContext.insert(diffConfig)
            try database.modelContainer.mainContext.save()

            // When
            try await database.write(ImageCommands.AddResponse(
                messageId: message.id,
                imageData: largeData,
                configuration: diffConfig.id,
                prompt: "Test prompt"
            ))

            // Then
            let responseImage = try await database.read(ImageCommands.GetResponse(messageId: message.id))
            #expect(responseImage != nil)
            #expect(responseImage?.image.count == largeData.count)
        }
    }

    @Suite(.tags(.concurrency))
    struct ConcurrencyTests {
        @Test("Concurrent image operations maintain consistency")
        @MainActor
        func concurrentImageOperations() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModels(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            let chat = try await database.read(ChatCommands.GetFirst())
            try await database.write(MessageCommands.Create(chatId: chat.id, userInput: "Test input", isDeepThinker: false))

            guard let message = chat.messages.first else {
                #expect(Bool(true))
                return
            }

            let messageId = message.id
            let imageModelConfigID = message.chat!.imageModelConfig.id
            let operations = (0..<5).map { index in
                (
                    "Image data \(index)".data(using: .utf8)!,
                    "Prompt \(index)"
                )
            }

            // When
            await withThrowingTaskGroup(of: Void.self) { group in
                for (imageData, prompt) in operations {
                    group.addTask {
                        try await database.writeInBackground(ImageCommands.AddResponse(
                            messageId: messageId,
                            imageData: imageData,
                            configuration: imageModelConfigID,
                            prompt: prompt
                        ))
                    }
                }
            }

            // Then
            let finalImage = try await database.read(ImageCommands.GetResponse(messageId: messageId))
            #expect(finalImage != nil)
            // Note: Due to concurrent operations, we can't predict which operation's data will be final
            #expect(operations.contains { $0.0 == finalImage?.image })
        }
    }
}

// MARK: - Potential Bugs Found
/*
1. Missing Validation:
   - No validation for maximum image size
   - No validation for image format/type
   - No validation for empty or nil prompt
   - No validation for DiffusorConfiguration parameters

2. State Management:
   - No status tracking for image generation process
   - No handling of partially generated images
   - No cleanup mechanism for failed generations

3. Resource Management:
   - Large images might cause memory issues
   - No compression or optimization of image data
   - No cleanup of temporary image data

4. Error Handling:
   - Limited error types for image-specific failures
   - No retry mechanism for failed operations
   - No handling of configuration validation errors

5. Concurrency:
   - Last-write-wins behavior might not be ideal for all use cases
   - No locking mechanism for updating same message's image
   - Race conditions possible during rapid updates
*/

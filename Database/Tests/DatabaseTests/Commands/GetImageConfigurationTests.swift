import Testing
import Foundation
import SwiftData
@testable import Database
import AbstractionsTestUtilities
import Abstractions

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

    try await database.write(ModelCommands.AddModels(models: [languageModel, imageModel]))
}

extension ImageCommandsTests {
    @Suite(.tags(.acceptance))
    @MainActor
    struct GetImageConfigurationTests {
        @Test("Get image configuration successfully")
        func getImageConfigurationSuccess() async throws {
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

            // Custom DiffusorConfiguration for testing
            let diffConfig = DiffusorConfiguration(
                negativePrompt: "Test negative prompt",
                steps: 30,
                seed: 12345,
                cfgWeight: 8.0,
                imageCount: 2,
                decodingBatchSize: 2,
                latentSize: [128, 128]
            )

            // Replace default configuration with custom one
            chat.imageModelConfig = diffConfig
            database.modelContainer.mainContext.insert(diffConfig)
            try database.save()

            let prompt = "A test prompt"
            let negativePrompt = "Additional negative prompt"

            // When
            let imageConfig = try await database.read(ImageCommands.GetImageConfiguration(
                chat: chat.id,
                prompt: prompt,
                negativePrompt: negativePrompt
            ))

            // Then
            #expect(imageConfig.id == diffConfig.id)
            #expect(imageConfig.prompt == prompt)
            #expect(imageConfig.negativePrompt == negativePrompt)
            #expect(imageConfig.steps == 30)
            #expect(imageConfig.seed == 12345)
            #expect(imageConfig.cfgWeight == 8.0)
            #expect(imageConfig.imageCount == 2)
            #expect(imageConfig.decodingBatchSize == 2)
            #expect(imageConfig.latentSize == [128, 128])
        }

        @Test("Get image configuration with default negative prompt")
        func getImageConfigDefaultNegativePrompt() async throws {
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
            let diffConfig = chat.imageModelConfig
            let prompt = "A test prompt"

            // When - not providing a negative prompt
            let imageConfig = try await database.read(ImageCommands.GetImageConfiguration(
                chat: chat.id,
                prompt: prompt
            ))

            // Then - should use default negative prompt from DiffusorConfiguration
            #expect(imageConfig.prompt == prompt)
            #expect(imageConfig.negativePrompt == diffConfig.negativePrompt)
        }
    }

    @Suite(.tags(.edge))
    struct GetImageConfigurationEdgeCasesTests {
        @Test("Get image configuration for nonexistent chat throws error")
        @MainActor
        func getImageConfigNonexistentChat() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            let nonexistentChatId = UUID()

            // When/Then
            await #expect(throws: DatabaseError.configurationNotFound) {
                _ = try await database.read(ImageCommands.GetImageConfiguration(
                    chat: nonexistentChatId,
                    prompt: "Test prompt"
                ))
            }
        }

        @Test("Get image configuration with empty prompt")
        @MainActor
        func getImageConfigEmptyPrompt() async throws {
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
            let emptyPrompt = ""

            // When
            let imageConfig = try await database.read(ImageCommands.GetImageConfiguration(
                chat: chat.id,
                prompt: emptyPrompt
            ))

            // Then - should still work with empty prompt
            #expect(imageConfig.prompt == emptyPrompt)
        }
    }

    @Suite(.tags(.performance))
    struct GetImageConfigurationPerformanceTests {
        @Test("Get image configuration with very long prompts")
        @MainActor
        func getImageConfigLongPrompts() async throws {
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

            // Create very long prompt (10KB)
            let longPrompt = String(repeating: "This is a test prompt. ", count: 500)
            let longNegativePrompt = String(repeating: "This is a negative prompt. ", count: 500)

            // When
            let imageConfig = try await database.read(ImageCommands.GetImageConfiguration(
                chat: chat.id,
                prompt: longPrompt,
                negativePrompt: longNegativePrompt
            ))

            // Then
            #expect(imageConfig.prompt == longPrompt)
            #expect(imageConfig.negativePrompt == longNegativePrompt)
        }
    }

    @Suite(.tags(.concurrency))
    struct GetImageConfigurationConcurrencyTests {
        @Test("Concurrent image configuration retrieval")
        @MainActor
        func concurrentImageConfigRetrieval() async throws {
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
            let chatId = chat.id

            // Create multiple prompts for concurrent testing
            let prompts = (0..<10).map { "Test prompt \($0)" }

            // When - retrieve configurations concurrently
            var results = [ImageConfiguration]()

            try await withThrowingTaskGroup(of: ImageConfiguration.self) { group in
                for prompt in prompts {
                    group.addTask {
                        try await database.readInBackground(ImageCommands.GetImageConfiguration(
                            chat: chatId,
                            prompt: prompt
                        ))
                    }
                }

                for try await result in group {
                    results.append(result)
                }
            }

            // Then
            #expect(results.count == prompts.count)

            // Verify all returned configurations have correct prompts
            let returnedPrompts = results.map { $0.prompt }
            for prompt in prompts {
                #expect(returnedPrompts.contains(prompt))
            }
        }
    }
}

// MARK: - Potential Bugs Found
/*
1. Missing Validation:
   - No validation for maximum prompt length
   - No validation for empty chat id
   - No validation for malformed prompts

2. Performance Issues:
   - Very long prompts might impact performance
   - No caching mechanism for frequently accessed configurations

3. Error Handling:
   - Throws configurationNotFound for chat not found, but could be more specific
   - Error message might not provide enough context about what configuration wasn't found

4. Concurrency:
   - No explicit synchronization for concurrent access to the same chat's configuration
   - Potential race conditions if chat configurations are updated concurrently

5. Resource Management:
   - No memory optimization for large prompts
*/

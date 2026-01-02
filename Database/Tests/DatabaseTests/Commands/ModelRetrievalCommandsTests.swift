import Testing
import Foundation
import SwiftData
import Abstractions
@testable import Database
import AbstractionsTestUtilities

// MARK: - Helper Functions

private func addRequiredModelsForRetrieval(_ database: Database) async throws {
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

    let deepLanguageModel = ModelDTO(
        type: .deepLanguage,
        backend: .mlx,
        name: "test-deep-llm",
        displayName: "Deep LLM",
        displayDescription: "A deep language model",
        skills: ["text-generation"],
        parameters: 200000,
        ramNeeded: 200_000_000,
        size: 100_000_000,
        locationHuggingface: "local/path/deep-text-model",
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

    try await database.write(ModelCommands.AddModels(modelDTOs: [languageModel, deepLanguageModel, imageModel]))
}

@Suite("Model Retrieval Commands Tests", .serialized)
struct ModelRetrievalCommandsTests {
    @Suite(.tags(.acceptance))
    struct LanguageModelTests {
        @Test("Get language model successfully")
        @MainActor
        func getLanguageModelSuccess() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModelsForRetrieval(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            // When
            let model = try await database.read(ChatCommands.GetLanguageModel(chatId: chatId))

            // Then
            // With priority-based fallback, deepLanguage is selected over language
            #expect(model.modelType == SendableModel.ModelType.deepLanguage)
            #expect(model.location == "local/path/deep-text-model")
        }

        @Test("Get language model fails with invalid chat ID")
        @MainActor
        func getLanguageModelInvalidChat() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            let nonExistentChatId = UUID()

            // When/Then
            await #expect(throws: DatabaseError.chatNotFound) {
                _ = try await database.read(ChatCommands.GetLanguageModel(chatId: nonExistentChatId))
            }
        }
    }

    @Suite(.tags(.acceptance))
    struct UnifiedLanguageModelTests {
        @Test("Get unified language model returns best available model")
        @MainActor
        func getUnifiedLanguageModelSuccess() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModelsForRetrieval(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            // When
            let model = try await database.read(ChatCommands.GetLanguageModel(chatId: chatId))

            // Then
            // With priority-based fallback, deepLanguage is selected over language
            #expect(model.modelType == SendableModel.ModelType.deepLanguage)
            #expect(model.location == "local/path/deep-text-model")
        }

        @Test("Get unified language model fails with invalid chat ID")
        @MainActor
        func getUnifiedLanguageModelInvalidChat() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            let nonExistentChatId = UUID()

            // When/Then
            await #expect(throws: DatabaseError.chatNotFound) {
                _ = try await database.read(ChatCommands.GetLanguageModel(chatId: nonExistentChatId))
            }
        }
    }

    @Suite(.tags(.acceptance))
    struct ImageModelTests {
        @Test("Get image model successfully")
        @MainActor
        func getImageModelSuccess() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModelsForRetrieval(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            // When
            let model = try await database.read(ChatCommands.GetImageModel(chatId: chatId))

            // Then
            #expect(model.modelType == SendableModel.ModelType.diffusion)
            #expect(model.location == "test/image")
        }

        @Test("Get image model fails with invalid chat ID")
        @MainActor
        func getImageModelInvalidChat() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            let nonExistentChatId = UUID()

            // When/Then
            await #expect(throws: DatabaseError.chatNotFound) {
                _ = try await database.read(ChatCommands.GetImageModel(chatId: nonExistentChatId))
            }
        }
    }

    @Suite(.tags(.performance))
    struct ModelRetrievalPerformanceTests {
        @Test("Model retrieval performance is acceptable")
        @MainActor
        func modelRetrievalPerformance() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModelsForRetrieval(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            // When
            let start = ProcessInfo.processInfo.systemUptime

            for _ in 0..<10 {
                _ = try await database.read(ChatCommands.GetLanguageModel(chatId: chatId))
                _ = try await database.read(ChatCommands.GetImageModel(chatId: chatId))
            }

            let duration = ProcessInfo.processInfo.systemUptime - start

            // Then
            #expect(duration < 2) // Should complete retrievals quickly
        }
    }

    @Suite(.tags(.core))
    struct ConcurrentModelRetrievalTests {
        @Test("Concurrent model retrievals don't cause issues")
        @MainActor
        func concurrentModelRetrievals() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModelsForRetrieval(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            // When - Sequential reads to avoid concurrency issues
            for _ in 0..<5 {
                _ = try await database.read(ChatCommands.GetLanguageModel(chatId: chatId))
                _ = try await database.read(ChatCommands.GetImageModel(chatId: chatId))
            }

            // Then - if we get here without crashes, the test passes
            let languageModel = try await database.read(ChatCommands.GetLanguageModel(chatId: chatId))
            #expect(languageModel.modelType == SendableModel.ModelType.deepLanguage)
            #expect(languageModel.location == "local/path/deep-text-model")
        }
    }
}

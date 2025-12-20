import Testing
import Foundation
import SwiftData
import Abstractions
@testable import Database
import AbstractionsTestUtilities

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

@Suite("HaveSameModels Tests")
struct HaveSameModelsTests {
    @Suite(.tags(.acceptance))
    struct BasicFunctionalityTests {
        @Test("Two newly created chats should have same models")
        func sameModelsForNewChats() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModels(database)

            // When
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            let chatId1 = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))
            let chatId2 = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            // Then
            let haveSameModels = try await database.read(ChatCommands.HaveSameModels(chatId1: chatId1, chatId2: chatId2))
            #expect(haveSameModels == true)
        }
    }

    @Suite(.tags(.edge))
    struct EdgeCaseTests {
        @Test("Comparing with nonexistent chat should throw error")
        func nonexistentChat() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModels(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            // When/Then
            await #expect(throws: DatabaseError.chatNotFound) {
                _ = try await database.read(ChatCommands.HaveSameModels(chatId1: chatId, chatId2: UUID()))
            }
        }

        @Test("Comparing chat with itself should return true")
        func compareChatWithItself() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModels(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            // When
            let haveSameModels = try await database.read(ChatCommands.HaveSameModels(chatId1: chatId, chatId2: chatId))

            // Then
            #expect(haveSameModels == true)
        }
    }

    @Suite(.tags(.core))
    struct ModelDifferenceTests {
        @Test("Chats with different models should return false")
        @MainActor
        func differentModelsTest() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)

            // Add initial set of models
            try await addRequiredModels(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            let chatId1 = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            // Add different models for second chat
            try await addAlternativeModels(database)

            // Create a new chat with the same user
            let chatId2 = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            // Get all available models to assign different ones to chat2
            let alternativeLanguageModel = try await database.read(ModelCommands.GetModel(name: "alternative-text-model"))

            // Modify chat2 to use different models
            try await database.write(ChatCommands.ModifyChatModelsCommand(
                chatId: chatId2,
                newLanguageModelId: alternativeLanguageModel.id,
                newImageModelId: nil
            ))

            // When
            let haveSameModels = try await database.read(ChatCommands.HaveSameModels(chatId1: chatId1, chatId2: chatId2))

            // Then
            #expect(haveSameModels == false)
        }
    }

    @Suite(.tags(.performance))
    struct PerformanceTests {
        @Test("HaveSameModels performance is acceptable")
        func performanceTest() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try await Database.new(configuration: config)
            try await addRequiredModels(database)

            // Create a lot of chats
            var chatIds: [UUID] = []
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            for _ in 0..<10 {
                let id = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))
                chatIds.append(id)
            }

            // When
            let start = ProcessInfo.processInfo.systemUptime
            for index in 0..<chatIds.count-1 {
                for secondIndex in index+1..<chatIds.count {
                    _ = try await database.read(ChatCommands.HaveSameModels(chatId1: chatIds[index], chatId2: chatIds[secondIndex]))
                }
            }
            let duration = ProcessInfo.processInfo.systemUptime - start

            // Then
            #expect(duration < 1.0) // Should complete within 1 second
        }
    }
}

// MARK: - Helper Functions

// Add alternative models for testing differences
func addAlternativeModels(_ database: Database) async throws {
    let alternativeTextModel = ModelDTO(
        type: .language,
        backend: .mlx,
        name: "alternative-text-model",
        displayName: "Alternative Text Model",
        displayDescription: "An alternative text generation model",
        skills: ["text generation"],
        parameters: 7_000_000_000,
        ramNeeded: 8_000_000_000,
        size: 4_000_000_000,
        locationHuggingface: "local/path/alternative-text-model",
        version: 2,
        architecture: .unknown
    )

    let alternativeDeepTextModel = ModelDTO(
        type: .deepLanguage,
        backend: .mlx,
        name: "alternative-deep-text-model",
        displayName: "Alternative Deep Text Model",
        displayDescription: "An alternative deep text generation model",
        skills: ["reason"],
        parameters: 8_000_000_000,
        ramNeeded: 10_000_000_000,
        size: 5_000_000_000,
        locationHuggingface: "local/path/alternative-deep-text-model",
        version: 2,
        architecture: .unknown
    )

    let alternativeDiffusionModel = ModelDTO(
        type: .diffusion,
        backend: .mlx,
        name: "alternative-diffusion-model",
        displayName: "Alternative Diffusion Model",
        displayDescription: "An alternative image diffusion model",
        skills: ["image generation"],
        parameters: 3_000_000_000,
        ramNeeded: 7_000_000_000,
        size: 4_000_000_000,
        locationHuggingface: "local/path/alternative-diffusion-model",
        version: 2,
        architecture: .unknown
    )

    try await database.writeInBackground(
        ModelCommands.AddModels(
            models: [alternativeTextModel, alternativeDiffusionModel, alternativeDeepTextModel]
        )
    )
}

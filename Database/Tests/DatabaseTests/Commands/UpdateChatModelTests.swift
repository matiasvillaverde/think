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

@Suite("UpdateChatModel Command Tests")
struct UpdateChatModelTests {
    @Suite(.tags(.acceptance))
    struct AcceptanceTests {
        @Test("Update language model successfully")
        @MainActor
        func updateLanguageModelSuccess() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)

            // Setup required models
            try await addRequiredModels(database)

            // Create a chat
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            // Create a new language model
            let newModelId = try await addNewLanguageModel(database)

            // When
            try await database.write(ChatCommands.UpdateChatModel(chatId: chatId, modelId: newModelId))

            // Then
            let chat = try await database.read(ChatCommands.Read(chatId: chatId))
            #expect(chat.languageModel.id == newModelId)
        }

        @Test("Update deep language model successfully")
        @MainActor
        func updateDeepLanguageModelSuccess() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)

            // Setup required models
            try await addRequiredModels(database)

            // Create a chat
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            // Create a new deep language model
            let newModelId = try await addNewDeepLanguageModel(database)

            // When
            try await database.write(ChatCommands.UpdateChatModel(chatId: chatId, modelId: newModelId))

            // Then
            let chat = try await database.read(ChatCommands.Read(chatId: chatId))
            #expect(chat.languageModel.id == newModelId)
        }

        @Test("Update image model successfully")
        @MainActor
        func updateImageModelSuccess() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)

            // Setup required models
            try await addRequiredModels(database)

            // Create a chat
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            // Create a new diffusion model
            let newModelId = try await addNewDiffusionModel(database)

            // When
            try await database.write(ChatCommands.UpdateChatModel(chatId: chatId, modelId: newModelId))

            // Then
            let chat = try await database.read(ChatCommands.Read(chatId: chatId))
            #expect(chat.imageModel.id == newModelId)
        }

        @Test("Update with visual language model modifies language model")
        @MainActor
        func updateWithVisualLanguageModelSuccess() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)

            // Setup required models
            try await addRequiredModels(database)

            // Create a chat
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            // Create a new visual language model
            let newModelId = try await addNewVisualLanguageModel(database)

            // When
            try await database.write(ChatCommands.UpdateChatModel(chatId: chatId, modelId: newModelId))

            // Then
            let chat = try await database.read(ChatCommands.Read(chatId: chatId))
            #expect(chat.languageModel.id == newModelId)
        }
    }

    @Suite(.tags(.edge))
    struct EdgeCasesTests {
        @Test("Update with nonexistent chat fails")
        func updateNonexistentChatFails() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)

            // When/Then
            await #expect(throws: DatabaseError.chatNotFound) {
                try await database.write(ChatCommands.UpdateChatModel(
                    chatId: UUID(),
                    modelId: UUID()
                ))
            }
        }

        @Test("Update with nonexistent model fails")
        @MainActor
        func updateNonexistentModelFails() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModels(database)

            // Create a chat
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            // When/Then
            await #expect(throws: DatabaseError.modelNotFound) {
                try await database.write(ChatCommands.UpdateChatModel(
                    chatId: chatId,
                    modelId: UUID()
                ))
            }
        }
    }
}

// MARK: - Helper functions for tests

/// Adds a new language model to the database and returns its ID
@MainActor
func addNewLanguageModel(_ database: Database) async throws -> UUID {
    let newLanguageModel = ModelDTO(
        type: .language,
        backend: .mlx,
        name: "new-language-model",
        displayName: "New Language Model",
        displayDescription: "A new language model for testing",
        skills: ["text generation"],
        parameters: 13_000_000_000,
        ramNeeded: 16_000_000_000,
        size: 8_000_000_000,
        locationHuggingface: "local/path/new-language-model",
        version: 2,
        architecture: .unknown
    )

    try await database.writeInBackground(
        ModelCommands.AddModels(models: [newLanguageModel])
    )

    // Fetch the created model to get its ID
    let model = try await database.read(ModelCommands.GetModel(name: "new-language-model"))
    return model.id
}

/// Adds a new deep language model to the database and returns its ID
@MainActor
func addNewDeepLanguageModel(_ database: Database) async throws -> UUID {
    let newDeepLanguageModel = ModelDTO(
        type: .deepLanguage,
        backend: .mlx,
        name: "new-deep-language-model",
        displayName: "New Deep Language Model",
        displayDescription: "A new deep language model for testing",
        skills: ["reason"],
        parameters: 70_000_000_000,
        ramNeeded: 32_000_000_000,
        size: 16_000_000_000,
        locationHuggingface: "local/path/new-deep-language-model",
        version: 2,
        architecture: .unknown
    )

    try await database.write(
        ModelCommands.AddModels(models: [newDeepLanguageModel])
    )

    // Fetch the created model to get its ID
    let model = try await database.read(ModelCommands.GetModel(name: "new-deep-language-model"))
    return model.id
}

/// Adds a new diffusion model to the database and returns its ID
@MainActor
func addNewDiffusionModel(_ database: Database) async throws -> UUID {
    let newDiffusionModel = ModelDTO(
        type: .diffusion,
        backend: .mlx,
        name: "new-diffusion-model",
        displayName: "New Diffusion Model",
        displayDescription: "A new diffusion model for testing",
        skills: ["image generation"],
        parameters: 4_000_000_000,
        ramNeeded: 12_000_000_000,
        size: 6_000_000_000,
        locationHuggingface: "local/path/new-diffusion-model",
        version: 2,
        architecture: .unknown
    )

    try await database.write(
        ModelCommands.AddModels(models: [newDiffusionModel])
    )

    // Fetch the created model to get its ID
    let model = try await database.read(ModelCommands.GetModel(name: "new-diffusion-model"))
    return model.id
}

/// Adds a new visual language model to the database and returns its ID
@MainActor
func addNewVisualLanguageModel(_ database: Database) async throws -> UUID {
    let newVisualLanguageModel = ModelDTO(
        type: .visualLanguage,
        backend: .mlx,
        name: "new-visual-language-model",
        displayName: "New Visual Language Model",
        displayDescription: "A new visual language model for testing",
        skills: ["visual reasoning"],
        parameters: 20_000_000_000,
        ramNeeded: 24_000_000_000,
        size: 12_000_000_000,
        locationHuggingface: "local/path/new-visual-language-model",
        version: 2,
        architecture: .unknown
    )

    try await database.write(
        ModelCommands.AddModels(models: [newVisualLanguageModel])
    )

    // Fetch the created model to get its ID
    let model = try await database.read(ModelCommands.GetModel(name: "new-visual-language-model"))
    return model.id
}

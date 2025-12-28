import Testing
import Foundation
import SwiftData
import Abstractions
@testable import Database
import AbstractionsTestUtilities

// Use the common helper function from ChatCommandsTestHelpers that includes deepLanguage model

@Suite("Unified Language Model Tests")
struct UnifiedLanguageModelTests {
    @Suite(.tags(.acceptance))
    struct ThinkingCapabilityTests {
        @Test("Language model cannot think")
        @MainActor
        func languageModelCannotThink() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addLanguageOnlyModel(database)
            try await database.write(PersonalityCommands.WriteDefault())
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            // When
            let model = try await database.read(ChatCommands.GetLanguageModel(chatId: chatId))

            // Then
            #expect(model.modelType == SendableModel.ModelType.language)
            #expect(model.modelType != SendableModel.ModelType.deepLanguage)
            #expect(model.modelType != SendableModel.ModelType.flexibleThinker)
        }

        @Test("DeepLanguage model always thinks")
        @MainActor
        func deepLanguageModelAlwaysThinks() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addDeepLanguageOnlyModel(database)
            try await database.write(PersonalityCommands.WriteDefault())
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            // When
            let model = try await database.read(ChatCommands.GetLanguageModel(chatId: chatId))

            // Then
            #expect(model.modelType == SendableModel.ModelType.deepLanguage)
            #expect(model.modelType != SendableModel.ModelType.language)
            #expect(model.modelType != SendableModel.ModelType.flexibleThinker)
        }

        @Test("FlexibleThinker model can optionally think")
        @MainActor
        func flexibleThinkerModelCanOptionallyThink() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addFlexibleThinkerOnlyModel(database)
            try await database.write(PersonalityCommands.WriteDefault())
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            // When
            let model = try await database.read(ChatCommands.GetLanguageModel(chatId: chatId))

            // Then
            #expect(model.modelType == SendableModel.ModelType.flexibleThinker)
            #expect(model.modelType != SendableModel.ModelType.language)
            #expect(model.modelType != SendableModel.ModelType.deepLanguage)
        }

        @Test("Unified model selection prioritizes capabilities correctly")
        @MainActor
        func unifiedModelSelectionPrioritizesCapabilities() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addAllLanguageModelTypes(database)
            try await database.write(PersonalityCommands.WriteDefault())
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            // When
            let model = try await database.read(ChatCommands.GetLanguageModel(chatId: chatId))

            // Then
            // With priority-based fallback, flexibleThinker has highest priority
            #expect(model.modelType == SendableModel.ModelType.flexibleThinker)
            #expect(model.location == "local/path/flexible-thinker-model")
        }
    }

    @Suite(.tags(.integration))
    struct ChatModelIntegrationTests {
        @Test("Chat uses single language model for all language tasks")
        @MainActor
        func chatUsesSingleLanguageModel() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModelsForChatCommands(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            // When
            let chat = try await database.read(ChatCommands.Read(chatId: chatId))
            let languageModel = try await database.read(ChatCommands.GetLanguageModel(chatId: chatId))

            // Then
            #expect(chat.languageModel.id == languageModel.id)
            #expect(chat.languageModel.type == SendableModel.ModelType.deepLanguage) // Uses priority-based selection
        }

        @Test("Chat model update works with unified approach")
        @MainActor
        func chatModelUpdateWorks() async throws {
            // Given
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )

            let database = try Database.new(configuration: config)
            try await addRequiredModelsForChatCommands(database)
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            let chatId = try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

            // Add a new language model
            let newModelId = try await addNewLanguageModel(database)

            // When
            try await database.write(ChatCommands.UpdateChatModel(chatId: chatId, modelId: newModelId))

            // Then
            let chat = try await database.read(ChatCommands.Read(chatId: chatId))
            let languageModel = try await database.read(ChatCommands.GetLanguageModel(chatId: chatId))
            #expect(chat.languageModel.id == newModelId)
            #expect(languageModel.id == newModelId)
        }
    }
}

// MARK: - Helper Functions

private func addLanguageOnlyModel(_ database: Database) async throws {
    let languageModel = ModelDTO(
        type: .language,
        backend: .mlx,
        name: "test-language-only-model",
        displayName: "Test Language Only Model",
        displayDescription: "A test language model that cannot think",
        skills: ["text generation"],
        parameters: 7_000_000_000,
        ramNeeded: 8_000_000_000,
        size: 4_000_000_000,
        locationHuggingface: "local/path/language-only-model",
        version: 2,
        architecture: .unknown
    )

    let diffusionModel = ModelDTO(
        type: .diffusion,
        backend: .mlx,
        name: "test-diffusion-model",
        displayName: "Test Diffusion Model",
        displayDescription: "A test diffusion model",
        skills: ["image generation"],
        parameters: 2_000_000_000,
        ramNeeded: 6_000_000_000,
        size: 3_000_000_000,
        locationHuggingface: "local/path/diffusion-model",
        version: 2,
        architecture: .unknown
    )

    try await database.writeInBackground(
        ModelCommands.AddModels(modelDTOs: [languageModel, diffusionModel])
    )
}

private func addDeepLanguageOnlyModel(_ database: Database) async throws {
    let deepLanguageModel = ModelDTO(
        type: .deepLanguage,
        backend: .mlx,
        name: "test-deep-language-only-model",
        displayName: "Test Deep Language Only Model",
        displayDescription: "A test deep language model that always thinks",
        skills: ["reasoning"],
        parameters: 70_000_000_000,
        ramNeeded: 32_000_000_000,
        size: 16_000_000_000,
        locationHuggingface: "local/path/deep-language-only-model",
        version: 2,
        architecture: .unknown
    )

    let diffusionModel = ModelDTO(
        type: .diffusion,
        backend: .mlx,
        name: "test-diffusion-model",
        displayName: "Test Diffusion Model",
        displayDescription: "A test diffusion model",
        skills: ["image generation"],
        parameters: 2_000_000_000,
        ramNeeded: 6_000_000_000,
        size: 3_000_000_000,
        locationHuggingface: "local/path/diffusion-model",
        version: 2,
        architecture: .unknown
    )

    try await database.writeInBackground(
        ModelCommands.AddModels(modelDTOs: [deepLanguageModel, diffusionModel])
    )
}

private func addFlexibleThinkerOnlyModel(_ database: Database) async throws {
    let flexibleThinkerModel = ModelDTO(
        type: .flexibleThinker,
        backend: .mlx,
        name: "test-flexible-thinker-only-model",
        displayName: "Test Flexible Thinker Only Model",
        displayDescription: "A test flexible thinker model that can optionally think",
        skills: ["text generation", "reasoning"],
        parameters: 13_000_000_000,
        ramNeeded: 16_000_000_000,
        size: 8_000_000_000,
        locationHuggingface: "local/path/flexible-thinker-only-model",
        version: 2,
        architecture: .unknown
    )

    let diffusionModel = ModelDTO(
        type: .diffusion,
        backend: .mlx,
        name: "test-diffusion-model",
        displayName: "Test Diffusion Model",
        displayDescription: "A test diffusion model",
        skills: ["image generation"],
        parameters: 2_000_000_000,
        ramNeeded: 6_000_000_000,
        size: 3_000_000_000,
        locationHuggingface: "local/path/diffusion-model",
        version: 2,
        architecture: .unknown
    )

    try await database.writeInBackground(
        ModelCommands.AddModels(modelDTOs: [flexibleThinkerModel, diffusionModel])
    )
}

private func addAllLanguageModelTypes(_ database: Database) async throws {
    let languageModel = ModelDTO(
        type: .language,
        backend: .mlx,
        name: "test-language-model",
        displayName: "Test Language Model",
        displayDescription: "A test language model",
        skills: ["text generation"],
        parameters: 7_000_000_000,
        ramNeeded: 8_000_000_000,
        size: 4_000_000_000,
        locationHuggingface: "local/path/language-model",
        version: 2,
        architecture: .unknown
    )

    let deepLanguageModel = ModelDTO(
        type: .deepLanguage,
        backend: .mlx,
        name: "test-deep-language-model",
        displayName: "Test Deep Language Model",
        displayDescription: "A test deep language model",
        skills: ["reasoning"],
        parameters: 70_000_000_000,
        ramNeeded: 32_000_000_000,
        size: 16_000_000_000,
        locationHuggingface: "local/path/deep-language-model",
        version: 2,
        architecture: .unknown
    )

    let flexibleThinkerModel = ModelDTO(
        type: .flexibleThinker,
        backend: .mlx,
        name: "test-flexible-thinker-model",
        displayName: "Test Flexible Thinker Model",
        displayDescription: "A test flexible thinker model",
        skills: ["text generation", "reasoning"],
        parameters: 13_000_000_000,
        ramNeeded: 16_000_000_000,
        size: 8_000_000_000,
        locationHuggingface: "local/path/flexible-thinker-model",
        version: 2,
        architecture: .unknown
    )

    let diffusionModel = ModelDTO(
        type: .diffusion,
        backend: .mlx,
        name: "test-diffusion-model",
        displayName: "Test Diffusion Model",
        displayDescription: "A test diffusion model",
        skills: ["image generation"],
        parameters: 2_000_000_000,
        ramNeeded: 6_000_000_000,
        size: 3_000_000_000,
        locationHuggingface: "local/path/diffusion-model",
        version: 2,
        architecture: .unknown
    )

    try await database.writeInBackground(
        ModelCommands.AddModels(
            modelDTOs: [languageModel, deepLanguageModel, flexibleThinkerModel, diffusionModel]
        )
    )
}

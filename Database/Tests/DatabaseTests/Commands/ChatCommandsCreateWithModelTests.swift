import Testing
import Foundation
import SwiftData
import Abstractions
import DataAssets
@testable import Database
import AbstractionsTestUtilities

@Suite("CreateWithModel Command Tests", .tags(.acceptance))
struct ChatCommandsCreateWithModelTests {
    @Test("Creates chat with specific model")
    @MainActor
    func testCreateChatWithModel() async throws {
        // Given: Database with multiple models
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)

        // Create default personality and get its ID
        try await database.write(PersonalityCommands.WriteDefault())
        let defaultPersonalityId = try await database.read(PersonalityCommands.GetDefault())

        // Add multiple models with different capabilities
        let preferredLanguageModel = ModelDTO(
            type: .flexibleThinker,
            backend: .mlx,
            name: "preferred-language-model",
            displayName: "Preferred Language Model",
            displayDescription: "A user-selected language model",
            skills: ["text generation", "reasoning"],
            parameters: 8_000_000_000,
            ramNeeded: 10_000_000_000,
            size: 5_000_000_000,
            locationHuggingface: "local/path/preferred-model",
            version: 2,
            architecture: .unknown
        )

        let alternativeLanguageModel = ModelDTO(
            type: .language,
            backend: .mlx,
            name: "alternative-language-model",
            displayName: "Alternative Language Model",
            displayDescription: "Another language model",
            skills: ["text generation"],
            parameters: 4_000_000_000,
            ramNeeded: 6_000_000_000,
            size: 3_000_000_000,
            locationHuggingface: "local/path/alternative-model",
            version: 2,
            architecture: .unknown
        )

        let imageModel = ModelDTO(
            type: .diffusion,
            backend: .mlx,
            name: "test-image-model",
            displayName: "Test Image Model",
            displayDescription: "An image generation model",
            skills: ["image generation"],
            parameters: 2_000_000_000,
            ramNeeded: 6_000_000_000,
            size: 3_000_000_000,
            locationHuggingface: "local/path/image-model",
            version: 2,
            architecture: .unknown
        )

        try await database.writeInBackground(
            ModelCommands.AddModels(models: [preferredLanguageModel, alternativeLanguageModel, imageModel])
        )

        // Get the model IDs
        let models = try await database.read(ModelCommands.FetchAll())
        let preferredModel = models.first(where: { $0.location == "local/path/preferred-model" })!

        // When: Create chat with specific model
        let chatId = try await database.write(
            ChatCommands.CreateWithModel(
                modelId: preferredModel.id,
                personalityId: defaultPersonalityId
            )
        )

        // Then: Chat is created with the specified model
        let chat = try await database.read(ChatCommands.Read(chatId: chatId))
        #expect(chat.languageModel.id == preferredModel.id)
        #expect(chat.languageModel.name == "preferred-language-model")
    }

    @Test("Fails when model not found")
    @MainActor
    func testCreateChatWithInvalidModel() async throws {
        // Given: Database without the specified model
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)

        // Create default personality and get its ID
        try await database.write(PersonalityCommands.WriteDefault())
        let defaultPersonalityId = try await database.read(PersonalityCommands.GetDefault())

        try await addRequiredModelsForChatCommands(database)

        let nonExistentModelId = UUID()

        // When/Then: Should throw model not found error
        await #expect(throws: DatabaseError.modelNotFound) {
            try await database.write(
                ChatCommands.CreateWithModel(
                    modelId: nonExistentModelId,
                    personalityId: defaultPersonalityId
                )
            )
        }
    }

    @Test("Creates chat with custom personality")
    @MainActor
    func testCreateChatWithCustomPersonality() async throws {
        // Given: Database with models and custom personality
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)

        // Create default personality first
        try await database.write(PersonalityCommands.WriteDefault())

        try await addRequiredModelsForChatCommands(database)

        // Create custom personality using CreateCustom command
        let personalityId = try await database.write(
            PersonalityCommands.CreateCustom(
                name: "Creative Writer",
                description: "A creative writing assistant",
                customSystemInstruction: "You are a creative writing assistant.",
                category: .creative,
                tintColorHex: nil,
                imageName: nil,
                customImage: nil
            )
        )

        // Get a model
        let models = try await database.read(ModelCommands.FetchAll())
        let languageModel = models.first { $0.modelType == .language }!

        // When: Create chat with custom personality
        let chatId = try await database.write(
            ChatCommands.CreateWithModel(
                modelId: languageModel.id,
                personalityId: personalityId
            )
        )

        // Then: Chat uses custom personality
        let chat = try await database.read(ChatCommands.Read(chatId: chatId))
        #expect(chat.personality.id == personalityId)
        #expect(chat.personality.name == "Creative Writer")
    }

    @Test("Automatically selects compatible image model")
    @MainActor
    func testAutoSelectsImageModel() async throws {
        // Given: Database with language and image models
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)

        // Create default personality and get its ID
        try await database.write(PersonalityCommands.WriteDefault())
        let defaultPersonalityId = try await database.read(PersonalityCommands.GetDefault())

        try await addRequiredModelsForChatCommands(database)

        let models = try await database.read(ModelCommands.FetchAll())
        let languageModel = models.first { $0.modelType == .language }!

        // When: Create chat with only language model specified
        let chatId = try await database.write(
            ChatCommands.CreateWithModel(
                modelId: languageModel.id,
                personalityId: defaultPersonalityId
            )
        )

        // Then: Image model is automatically selected
        let chat = try await database.read(ChatCommands.Read(chatId: chatId))
        #expect(chat.imageModel.type == SendableModel.ModelType.diffusion)
        #expect(chat.imageModel.id != languageModel.id)
    }
}

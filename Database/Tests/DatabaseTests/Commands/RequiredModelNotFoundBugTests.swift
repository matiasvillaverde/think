import Testing
import Foundation
import SwiftData
import Abstractions
@testable import Database
import AbstractionsTestUtilities

@Suite("Required Model Not Found Bug Tests")
struct RequiredModelNotFoundBugTests {
    @Test("Chat creation fails when required models are missing")
    @MainActor
    func chatCreationFailsWithMissingModels() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)
        // Initialize default personality first
        try await database.write(PersonalityCommands.WriteDefault())

        // Add only standard language model, but not deep language or image models
        let textGenerationModel = ModelDTO(
            type: .language,
            backend: .mlx,
            name: "test-text-model",
            displayName: "Test Text Model",
            displayDescription: "A test text generation model",
            skills: ["text generation"],
            parameters: 7_000_000_000,
            ramNeeded: 8_000_000_000,
            size: 4_000_000_000,
            locationHuggingface: "local/path/text-model",
            version: 2,
            architecture: .unknown
        )

        try await database.writeInBackground(
            ModelCommands.AddModels(modelDTOs: [textGenerationModel])
        )

        // When/Then - Creating a chat should fail because not all required models are available
        await #expect(throws: DatabaseError.modelNotFound) {
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            try await database.write(ChatCommands.Create(personality: defaultPersonalityId))
        }
    }

    @Test("Chat creation fails with no models")
    @MainActor
    func chatCreationFailsWithNoModels() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)
        // Initialize default personality first
        try await database.write(PersonalityCommands.WriteDefault())

        // Don't add any models at all

        // When/Then - Creating a chat should fail because all required models are missing
        await #expect(throws: DatabaseError.modelNotFound) {
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            try await database.write(ChatCommands.Create(personality: defaultPersonalityId))
        }
    }

    @Test("Chat creation fails with incomplete model types")
    @MainActor
    func chatCreationFailsWithIncompleteModelTypes() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)
        // Initialize default personality first
        try await database.write(PersonalityCommands.WriteDefault())

        // Add standard language and deep language models, but no image model
        let textGenerationModel = ModelDTO(
            type: .language,
            backend: .mlx,
            name: "test-text-model",
            displayName: "Test Text Model",
            displayDescription: "A test text generation model",
            skills: ["text generation"],
            parameters: 7_000_000_000,
            ramNeeded: 8_000_000_000,
            size: 4_000_000_000,
            locationHuggingface: "local/path/text-model",
            version: 2,
            architecture: .unknown
        )

        let deepTextGenerationModel = ModelDTO(
            type: .deepLanguage,
            backend: .mlx,
            name: "test-deep-text-model",
            displayName: "Test Deep Text Model",
            displayDescription: "A test deep text generation model",
            skills: ["reason"],
            parameters: 7_000_000_000,
            ramNeeded: 8_000_000_000,
            size: 4_000_000_000,
            locationHuggingface: "local/path/deep-text-model",
            version: 2,
            architecture: .unknown
        )

        try await database.writeInBackground(
            ModelCommands.AddModels(modelDTOs: [textGenerationModel, deepTextGenerationModel])
        )

        // When/Then - Creating a chat should fail because the image model is missing
        await #expect(throws: DatabaseError.modelNotFound) {
            let defaultPersonalityId = try await getDefaultPersonalityId(database)
            try await database.write(ChatCommands.Create(personality: defaultPersonalityId))
        }
    }
}

@Suite("Production Bug Pattern Tests")
struct ProductionBugPatternTests {
    @Test("Chat creation should work with bundled models but fails")
    @MainActor
    func chatCreationFailsWithBundledModels() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)
        // Initialize default personality first
        try await database.write(PersonalityCommands.WriteDefault())

        // Simulate the production scenario where models with bundle locations exist
        // but they're not being properly detected/used by the app
        let textGenerationModel = ModelDTO(
            type: .language,
            backend: .mlx,
            name: "bundled-text-model",
            displayName: "Bundled Text Model",
            displayDescription: "A bundled text generation model",
            skills: ["text generation"],
            parameters: 1_000_000_000,
            ramNeeded: 500_000_000,
            size: 1_000_000_000,
            // Bundled location exists but will be ignored by current implementation
            locationHuggingface: "bundle://text-model",
            version: 2,
            architecture: .unknown
        )

        let deepTextGenerationModel = ModelDTO(
            type: .deepLanguage,
            backend: .mlx,
            name: "bundled-deep-model",
            displayName: "Bundled Deep Model",
            displayDescription: "A bundled deep model",
            skills: ["reasoning"],
            parameters: 2_000_000_000,
            ramNeeded: 1_000_000_000,
            size: 2_000_000_000,
            // Bundled location exists but will be ignored by current implementation
            locationHuggingface: "bundle://deep-model",
            version: 2,
            architecture: .unknown
        )

        let diffusionModel = ModelDTO(
            type: .diffusion,
            backend: .mlx,
            name: "bundled-diffusion-model",
            displayName: "Bundled Diffusion Model",
            displayDescription: "A bundled image generation model",
            skills: ["image generation"],
            parameters: 1_500_000_000,
            ramNeeded: 800_000_000,
            size: 1_500_000_000,
            // Bundled location exists but will be ignored by current implementation
            locationHuggingface: "bundle://diffusion-model",
            version: 2,
            architecture: .unknown
        )

        // Add all models with bundle locations, but the current implementation
        // doesn't handle these properly in the findRequiredModels() method
        try await database.writeInBackground(
            ModelCommands.AddModels(modelDTOs: [
                textGenerationModel,
                deepTextGenerationModel,
                diffusionModel
            ])
        )

        // When/Then
        // This should succeed since we have all required model types with bundle locations,
        // but the current implementation fails to use them properly
        let defaultPersonalityId = try await getDefaultPersonalityId(database)
        try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

        // We should get here if the chat was created successfully
        let chatCount = try await database.read(ValidateChatCountCommand())
        #expect(chatCount == 1, "A chat should have been created with the bundled models")
    }

    @Test("Chat creation should fall back to remote models when needed")
    @MainActor
    func chatCreationShouldFallBackToRemoteModels() async throws {
        // Given
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)
        // Initialize default personality first
        try await database.write(PersonalityCommands.WriteDefault())

        // Add only remote models (no local/bundle paths)
        let textGenerationModel = ModelDTO(
            type: .language,
            backend: .mlx,
            name: "remote-text-model",
            displayName: "Remote Text Model",
            displayDescription: "A remote text generation model",
            skills: ["text generation"],
            parameters: 7_000_000_000,
            ramNeeded: 1_000_000_000,
            size: 4_000_000_000,
            locationHuggingface: "https://api.example.com/models/text-model",
            version: 2,
            architecture: .unknown
        )

        let deepTextGenerationModel = ModelDTO(
            type: .deepLanguage,
            backend: .mlx,
            name: "remote-deep-model",
            displayName: "Remote Deep Model",
            displayDescription: "A remote deep model",
            skills: ["reasoning"],
            parameters: 70_000_000_000,
            ramNeeded: 8_000_000_000,
            size: 16_000_000_000,
            locationHuggingface: "https://api.example.com/models/deep-model",
            version: 2,
            architecture: .unknown
        )

        let diffusionModel = ModelDTO(
            type: .diffusion,
            backend: .mlx,
            name: "remote-diffusion-model",
            displayName: "Remote Diffusion Model",
            displayDescription: "A remote image generation model",
            skills: ["image generation"],
            parameters: 2_000_000_000,
            ramNeeded: 6_000_000_000,
            size: 3_000_000_000,
            locationHuggingface: "https://api.example.com/models/diffusion-model",
            version: 2,
            architecture: .unknown
        )

        try await database.writeInBackground(
            ModelCommands.AddModels(modelDTOs: [
                textGenerationModel,
                deepTextGenerationModel,
                diffusionModel
            ])
        )

        // When/Then - This should succeed but will fail with the current implementation
        let defaultPersonalityId = try await getDefaultPersonalityId(database)
        try await database.write(ChatCommands.Create(personality: defaultPersonalityId))

        // We should get here if the chat was created successfully
        let chatCount = try await database.read(ValidateChatCountCommand())
        #expect(chatCount == 1, "A chat should have been created with remote models as fallbacks")
    }
}

import Abstractions
import Database
import Foundation

/// Helper utilities for creating test models in the database
public enum TestModelHelpers {
    /// Creates standard test models in the database for testing purposes
    public static func createTestModels(database: DatabaseProtocol) async throws {
        // Create test language model DTO
        let languageModel: ModelDTO = ModelDTO(
            type: .language,
            backend: .mlx,
            name: "test-llm-model",
            displayName: "Test LLM Model",
            displayDescription: "Test language model for unit tests",
            skills: ["text generation", "conversation"],
            parameters: 1_000_000_000,
            ramNeeded: 4_000,
            size: 1_000,
            locationHuggingface: "test/llm-model",
            version: 1,
            architecture: .llama
        )

        // Create test image model DTO
        let imageModel: ModelDTO = ModelDTO(
            type: .diffusion,
            backend: .coreml,
            name: "test-image-model",
            displayName: "Test Image Model",
            displayDescription: "Test image model for unit tests",
            skills: ["image generation"],
            parameters: 500_000_000,
            ramNeeded: 8_000,
            size: 2_000,
            locationHuggingface: "test/image-model",
            version: 2,
            architecture: .unknown
        )

        // Add all models
        try await database.write(ModelCommands.AddModels(modelDTOs: [languageModel, imageModel]))
    }
}

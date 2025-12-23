import Foundation
import SwiftData
import Abstractions
@testable import Database

/// Command to insert default personalities for testing (mirrors AppInitializeCommand behavior)
struct InsertDefaultPersonalitiesCommand: AnonymousCommand {
    typealias Result = Void

    func execute(in context: ModelContext) throws {
        let factoryPersonalities = PersonalityFactory.createSystemPersonalities()
        for personality in factoryPersonalities {
            try PersonalityFactory.insertSystemPersonalitySafely(personality, in: context)
        }
        try context.save()
    }
}

// MARK: - Helper Functions

/// Adds required models for personality commands that create associated chats.
/// This must be called before `PersonalityCommands.CreateCustom` since it auto-creates a chat.
func addRequiredModelsForPersonalityCommands(_ database: Database) async throws {
    // Add language model
    let languageModel = ModelDTO(
        type: .language,
        backend: .mlx,
        name: "test-llm",
        displayName: "Test LLM",
        displayDescription: "A test language model",
        skills: ["text-generation"],
        parameters: 100_000,
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
        parameters: 50_000,
        ramNeeded: 200_000_000,
        size: 100_000_000,
        locationHuggingface: "test/image",
        version: 1
    )

    try await database.write(ModelCommands.AddModels(modelDTOs: [languageModel, imageModel]))
}

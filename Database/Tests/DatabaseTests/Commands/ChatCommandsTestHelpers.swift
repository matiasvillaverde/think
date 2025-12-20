import Testing
import Foundation
import SwiftData
import Abstractions
@testable import Database
import AbstractionsTestUtilities

// MARK: - Helper Commands

struct ValidateChatCountCommand: ReadCommand {
    typealias Result = Int

    func execute(in context: ModelContext, userId: PersistentIdentifier?, rag: (any Ragging)?) throws -> Result {
        let descriptor = FetchDescriptor<Chat>()
        let chats = try context.fetch(descriptor)
        return chats.count
    }
}

// MARK: - Helper Functions

func addRequiredModelsForChatCommands(_ database: Database) async throws {
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

    let deepLanguageModel = ModelDTO(
        type: .deepLanguage,
        backend: .mlx,
        name: "test-deep-llm",
        displayName: "Test Deep LLM",
        displayDescription: "A test deep language model",
        skills: ["text-generation"],
        parameters: 200000,
        ramNeeded: 200.megabytes,
        size: 100.megabytes,
        locationHuggingface: "test/deep-llm",
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

    try await database.write(ModelCommands.AddModels(models: [languageModel, deepLanguageModel, imageModel]))
}

// Helper function to get the default personality ID from the database
func getDefaultPersonalityId(_ database: Database) async throws -> UUID {
    try await database.read(PersonalityCommands.GetDefault())
}

// MARK: - Extensions

extension UInt64 {
    static var megabytes: UInt64 { 1_048_576 }
    static var gigabytes: UInt64 { 1_073_741_824 }
}

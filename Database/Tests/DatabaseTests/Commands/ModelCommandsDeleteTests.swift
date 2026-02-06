import Testing
import Foundation
import Abstractions
@testable import Database

@Suite("Model Commands Delete Tests", .tags(.edge))
struct ModelCommandsDeleteTests {
    @Test("Delete model removes record")
    @MainActor
    func deleteModelRemovesRecord() async throws {
        let database = try ModelCommandsTests.setupTestDatabase()
        let modelId = try await database.write(
            ModelCommands.CreateLocalModel(
                name: "Delete Me",
                backend: .mlx,
                type: .language,
                parameters: 1,
                ramNeeded: 1,
                size: 1,
                architecture: .llama,
                locationLocal: "/tmp/delete-me",
                locationBookmark: nil
            )
        )

        let result = try await database.write(
            ModelCommands.DeleteModel(model: modelId)
        )
        #expect(result == modelId)

        await #expect(throws: DatabaseError.modelNotFound) {
            _ = try await database.read(ModelCommands.GetModelFromId(id: modelId))
        }
    }

    @Test("Delete model fails when in use by a chat")
    @MainActor
    func deleteModelFailsWhenInUse() async throws {
        let database = try ModelCommandsTests.setupTestDatabase()
        _ = try await database.write(
            ModelCommands.CreateLocalModel(
                name: "Lang",
                backend: .mlx,
                type: .language,
                parameters: 1,
                ramNeeded: 1,
                size: 1,
                architecture: .llama,
                locationLocal: "/tmp/lang",
                locationBookmark: nil
            )
        )
        _ = try await database.write(
            ModelCommands.CreateLocalModel(
                name: "Image",
                backend: .mlx,
                type: .diffusion,
                parameters: 1,
                ramNeeded: 1,
                size: 1,
                architecture: .stableDiffusion,
                locationLocal: "/tmp/image",
                locationBookmark: nil
            )
        )

        let personalityId = try await database.write(PersonalityCommands.WriteDefault())
        let chatId = try await database.write(ChatCommands.Create(personality: personalityId))
        let chat = try await database.read(ChatCommands.Read(chatId: chatId))
        let inUseId = chat.languageModel.id

        await #expect(throws: DatabaseError.invalidInput(
            "Model is currently used by 1 chat(s). Update chats before deleting."
        )) {
            _ = try await database.write(ModelCommands.DeleteModel(model: inUseId))
        }
    }

    @Test("Delete model removes fallback references")
    @MainActor
    func deleteModelRemovesFallbackReferences() async throws {
        let database = try ModelCommandsTests.setupTestDatabase()
        let fallbackId = try await database.write(
            ModelCommands.CreateLocalModel(
                name: "Fallback",
                backend: .mlx,
                type: .language,
                parameters: 1,
                ramNeeded: 1,
                size: 1,
                architecture: .llama,
                locationLocal: "/tmp/fallback",
                locationBookmark: nil
            )
        )
        _ = try await database.write(
            ModelCommands.CreateLocalModel(
                name: "Lang",
                backend: .mlx,
                type: .flexibleThinker,
                parameters: 1,
                ramNeeded: 1,
                size: 1,
                architecture: .llama,
                locationLocal: "/tmp/lang",
                locationBookmark: nil
            )
        )
        _ = try await database.write(
            ModelCommands.CreateLocalModel(
                name: "Image",
                backend: .mlx,
                type: .diffusion,
                parameters: 1,
                ramNeeded: 1,
                size: 1,
                architecture: .stableDiffusion,
                locationLocal: "/tmp/image",
                locationBookmark: nil
            )
        )

        let personalityId = try await database.write(PersonalityCommands.WriteDefault())
        let chatId = try await database.write(ChatCommands.Create(personality: personalityId))
        _ = try await database.write(
            ChatCommands.AddFallbackModel(chatId: chatId, modelId: fallbackId)
        )

        let before = try await database.read(ChatCommands.GetFallbackModels(chatId: chatId))
        #expect(before.contains(fallbackId))

        _ = try await database.write(ModelCommands.DeleteModel(model: fallbackId))

        let after = try await database.read(ChatCommands.GetFallbackModels(chatId: chatId))
        #expect(after.contains(fallbackId) == false)
    }
}

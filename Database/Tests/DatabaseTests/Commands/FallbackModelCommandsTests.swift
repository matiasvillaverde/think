import Testing
import Foundation
import SwiftData
import Abstractions
import DataAssets
@testable import Database
import AbstractionsTestUtilities

@Suite("Fallback Model Commands Tests")
@MainActor
struct FallbackModelCommandsTests {
    // MARK: - Helper Methods

    private func createTestDatabase() async throws -> Database {
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        try await addRequiredModelsForChatCommands(database)
        return database
    }

    // MARK: - Tests

    @Test("Get fallback models returns empty array by default")
    func getFallbackModelsReturnsEmptyByDefault() async throws {
        // Given
        let database = try await createTestDatabase()
        let personalityId = try await getDefaultPersonalityId(database)
        let chatId = try await database.write(ChatCommands.Create(personality: personalityId))

        // When
        let fallbacks = try await database.read(ChatCommands.GetFallbackModels(chatId: chatId))

        // Then
        #expect(fallbacks.isEmpty)
    }

    @Test("Set fallback models stores the list")
    func setFallbackModelsStoresList() async throws {
        // Given
        let database = try await createTestDatabase()
        let personalityId = try await getDefaultPersonalityId(database)
        let chatId = try await database.write(ChatCommands.Create(personality: personalityId))
        let fallbackIds = [UUID(), UUID(), UUID()]

        // When
        _ = try await database.write(
            ChatCommands.SetFallbackModels(chatId: chatId, fallbackModelIds: fallbackIds)
        )

        // Then
        let retrieved = try await database.read(ChatCommands.GetFallbackModels(chatId: chatId))
        #expect(retrieved == fallbackIds)
    }

    @Test("Add fallback model appends to list")
    func addFallbackModelAppends() async throws {
        // Given
        let database = try await createTestDatabase()
        let personalityId = try await getDefaultPersonalityId(database)
        let chatId = try await database.write(ChatCommands.Create(personality: personalityId))
        let model1 = UUID()
        let model2 = UUID()

        // When
        _ = try await database.write(ChatCommands.AddFallbackModel(chatId: chatId, modelId: model1))
        _ = try await database.write(ChatCommands.AddFallbackModel(chatId: chatId, modelId: model2))

        // Then
        let fallbacks = try await database.read(ChatCommands.GetFallbackModels(chatId: chatId))
        #expect(fallbacks.count == 2)
        #expect(fallbacks[0] == model1)
        #expect(fallbacks[1] == model2)
    }

    @Test("Add fallback model avoids duplicates")
    func addFallbackModelAvoidsDuplicates() async throws {
        // Given
        let database = try await createTestDatabase()
        let personalityId = try await getDefaultPersonalityId(database)
        let chatId = try await database.write(ChatCommands.Create(personality: personalityId))
        let modelId = UUID()

        // When
        _ = try await database.write(ChatCommands.AddFallbackModel(chatId: chatId, modelId: modelId))
        _ = try await database.write(ChatCommands.AddFallbackModel(chatId: chatId, modelId: modelId))

        // Then
        let fallbacks = try await database.read(ChatCommands.GetFallbackModels(chatId: chatId))
        #expect(fallbacks.count == 1)
    }

    @Test("Remove fallback model removes from list")
    func removeFallbackModelRemoves() async throws {
        // Given
        let database = try await createTestDatabase()
        let personalityId = try await getDefaultPersonalityId(database)
        let chatId = try await database.write(ChatCommands.Create(personality: personalityId))
        let model1 = UUID()
        let model2 = UUID()
        let model3 = UUID()

        _ = try await database.write(
            ChatCommands.SetFallbackModels(chatId: chatId, fallbackModelIds: [model1, model2, model3])
        )

        // When
        _ = try await database.write(
            ChatCommands.RemoveFallbackModel(chatId: chatId, modelId: model2)
        )

        // Then
        let fallbacks = try await database.read(ChatCommands.GetFallbackModels(chatId: chatId))
        #expect(fallbacks.count == 2)
        #expect(fallbacks == [model1, model3])
    }

    @Test("Remove non-existent fallback model does nothing")
    func removeNonExistentFallbackDoesNothing() async throws {
        // Given
        let database = try await createTestDatabase()
        let personalityId = try await getDefaultPersonalityId(database)
        let chatId = try await database.write(ChatCommands.Create(personality: personalityId))
        let modelId = UUID()
        let nonExistentId = UUID()

        _ = try await database.write(ChatCommands.AddFallbackModel(chatId: chatId, modelId: modelId))

        // When
        _ = try await database.write(
            ChatCommands.RemoveFallbackModel(chatId: chatId, modelId: nonExistentId)
        )

        // Then
        let fallbacks = try await database.read(ChatCommands.GetFallbackModels(chatId: chatId))
        #expect(fallbacks.count == 1)
        #expect(fallbacks[0] == modelId)
    }

    @Test("Set fallback models replaces existing list")
    func setFallbackModelsReplaces() async throws {
        // Given
        let database = try await createTestDatabase()
        let personalityId = try await getDefaultPersonalityId(database)
        let chatId = try await database.write(ChatCommands.Create(personality: personalityId))
        let initialIds = [UUID(), UUID()]
        let newIds = [UUID()]

        _ = try await database.write(
            ChatCommands.SetFallbackModels(chatId: chatId, fallbackModelIds: initialIds)
        )

        // When
        _ = try await database.write(
            ChatCommands.SetFallbackModels(chatId: chatId, fallbackModelIds: newIds)
        )

        // Then
        let fallbacks = try await database.read(ChatCommands.GetFallbackModels(chatId: chatId))
        #expect(fallbacks == newIds)
    }
}

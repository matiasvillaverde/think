import Testing
import Foundation
import SwiftData
@testable import Database
import AbstractionsTestUtilities
import Abstractions

@Suite("App Initialization - Migration Scenario")
struct AppInitializationMigrationTests {
    @Test("Migrates v0 models to v1 and adds v2 image model")
    @MainActor
    func migrationUpgradesLegacyModelsAndAddsV2Image() async throws {
        // Given - Database with user having v0 legacy models
        let mockRag = MockRagging()
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: mockRag)
        )
        let database = try Database.new(configuration: config)

        // Create user with v0 legacy models
        let user = User()
        let legacyLanguageModel = try ModelDTO(
            type: .language,
            backend: .mlx,
            name: "legacy-language-model",
            displayName: "Legacy Language Model",
            displayDescription: "A legacy language model",
            skills: ["text-generation"],
            parameters: 1_000_000_000,
            ramNeeded: 2.gigabytes,
            size: 1.gigabytes,
            locationHuggingface: "mlx-community/legacy-model",
            version: 0 // Legacy version
        ).createModel()

        let legacyImageModel = try ModelDTO(
            type: .diffusion,
            backend: .coreml,
            name: "legacy-image-model",
            displayName: "Legacy Image Model",
            displayDescription: "A legacy image model",
            skills: ["image-generation"],
            parameters: 500_000_000,
            ramNeeded: 3.gigabytes,
            size: 2.gigabytes,
            locationHuggingface: "coreml-community/legacy-image",
            version: 0 // Legacy version
        ).createModel()

        database.modelContainer.mainContext.insert(user)
        database.modelContainer.mainContext.insert(legacyLanguageModel)
        database.modelContainer.mainContext.insert(legacyImageModel)
        user.models.append(legacyLanguageModel)
        user.models.append(legacyImageModel)
        try database.modelContainer.mainContext.save()

        // When - Initialize app for migration
        _ = try await database.execute(AppCommands.Initialize())

        // Then - Legacy models should be migrated to v1
        #expect(legacyLanguageModel.version == 1)
        #expect(legacyImageModel.version == 1)

        // Should have added v2 image model
        let v2ImageModels = user.models.filter { $0.type == .diffusion && $0.version == 2 }
        #expect(v2ImageModels.count == 1)

        // Should NOT have added v2 language model
        let v2LanguageModels = user.models.filter { $0.type == .language && $0.version == 2 }
        #expect(v2LanguageModels.isEmpty)

        // Total models: 2 legacy (now v1) + 1 new v2 image = 3
        #expect(user.models.count == 3)
    }

    @Test("Does not create chats during migration")
    @MainActor
    func migrationDoesNotCreateChats() async throws {
        // Given - Database with user having v1 models
        let mockRag = MockRagging()
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: mockRag)
        )
        let database = try Database.new(configuration: config)

        // Create user with v1 models
        let user = User()
        let v1LanguageModel = try ModelDTO(
            type: .language,
            backend: .mlx,
            name: "v1-language-model",
            displayName: "V1 Language Model",
            displayDescription: "A v1 language model",
            skills: ["text-generation"],
            parameters: 1_000_000_000,
            ramNeeded: 2.gigabytes,
            size: 1.gigabytes,
            locationHuggingface: "mlx-community/v1-model",
            version: 1
        ).createModel()

        database.modelContainer.mainContext.insert(user)
        database.modelContainer.mainContext.insert(v1LanguageModel)
        user.models.append(v1LanguageModel)
        try database.modelContainer.mainContext.save()

        // When - Initialize app for migration
        _ = try await database.execute(AppCommands.Initialize())

        // Then - No chats should be created (user must download v2 models)
        #expect(user.chats.isEmpty)

        // Should show welcome screen (no v2 language model)
        let hasV2Language = user.models.contains { $0.type == .language && $0.version == 2 }
        #expect(!hasV2Language)

        // Verify migration returns welcome screen
        let result = try await database.execute(AppCommands.Initialize())
        #expect(result.targetScreen == .welcome)
    }

    @Test("Syncs personalities during migration")
    @MainActor
    func migrationSyncsPersonalities() async throws {
        // Given - Database with user but no personalities
        let mockRag = MockRagging()
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: mockRag)
        )
        let database = try Database.new(configuration: config)

        let user = User()
        database.modelContainer.mainContext.insert(user)
        try database.modelContainer.mainContext.save()

        // When - Initialize app for migration
        _ = try await database.execute(AppCommands.Initialize())

        // Then - Personalities should be synced
        let personalityDescriptor = FetchDescriptor<Personality>()
        let personalities = try database.modelContainer.mainContext.fetch(personalityDescriptor)

        #expect(personalities.count >= 20)
        #expect(personalities.contains { $0.isDefault })
    }
}

import Testing
import Foundation
import SwiftData
@testable import Database
import AbstractionsTestUtilities
import Abstractions

@Suite("App Initialization - New Install Scenario")
struct AppInitializationNewInstallTests {
    @Test("Creates user with only CoreML image model v2 on new install")
    @MainActor
    func newInstallCreatesUserWithOnlyImageModelV2() async throws {
        // Given - Fresh database (no existing user)
        let mockRag = MockRagging()
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: mockRag)
        )
        let database = try Database.new(configuration: config)

        // When - Initialize app for new install
        let result = try await database.execute(AppCommands.Initialize())
        let userId = result.userId

        // Then - User should be created with only v2 image model
        let userDescriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { $0.id == userId }
        )
        let user = try database.modelContainer.mainContext.fetch(userDescriptor).first
        #expect(user != nil)

        // Should have exactly 1 model (v2 image only)
        let models = user!.models
        #expect(models.count == 1)

        // Check NO v2 language-capable models exist
        let v2LanguageModels = models.filter {
            ($0.type == .language || $0.type == .deepLanguage || $0.type == .flexibleThinker) && $0.version == 2
        }
        #expect(v2LanguageModels.isEmpty)

        // Check for exactly one v2 image model
        let v2ImageModels = models.filter { $0.type == .diffusion && $0.version == 2 }
        #expect(v2ImageModels.count == 1)

        let imageModel = v2ImageModels.first!
        #expect(imageModel.version == 2)
        #expect(imageModel.state == .notDownloaded)
        #expect(imageModel.backend == .coreml)
    }

    @Test("Creates default personalities on new install")
    @MainActor
    func newInstallCreatesDefaultPersonalities() async throws {
        // Given - Fresh database
        let mockRag = MockRagging()
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: mockRag)
        )
        let database = try Database.new(configuration: config)

        // When - Initialize app for new install
        _ = try await database.execute(AppCommands.Initialize())

        // Then - Default personalities should be created
        let personalityDescriptor = FetchDescriptor<Personality>()
        let personalities = try database.modelContainer.mainContext.fetch(personalityDescriptor)

        #expect(personalities.count >= 20) // Should have at least 20 system personalities
        #expect(personalities.contains { $0.isDefault }) // Should have default personality

        let systemPersonalities = personalities.filter { !$0.isCustom }
        #expect(systemPersonalities.count >= 20)
    }

    @Test("Does not create any chats on new install")
    @MainActor
    func newInstallDoesNotCreateChats() async throws {
        // Given - Fresh database
        let mockRag = MockRagging()
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: mockRag)
        )
        let database = try Database.new(configuration: config)

        // When - Initialize app for new install
        let result = try await database.execute(AppCommands.Initialize())
        let userId = result.userId

        // Then - No chats should be created
        let userDescriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { $0.id == userId }
        )
        let user = try database.modelContainer.mainContext.fetch(userDescriptor).first!
        #expect(user.chats.isEmpty)

        // Verify app should show welcome screen (no v2 language model)
        let hasV2Language = user.models.contains { $0.type == .language && $0.version == 2 }
        #expect(!hasV2Language)

        // Verify correct screen is returned
        #expect(result.targetScreen == .welcome)
    }
}

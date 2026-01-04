import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
@testable import Database
import Foundation
import Testing

@Suite("ModelStateCoordinator URL Creation Tests", .tags(.acceptance))
internal struct ModelStateCoordinatorURLCreationTests {
    // MARK: - Test Environment

    internal struct TestEnvironment {
        internal let database: Database
        internal let mlxSession: MockLLMSession
        internal let ggufSession: MockLLMSession
        internal let imageGenerator: MockImageGenerating
        internal let coordinator: ModelStateCoordinator
    }

    // MARK: - Test Helpers

    @MainActor
    private func setupTestEnvironment() async throws -> TestEnvironment {
        let database: Database = try await createAndInitializeDatabase()

        let mlxSession: MockLLMSession = MockLLMSession()
        let ggufSession: MockLLMSession = MockLLMSession()
        let imageGenerator: MockImageGenerating = MockImageGenerating()

        let coordinator: ModelStateCoordinator = ModelStateCoordinator(
            database: database,
            mlxSession: mlxSession,
            ggufSession: ggufSession,
            imageGenerator: imageGenerator,
            modelDownloader: MockModelDownloader.createConfiguredMock()
        )

        return TestEnvironment(
            database: database,
            mlxSession: mlxSession,
            ggufSession: ggufSession,
            imageGenerator: imageGenerator,
            coordinator: coordinator
        )
    }

    @MainActor
    private func createAndInitializeDatabase() async throws -> Database {
        let config: DatabaseConfiguration = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database: Database = try Database.new(configuration: config)
        try await AgentOrchestratorTestHelpers.seedDatabase(database)

        return database
    }

    private func createModelWithLocation(_ location: String) -> ModelDTO {
        let megabyte: UInt64 = 1_024 * 1_024
        return ModelDTO(
            type: .language,
            backend: .mlx,
            name: "test-model-\(location.hashValue)",
            displayName: "Test Model",
            displayDescription: "A test model with location: \(location)",
            skills: ["text-generation"],
            parameters: 1_000_000,
            ramNeeded: 100 * megabyte,
            size: 50 * megabyte,
            locationHuggingface: location,
            version: 2,
            architecture: .llama
        )
    }

    @MainActor
    private func createChatWithModelLocation(
        _ database: Database,
        location: String
    ) async throws -> UUID {
        // Add model with specific location
        let model: ModelDTO = createModelWithLocation(location)
        try await database.write(ModelCommands.AddModels(modelDTOs: [model]))

        // Get the model
        let models: [SendableModel] = try await database.read(ModelCommands.FetchAll())
        var targetModel: SendableModel?
        for model in models where model.location == location {
            targetModel = model
            break
        }

        guard let foundModel = targetModel else {
            throw DatabaseError.modelNotFound
        }

        // Get personality and create chat
        let personalityId: UUID = try await database.read(PersonalityCommands.GetDefault())
        return try await database.write(
            ChatCommands.CreateWithModel(
                modelId: foundModel.id,
                personalityId: personalityId
            )
        )
    }

    // MARK: - Tests

    @Test("Invalid URL String Throws Error")
    @MainActor
    internal func invalidURLStringThrowsError() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        // Use a string that URL(string:) cannot parse
        let invalidPath: String = "http://[invalid"
        let chatId: UUID = try await createChatWithModelLocation(env.database, location: invalidPath)
        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)

        // When/Then - Load model with invalid URL string should throw
        await #expect(throws: ModelStateCoordinatorError.self) {
            try await env.coordinator.load(chatId: chatId)
        }
    }

    @Test("Valid URL String Is Resolved Through ModelDownloader")
    @MainActor
    internal func validURLStringResolvedThroughDownloader() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let validURL: String = "https://example.com/model"
        let chatId: UUID = try await createChatWithModelLocation(env.database, location: validURL)
        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)

        // When - Load model with valid URL
        try await env.coordinator.load(chatId: chatId)

        // Then - Verify URL was resolved through ModelDownloader
        let capturedConfig: ProviderConfiguration? = await env.mlxSession.lastPreloadConfiguration
        #expect(capturedConfig != nil, "Configuration should be captured")
        if let config = capturedConfig {
            // ModelDownloader resolves all paths to file URLs
            #expect(config.location.path.contains("https:__example.com_model"))
            #expect(config.modelName == validURL, "Model name should preserve original URL")
        }
    }

    @Test("Path String Without Scheme Is Resolved Through ModelDownloader")
    @MainActor
    internal func pathStringWithoutSchemeResolvedThroughDownloader() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let modelPath: String = "path/to/model"
        let chatId: UUID = try await createChatWithModelLocation(env.database, location: modelPath)
        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)

        // When - Load model with path string
        try await env.coordinator.load(chatId: chatId)

        // Then - Verify path was resolved through ModelDownloader
        let capturedConfig: ProviderConfiguration? = await env.mlxSession.lastPreloadConfiguration
        #expect(capturedConfig != nil, "Configuration should be captured")
        if let config = capturedConfig {
            // ModelDownloader resolves all paths to file URLs
            #expect(config.location.path.contains("path_to_model"))
            #expect(config.modelName == modelPath, "Model name should preserve original path")
        }
    }

    @Test("File URL Is Resolved Through ModelDownloader")
    @MainActor
    internal func fileURLResolvedThroughDownloader() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let fileURL: String = "file:///Users/test/model.gguf"
        let chatId: UUID = try await createChatWithModelLocation(env.database, location: fileURL)
        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)

        // When - Load model with file URL
        try await env.coordinator.load(chatId: chatId)

        // Then - Verify file URL was resolved through ModelDownloader
        let capturedConfig: ProviderConfiguration? = await env.mlxSession.lastPreloadConfiguration
        #expect(capturedConfig != nil, "Configuration should be captured")
        if let config = capturedConfig {
            // ModelDownloader resolves all paths to file URLs
            #expect(config.location.path.contains("file:___Users_test_model.gguf"))
            #expect(config.modelName == fileURL, "Model name should preserve original URL")
        }
    }
}

import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
@testable import Database
import Foundation
import Testing

@Suite("ModelStateCoordinator Configuration Tests", .tags(.acceptance))
internal struct ModelStateCoordinatorConfigurationTests {
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

    // MARK: - Tests

    @Test("Configuration Uses Model Location As ModelName")
    @MainActor
    internal func configurationUsesModelLocationAsModelName() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let modelLocation: String = "test/specific-model"
        let chatId: UUID = try await setupChatWithModelLocation(env.database, location: modelLocation)

        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)

        // When - Load model
        try await env.coordinator.load(chatId: chatId)

        // Then - Verify configuration uses location as modelName
        let capturedConfig: ProviderConfiguration? = await env.mlxSession.lastPreloadConfiguration
        #expect(capturedConfig != nil, "Configuration should be captured")
        if let config = capturedConfig {
            #expect(config.modelName == modelLocation, "ModelName should match location")
            // Location is resolved to a file path by ModelDownloader
            #expect(
                config.location.path.contains("test_specific-model"),
                "Location should contain model name"
            )
        }
    }

    @Test("Configuration Has Default Context Size")
    @MainActor
    internal func configurationHasDefaultContextSize() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId: UUID = try await setupChatWithModel(env.database)

        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)

        // When - Load model
        try await env.coordinator.load(chatId: chatId)

        // Then - Verify default context size is 2048
        let capturedConfig: ProviderConfiguration? = await env.mlxSession.lastPreloadConfiguration
        #expect(capturedConfig != nil, "Configuration should be captured")
        if let config = capturedConfig {
            #expect(config.compute.contextSize == 2_048, "Context size should be 2048")
        }
    }

    @Test("Configuration Has Dynamic Batch Size Based on Memory")
    @MainActor
    internal func configurationHasDynamicBatchSize() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId: UUID = try await setupChatWithModel(env.database)

        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)

        // When - Load model
        try await env.coordinator.load(chatId: chatId)

        // Then - Verify batch size is set based on system memory
        let capturedConfig: ProviderConfiguration? = await env.mlxSession.lastPreloadConfiguration
        #expect(capturedConfig != nil, "Configuration should be captured")
        if let config = capturedConfig {
            // Batch size should be one of the valid values based on memory
            let validBatchSizes: [Int] = [512, 1_024, 2_048, 4_096]
            #expect(
                validBatchSizes.contains(config.compute.batchSize),
                "Batch size should be dynamically set based on memory"
            )
        }
    }

    @Test("Configuration Uses System Processor Count")
    @MainActor
    internal func configurationUsesSystemProcessorCount() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId: UUID = try await setupChatWithModel(env.database)

        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)

        // When - Load model
        try await env.coordinator.load(chatId: chatId)

        // Then - Verify thread count matches processor count
        let expectedThreadCount: Int = ProcessInfo.processInfo.processorCount
        let capturedConfig: ProviderConfiguration? = await env.mlxSession.lastPreloadConfiguration
        #expect(capturedConfig != nil, "Configuration should be captured")
        if let config = capturedConfig {
            #expect(config.compute.threadCount == expectedThreadCount,
                "Thread count should match processor count")
        }
    }

    @Test("Configuration Has No Authentication")
    @MainActor
    internal func configurationHasNoAuthentication() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId: UUID = try await setupChatWithModel(env.database)

        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)

        // When - Load model
        try await env.coordinator.load(chatId: chatId)

        // Then - Verify authentication is noAuth
        let capturedConfig: ProviderConfiguration? = await env.mlxSession.lastPreloadConfiguration
        #expect(capturedConfig != nil, "Configuration should be captured")
        if let config = capturedConfig {
            if case .noAuth = config.authentication {
                // Expected
            } else {
                Issue.record("Expected noAuth authentication")
            }
        }
    }

    @Test("Configuration Uses Default Context Length When No Metadata")
    @MainActor
    internal func configurationUsesDefaultContextLengthWhenNoMetadata() async throws {
        // Given - Model without metadata (contextLength will be nil)
        let env: TestEnvironment = try await setupTestEnvironment()
        let chatId: UUID = try await setupChatWithModel(env.database)

        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)

        // When - Load model
        try await env.coordinator.load(chatId: chatId)

        // Then - Verify default context length is used (2048)
        let capturedConfig: ProviderConfiguration? = await env.mlxSession.lastPreloadConfiguration
        #expect(capturedConfig != nil, "Configuration should be captured")
        if let config = capturedConfig {
            #expect(config.compute.contextSize == 2_048,
                "Context size should default to 2048 when metadata is not available")
        }
    }

    // MARK: - Helper Methods

    @MainActor
    private func setupChatWithModel(_ database: Database) async throws -> UUID {
        let modelDTO: ModelDTO = createTestModel()
        try await database.write(ModelCommands.AddModels(modelDTOs: [modelDTO]))
        let models: [SendableModel] = try await database.read(ModelCommands.FetchAll())
        guard let model = models.first(where: { $0.location == "test/model" }) else {
            throw DatabaseError.modelNotFound
        }

        let personalityId: UUID = try await database.read(PersonalityCommands.GetDefault())
        return try await database.write(
            ChatCommands.CreateWithModel(
                modelId: model.id,
                personalityId: personalityId
            )
        )
    }

    @MainActor
    private func setupChatWithModelLocation(
        _ database: Database,
        location: String
    ) async throws -> UUID {
        let modelDTO: ModelDTO = createTestModelWithLocation(location)
        try await database.write(ModelCommands.AddModels(modelDTOs: [modelDTO]))
        let models: [SendableModel] = try await database.read(ModelCommands.FetchAll())
        guard let model = models.first(where: { $0.location == location }) else {
            throw DatabaseError.modelNotFound
        }

        let personalityId: UUID = try await database.read(PersonalityCommands.GetDefault())
        return try await database.write(
            ChatCommands.CreateWithModel(
                modelId: model.id,
                personalityId: personalityId
            )
        )
    }

    private func createTestModel() -> ModelDTO {
        createTestModelWithLocation("test/model")
    }

    private func createTestModelWithLocation(_ location: String) -> ModelDTO {
        let megabyte: UInt64 = 1_024 * 1_024
        return ModelDTO(
            type: .language,
            backend: .mlx,
            name: "test-model-\(location.hashValue)",
            displayName: "Test Model",
            displayDescription: "A test model for configuration",
            skills: ["text-generation"],
            parameters: 1_000_000,
            ramNeeded: 100 * megabyte,
            size: 50 * megabyte,
            locationHuggingface: location,
            version: 2,
            architecture: .llama
        )
    }
}

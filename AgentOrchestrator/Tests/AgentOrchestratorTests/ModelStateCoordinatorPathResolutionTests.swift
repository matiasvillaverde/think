import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
@testable import Database
import Foundation
import Testing

@Suite("ModelStateCoordinator Path Resolution Tests")
internal struct ModelStateCoordinatorPathResolutionTests {
    // MARK: - Test Environment

    internal struct TestEnvironment {
        internal let database: Database
        internal let mockDownloader: MockModelDownloader
        internal let mlxSession: MockLLMSession
        internal let ggufSession: MockLLMSession
        internal let imageGenerator: MockImageGenerating
        internal let coordinator: ModelStateCoordinator
    }

    // MARK: - Test Helpers

    @MainActor
    private func setupTestEnvironment() async throws -> TestEnvironment {
        let database: Database = try await createAndInitializeDatabase()

        let mockDownloader: MockModelDownloader = MockModelDownloader()
        let mlxSession: MockLLMSession = MockLLMSession()
        let ggufSession: MockLLMSession = MockLLMSession()
        let imageGenerator: MockImageGenerating = MockImageGenerating()

        let coordinator: ModelStateCoordinator = ModelStateCoordinator(
            database: database,
            mlxSession: mlxSession,
            ggufSession: ggufSession,
            imageGenerator: imageGenerator,
            modelDownloader: mockDownloader
        )

        return TestEnvironment(
            database: database,
            mockDownloader: mockDownloader,
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
        _ = try await database.execute(AppCommands.Initialize())

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

    private func createLocalModel(path: String, backend: SendableModel.Backend) -> ModelDTO {
        let megabyte: UInt64 = 1_024 * 1_024
        return ModelDTO(
            type: .language,
            backend: backend,
            name: "local-model-\(path.hashValue)",
            displayName: "Local Model",
            displayDescription: "Local model at \(path)",
            skills: ["text-generation"],
            parameters: 1,
            ramNeeded: 10 * megabyte,
            size: 10 * megabyte,
            locationHuggingface: "",
            locationKind: .localFile,
            locationLocal: path,
            locationBookmark: nil,
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

    @MainActor
    private func createChatWithLocalModel(
        _ database: Database,
        path: String,
        backend: SendableModel.Backend
    ) async throws -> (chatId: UUID, modelId: UUID) {
        let model: ModelDTO = createLocalModel(path: path, backend: backend)
        try await database.write(ModelCommands.AddModels(modelDTOs: [model]))

        let models: [SendableModel] = try await database.read(ModelCommands.FetchAll())
        guard let foundModel = models.first(
            where: { $0.locationKind == .localFile && $0.locationLocal == path }
        ) else {
            throw DatabaseError.modelNotFound
        }

        let personalityId: UUID = try await database.read(PersonalityCommands.GetDefault())
        let chatId: UUID = try await database.write(
            ChatCommands.CreateWithModel(
                modelId: foundModel.id,
                personalityId: personalityId
            )
        )

        return (chatId, foundModel.id)
    }

    // MARK: - Tests

    @Test("HuggingFace Repository ID Resolved Through ModelDownloader")
    @MainActor
    internal func huggingFaceRepoResolvedThroughDownloader() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let repoId: String = "mlx-community/Qwen3-1.7B-4bit"
        let expectedPath: URL = URL(fileURLWithPath: "/Users/test/Models/mlx/mlx-community_Qwen3-1.7B-4bit")

        // Setup mock to return the expected path
        env.mockDownloader.configureModel(for: repoId, location: expectedPath)

        let chatId: UUID = try await createChatWithModelLocation(env.database, location: repoId)
        await env.mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)

        // When - Load model with HuggingFace repository ID
        try await env.coordinator.load(chatId: chatId)

        // Then - Verify the resolved path was used
        let capturedConfig: ProviderConfiguration? = await env.mlxSession.lastPreloadConfiguration
        #expect(capturedConfig != nil, "Configuration should be captured")
        if let config = capturedConfig {
            #expect(config.location == expectedPath, "Should use resolved local path")
            #expect(config.modelName == repoId, "Should preserve original repository ID as model name")
        }
    }

    @Test("Model Not Downloaded Throws Appropriate Error")
    @MainActor
    internal func modelNotDownloadedThrowsError() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let repoId: String = "mlx-community/NotDownloadedModel"

        // Mock returns nil for non-existent model
        // (no need to call setModelLocation, it will return nil by default)

        let chatId: UUID = try await createChatWithModelLocation(env.database, location: repoId)

        // When/Then - Should throw modelNotDownloaded error
        await #expect(throws: ModelStateCoordinatorError.modelNotDownloaded(repoId)) {
            try await env.coordinator.load(chatId: chatId)
        }
    }

    @Test("Empty Model Location Throws Error")
    @MainActor
    internal func emptyModelLocationThrowsError() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let emptyLocation: String = ""

        // When/Then - Database should throw error when creating model with empty location
        await #expect(throws: (any Error).self) {
            _ = try await createChatWithModelLocation(env.database, location: emptyLocation)
        }
    }

    private func createGGUFModel(repoId: String) -> ModelDTO {
        let megabyte: UInt64 = 1_024 * 1_024
        return ModelDTO(
            type: .language,
            backend: .gguf,
            name: "test-gguf-model",
            displayName: "Test GGUF Model",
            displayDescription: "A test GGUF model",
            skills: ["text-generation"],
            parameters: 7_000_000_000,
            ramNeeded: 8_000 * megabyte,
            size: 4_000 * megabyte,
            locationHuggingface: repoId,
            version: 2,
            architecture: .llama
        )
    }

    @MainActor
    private func createGGUFChatWithLocation(
        _ env: TestEnvironment,
        repoId: String
    ) async throws -> UUID {
        let model: ModelDTO = createGGUFModel(repoId: repoId)
        try await env.database.write(ModelCommands.AddModels(modelDTOs: [model]))

        let models: [SendableModel] = try await env.database.read(ModelCommands.FetchAll())
        guard let foundModel = models.first(where: { $0.location == repoId }) else {
            throw DatabaseError.modelNotFound
        }

        let personalityId: UUID = try await env.database.read(PersonalityCommands.GetDefault())
        return try await env.database.write(
            ChatCommands.CreateWithModel(
                modelId: foundModel.id,
                personalityId: personalityId
            )
        )
    }

    @Test("GGUF Model Uses Correct Session And Path Resolution")
    @MainActor
    internal func ggufModelUsesCorrectSession() async throws {
        // Given
        let env: TestEnvironment = try await setupTestEnvironment()
        let repoId: String = "TheBloke/Llama-2-7B-GGUF"
        let expectedPath: URL = URL(fileURLWithPath: "/Users/test/Models/gguf/TheBloke_Llama-2-7B-GGUF")

        env.mockDownloader.configureModel(for: repoId, location: expectedPath)
        let chatId: UUID = try await createGGUFChatWithLocation(env, repoId: repoId)
        await env.ggufSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)

        // When - Load GGUF model
        try await env.coordinator.load(chatId: chatId)

        // Then - Verify GGUF session was used with resolved path
        let ggufConfig: ProviderConfiguration? = await env.ggufSession.lastPreloadConfiguration
        let mlxConfig: ProviderConfiguration? = await env.mlxSession.lastPreloadConfiguration

        #expect(ggufConfig != nil, "GGUF session should be used")
        #expect(mlxConfig == nil, "MLX session should not be used")

        if let config = ggufConfig {
            #expect(config.location == expectedPath, "Should use resolved local path")
            #expect(config.modelName == repoId, "Should preserve original repository ID")
        }
    }

    @Test("Local Model Missing Throws Error And Resets State")
    @MainActor
    internal func localModelMissingResetsState() async throws {
        let env: TestEnvironment = try await setupTestEnvironment()
        let missingPath: String = "/tmp/think-local-model-does-not-exist.gguf"

        let result: (chatId: UUID, modelId: UUID) = try await createChatWithLocalModel(
            env.database,
            path: missingPath,
            backend: .gguf
        )

        await #expect(throws: ModelStateCoordinatorError.modelFileMissing(missingPath)) {
            try await env.coordinator.load(chatId: result.chatId)
        }

        let model: Model = try await env.database.read(ModelCommands.GetModelFromId(id: result.modelId))
        #expect(model.state == .notDownloaded)
    }
}

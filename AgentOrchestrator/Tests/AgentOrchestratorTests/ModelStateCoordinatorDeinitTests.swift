import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
@testable import Database
import Foundation
import Testing

@Suite("ModelStateCoordinator Deinit Tests", .tags(.acceptance))
internal struct ModelStateCoordinatorDeinitTests {
    // MARK: - Test Helpers

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

    // MARK: - Tests

    @MainActor
    private func loadModelInScope(
        database: Database,
        mlxSession: MockLLMSession,
        ggufSession: MockLLMSession,
        chatId: UUID
    ) async -> ModelStateCoordinator? {
        weak var weakCoordinator: ModelStateCoordinator?
        let imageGenerator: MockImageGenerating = MockImageGenerating()
        // Create coordinator and load model
        var coordinator: ModelStateCoordinator? = ModelStateCoordinator(
            database: database,
            mlxSession: mlxSession,
            ggufSession: ggufSession,
            imageGenerator: imageGenerator,
            modelDownloader: MockModelDownloader.createConfiguredMock()
        )
        weakCoordinator = coordinator
        // Load the model
        do {
            try await coordinator?.load(chatId: chatId)
        } catch {
            // Log the error but continue - test will fail later when checking isModelLoaded
            print("Failed to load model in deinit test: \(error)")
        }

        // Now release the strong reference
        coordinator = nil
        // Return the weak reference
        return weakCoordinator
    }

    @Test("Simple Deinit Test")
    @MainActor
    internal func simpleDeinitTest() async throws {
        // Given
        weak var weakRef: ModelStateCoordinator?
        let database: Database = try await createAndInitializeDatabase()
        let mlxSession: MockLLMSession = MockLLMSession()
        let ggufSession: MockLLMSession = MockLLMSession()

        autoreleasepool {
            let imageGenerator: MockImageGenerating = MockImageGenerating()
            let coordinator: ModelStateCoordinator = ModelStateCoordinator(
                database: database,
                mlxSession: mlxSession,
                ggufSession: ggufSession,
                imageGenerator: imageGenerator,
                modelDownloader: MockModelDownloader.createConfiguredMock()
            )
            weakRef = coordinator
            #expect(weakRef != nil, "Should be alive in scope")
        }

        // Give time for deinit to complete
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Then
        #expect(weakRef == nil, "Should be deallocated after scope")
    }

    @Test("Deinit With No Loaded Model Does Nothing")
    @MainActor
    internal func deinitWithNoLoadedModelDoesNothing() async throws {
        // Given
        let database: Database = try await createAndInitializeDatabase()
        let mlxSession: MockLLMSession = MockLLMSession()
        let ggufSession: MockLLMSession = MockLLMSession()

        weak var weakCoordinator: ModelStateCoordinator?

        // Create and immediately release coordinator without loading
        weakCoordinator = createCoordinatorInScope(
            database: database,
            mlxSession: mlxSession,
            ggufSession: ggufSession
        )

        // Give time for deinit to complete
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Verify no unload calls and coordinator deallocated
        await verifyNoUnloadCalls(mlxSession: mlxSession, ggufSession: ggufSession)
        #expect(weakCoordinator == nil, "Coordinator should be deallocated")
    }

    @MainActor
    private func createCoordinatorInScope(
        database: Database,
        mlxSession: MockLLMSession,
        ggufSession: MockLLMSession
    ) -> ModelStateCoordinator? {
        weak var weakRef: ModelStateCoordinator?
        autoreleasepool {
            let imageGenerator: MockImageGenerating = MockImageGenerating()
            let coordinator: ModelStateCoordinator = ModelStateCoordinator(
                database: database,
                mlxSession: mlxSession,
                ggufSession: ggufSession,
                imageGenerator: imageGenerator,
                modelDownloader: MockModelDownloader.createConfiguredMock()
            )
            weakRef = coordinator
        }
        return weakRef
    }

    private func verifyNoUnloadCalls(
        mlxSession: MockLLMSession,
        ggufSession: MockLLMSession
    ) async {
        let mlxUnloadCount: Int = await mlxSession.callCount(for: "unload")
        let ggufUnloadCount: Int = await ggufSession.callCount(for: "unload")

        #expect(mlxUnloadCount == 0, "Should not unload MLX session")
        #expect(ggufUnloadCount == 0, "Should not unload GGUF session")
    }
    @Test("Deinit After Generation Completes")
    @MainActor
    internal func deinitAfterGenerationCompletes() async throws {
        // Given
        let database: Database = try await createAndInitializeDatabase()
        let mlxSession: MockLLMSession = MockLLMSession()
        let ggufSession: MockLLMSession = MockLLMSession()
        let chatId: UUID = try await setupChatWithModel(database, backend: .mlx)

        await mlxSession.configureForSuccessfulPreload(steps: 1, delay: 0.001)
        await mlxSession.configureForSuccessfulGeneration(texts: ["Hello", " World"], delay: 0.01)

        // When
        let weakCoordinator: ModelStateCoordinator? = await loadAndRunGeneration(
            database: database,
            mlxSession: mlxSession,
            ggufSession: ggufSession,
            chatId: chatId
        )

        // Wait for deinit
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Then
        await mlxSession.verifyUnloadCalled()
        #expect(await !mlxSession.isModelLoaded, "Model should be unloaded after deinit")
        #expect(weakCoordinator == nil, "Coordinator should be deallocated")
    }
    @MainActor
    private func loadAndRunGeneration(
        database: Database,
        mlxSession: MockLLMSession,
        ggufSession: MockLLMSession,
        chatId: UUID
    ) async -> ModelStateCoordinator? {
        weak var weakCoordinator: ModelStateCoordinator?
        let imageGenerator: MockImageGenerating = MockImageGenerating()

        var coordinator: ModelStateCoordinator? = ModelStateCoordinator(
            database: database,
            mlxSession: mlxSession,
            ggufSession: ggufSession,
            imageGenerator: imageGenerator,
            modelDownloader: MockModelDownloader.createConfiguredMock()
        )
        weakCoordinator = coordinator

        // Load and generate
        try? await coordinator?.load(chatId: chatId)

        // Run generation to completion
        await runGenerationToCompletion(coordinator)
        // Release coordinator
        coordinator = nil
        return weakCoordinator
    }

    private func runGenerationToCompletion(_ coordinator: ModelStateCoordinator?) async {
        let input: LLMInput = createLLMInput()
        if let coordinator {
            do {
                for try await _ in await coordinator.stream(input) {
                    // Consume stream
                }
            } catch { /* Ignore errors during generation */ }
        }
    }

    @MainActor
    private func loadModelAndStartGeneration(
        database: Database,
        mlxSession: MockLLMSession,
        ggufSession: MockLLMSession,
        chatId: UUID
    ) async -> ModelStateCoordinator? {
        weak var weakCoordinator: ModelStateCoordinator?
        let imageGenerator: MockImageGenerating = MockImageGenerating()

        var coordinator: ModelStateCoordinator? = ModelStateCoordinator(
            database: database,
            mlxSession: mlxSession,
            ggufSession: ggufSession,
            imageGenerator: imageGenerator,
            modelDownloader: MockModelDownloader.createConfiguredMock()
        )
        weakCoordinator = coordinator
        // Load the model
        do {
            try await coordinator?.load(chatId: chatId)
        } catch {
            // Log the error but continue - test will fail later when checking isModelLoaded
            print("Failed to load model in deinit test: \(error)")
        }

        // Start generation in background
        startBackgroundGeneration(coordinator)

        // Give generation time to start
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Release the coordinator during generation
        coordinator = nil

        return weakCoordinator
    }

    private func startBackgroundGeneration(_ coordinator: ModelStateCoordinator?) {
        Task { [weak coordinator] in
            guard let coord = coordinator else {
                return
            }
            for try await _ in await coord.stream(createLLMInput()) {
                // Consuming stream
            }
        }
    }
}

// MARK: - Test Helper Functions

private let kTestModelParameters: UInt64 = 1_000_000
private let kTestModelRAMMegabytes: UInt64 = 100
private let kTestModelSizeMegabytes: UInt64 = 50
private let kTestModelVersion: Int = 2
private let kTestTokenLimit: Int = 100
private let kTestTemperature: Float = 0.7
private let kTestTopP: Float = 0.9
private let kTestTopK: Int = 40
private let kTestRepetitionPenalty: Float = 1.1
private let kTestRepetitionPenaltyRange: Int = 64
private let kKilobytes: UInt64 = 1_024
private let kBytesPerMegabyte: UInt64 = kKilobytes * kKilobytes

@MainActor
private func setupChatWithModel(
    _ database: Database,
    backend: SendableModel.Backend
) async throws -> UUID {
    let location: String = backend == .mlx ? "test/mlx-model" : "test/gguf-model"
    let modelDTO: ModelDTO = createTestModel(backend: backend, location: location)
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

private func createTestModel(backend: SendableModel.Backend, location: String) -> ModelDTO {
    ModelDTO(
        type: .language,
        backend: backend,
        name: "test-\(backend)",
        displayName: "Test \(backend) Model",
        displayDescription: "A test model for deinit testing",
        skills: ["text-generation"],
        parameters: kTestModelParameters,
        ramNeeded: kTestModelRAMMegabytes * kBytesPerMegabyte,
        size: kTestModelSizeMegabytes * kBytesPerMegabyte,
        locationHuggingface: location,
        version: kTestModelVersion,
        architecture: .llama
    )
}

private func createLLMInput() -> LLMInput {
    LLMInput(
        context: "Test prompt",
        sampling: SamplingParameters(
            temperature: kTestTemperature,
            topP: kTestTopP,
            topK: kTestTopK,
            repetitionPenalty: kTestRepetitionPenalty,
            frequencyPenalty: 0.0,
            presencePenalty: 0.0,
            repetitionPenaltyRange: kTestRepetitionPenaltyRange,
            seed: nil,
            stopSequences: []
        ),
        limits: ResourceLimits(maxTokens: kTestTokenLimit)
    )
}

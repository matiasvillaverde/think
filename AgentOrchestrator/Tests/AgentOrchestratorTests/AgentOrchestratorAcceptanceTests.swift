import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
import ContextBuilder
@testable import Database
import Foundation
import Testing
import Tools

@Suite("AgentOrchestrator Acceptance", .tags(.acceptance))
internal struct AgentOrchestratorAcceptanceTests {
    private static let kKilobyte: Int = 1_024
    private static let kMegabyte: UInt64 = 1_048_576
    private static let kPromptTokens: UInt = 10
    private static let kGeneratedTokens: UInt = 20
    private static let kTokensPerSec: Double = 20.0
    private static let kModelParams: UInt64 = 1_000_000
    private static let kModelRamMB: UInt64 = 100
    private static let kModelSizeMB: UInt64 = 50
    private static let kModelVersion: Int = 2
    private static let kTimeFirst: Double = 0.1
    private static let kTimeTotal: Double = 1.0

    @Test("Text Generation Flow")
    @MainActor
    internal func textGenerationFlow() async throws {
        let database: Database = try await setupDB()
        let chatId: UUID = try await setupChat(database)
        let mlxSession: MockLLMSession = MockLLMSession()
        let orchestrator: AgentOrchestrator = setupOrch(
            database: database,
            mlxSession: mlxSession
        )

        await configMocks(mlxSession: mlxSession)
        try await runTest(orchestrator: orchestrator, chatId: chatId)
        try await verify(database: database, chatId: chatId, mlxSession: mlxSession)
    }

    @Test("Remote Text Generation Flow")
    @MainActor
    internal func remoteTextGenerationFlow() async throws {
        let database: Database = try await setupRemoteDB()
        let chatId: UUID = try await setupRemoteChat(database)
        let mlxSession: MockLLMSession = MockLLMSession()
        let remoteSession: MockLLMSession = MockLLMSession()
        let orchestrator: AgentOrchestrator = setupRemoteOrch(
            database: database,
            mlxSession: mlxSession,
            remoteSession: remoteSession
        )

        await configRemoteSession(remoteSession)
        try await runTest(orchestrator: orchestrator, chatId: chatId)
        try await verifyRemote(
            database: database,
            chatId: chatId,
            remoteSession: remoteSession,
            mlxSession: mlxSession
        )
    }

    private func runTest(
        orchestrator: AgentOrchestrator,
        chatId: UUID
    ) async throws {
        try await orchestrator.load(chatId: chatId)
        try await orchestrator.generate(
            prompt: "Hello",
            action: .textGeneration([])
        )
    }

    @MainActor
    private func setupDB() async throws -> Database {
        let config: DatabaseConfiguration = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database: Database = try Database.new(configuration: config)
        try await AgentOrchestratorTestHelpers.seedDatabase(database)

        let model: ModelDTO = createTestModel()
        try await database.write(
            ModelCommands.AddModels(modelDTOs: [model])
        )

        return database
    }

    @MainActor
    private func setupRemoteDB() async throws -> Database {
        let config: DatabaseConfiguration = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database: Database = try Database.new(configuration: config)
        try await AgentOrchestratorTestHelpers.seedDatabase(database)

        _ = try await database.write(
            ModelCommands.CreateRemoteModel(
                name: "remote-llm",
                displayName: "Remote Test LLM",
                displayDescription: "Remote model for testing",
                location: "openrouter:remote-test-llm",
                type: .language,
                architecture: .llama
            )
        )

        return database
    }

    private func createTestModel() -> ModelDTO {
        ModelDTO(
            type: .language,
            backend: .mlx,
            name: "test-mlx-llm",
            displayName: "Test MLX LLM",
            displayDescription: "Test model",
            skills: ["text-generation"],
            parameters: Self.kModelParams,
            ramNeeded: Self.kModelRamMB * Self.kMegabyte,
            size: Self.kModelSizeMB * Self.kMegabyte,
            locationHuggingface: "test/mlx-llm",
            version: Self.kModelVersion,
            architecture: .llama
        )
    }

    @MainActor
    private func setupChat(_ database: Database) async throws -> UUID {
        let personalityId: UUID = try await database.read(
            PersonalityCommands.GetDefault()
        )

        let models: [SendableModel] = try await database.read(
            ModelCommands.FetchAll()
        )

        guard let model = models.first(where: { mdl in
            mdl.location == "test/mlx-llm"
        }) else {
            throw DatabaseError.modelNotFound
        }

        return try await database.write(
            ChatCommands.CreateWithModel(
                modelId: model.id,
                personalityId: personalityId
            )
        )
    }

    @MainActor
    private func setupRemoteChat(_ database: Database) async throws -> UUID {
        let personalityId: UUID = try await database.read(
            PersonalityCommands.GetDefault()
        )

        let models: [SendableModel] = try await database.read(
            ModelCommands.FetchAll()
        )

        guard let model = models.first(where: { $0.backend == .remote }) else {
            throw DatabaseError.modelNotFound
        }

        return try await database.write(
            ChatCommands.CreateWithModel(
                modelId: model.id,
                personalityId: personalityId
            )
        )
    }

    private func setupOrch(
        database: Database,
        mlxSession: MockLLMSession
    ) -> AgentOrchestrator {
        let coordinator: ModelStateCoordinator = ModelStateCoordinator(
            database: database,
            mlxSession: mlxSession,
            ggufSession: MockLLMSession(),
            imageGenerator: MockImageGenerating(),
            modelDownloader: MockModelDownloader.createConfiguredMock()
        )

        let persistor: MessagePersistor = MessagePersistor(
            database: database
        )

        return AgentOrchestrator(
            modelCoordinator: coordinator,
            persistor: persistor,
            contextBuilder: ContextBuilder(tooling: ToolManager())
        )
    }

    private func setupRemoteOrch(
        database: Database,
        mlxSession: MockLLMSession,
        remoteSession: MockLLMSession
    ) -> AgentOrchestrator {
        let coordinator: ModelStateCoordinator = ModelStateCoordinator(
            database: database,
            mlxSession: mlxSession,
            ggufSession: MockLLMSession(),
            imageGenerator: MockImageGenerating(),
            modelDownloader: MockModelDownloader.createConfiguredMock(),
            remoteSession: remoteSession
        )

        let persistor: MessagePersistor = MessagePersistor(
            database: database
        )

        return AgentOrchestrator(
            modelCoordinator: coordinator,
            persistor: persistor,
            contextBuilder: ContextBuilder(tooling: ToolManager())
        )
    }

    private func configMocks(
        mlxSession: MockLLMSession
    ) async {
        await configSession(mlxSession)
    }

    // Context configuration removed as Context is now handled internally

    private func configSession(_ mlxSession: MockLLMSession) async {
        await mlxSession.configureForSuccessfulGeneration(
            texts: ["Hi there!"],
            delay: 0.01
        )
    }

    private func configRemoteSession(_ remoteSession: MockLLMSession) async {
        await remoteSession.configureForSuccessfulGeneration(
            texts: ["Remote hello!"],
            delay: 0.01
        )
    }

    private func verify(
        database: Database,
        chatId: UUID,
        mlxSession: MockLLMSession
    ) async throws {
        #expect(await mlxSession.isModelLoaded)

        // Get messages count instead of actual Message objects
        let messageCount: Int = try await database.read(
            MessageCommands.CountMessages(chatId: chatId)
        )

        #expect(messageCount == 1)
    }

    @MainActor
    private func verifyRemote(
        database: Database,
        chatId: UUID,
        remoteSession: MockLLMSession,
        mlxSession: MockLLMSession
    ) async throws {
        #expect(await remoteSession.isModelLoaded)
        #expect(await mlxSession.calls.isEmpty)

        let messages: [Message] = try await database.read(
            MessageCommands.GetAll(chatId: chatId)
        )

        guard let message = messages.first else {
            throw DatabaseError.messageNotFound
        }

        let channelContents: [String] = message
            .sortedChannels
            .map(\.content)

        #expect(channelContents.contains { $0.contains("Remote hello!") })
    }
}

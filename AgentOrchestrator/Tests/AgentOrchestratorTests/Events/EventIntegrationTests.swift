import Abstractions
@testable import AbstractionsTestUtilities
@testable import AgentOrchestrator
import ContextBuilder
@testable import Database
import Foundation
import Testing
import Tools

// swiftlint:disable explicit_acl explicit_type_interface function_body_length explicit_top_level_acl

/// Integration tests for event emission during agent orchestration
@Suite("Event Integration Tests", .tags(.acceptance))
@MainActor
struct EventIntegrationTests {
    private static let kMegabyte: UInt64 = 1_048_576
    private static let kModelParams: UInt64 = 1_000_000

    @Test("Orchestrator emits generation lifecycle events")
    func orchestratorEmitsLifecycleEvents() async throws {
        let env = try await createTestEnvironment()
        await env.mockSession.configureForSuccessfulGeneration(texts: ["Hello!"], delay: 0.001)

        try await env.orchestrator.load(chatId: env.chatId)
        let eventStream = await env.orchestrator.eventStream

        let eventsTask = Task<[AgentEvent], Never> { @Sendable in
            var events: [AgentEvent] = []
            for await event in eventStream {
                events.append(event)
                if case .generationCompleted = event {
                    break
                }
                if case .generationFailed = event {
                    break
                }
            }
            return events
        }

        try await env.orchestrator.generate(prompt: "Hello", action: .textGeneration([]))

        let events = await eventsTask.value

        // Verify generation started was emitted
        let hasStarted = events.contains { event in
            if case .generationStarted = event {
                return true
            }
            return false
        }
        #expect(hasStarted)

        // Verify generation completed was emitted
        let hasCompleted = events.contains { event in
            if case .generationCompleted = event {
                return true
            }
            return false
        }
        #expect(hasCompleted)

        // Verify order: started should be first, completed should be last
        if case .generationStarted = events.first {
            // Expected
        } else {
            Issue.record("First event should be generationStarted")
        }

        if case .generationCompleted = events.last {
            // Expected
        } else {
            Issue.record("Last event should be generationCompleted")
        }
    }

    // MARK: - Test Helpers

    private func createTestEnvironment() async throws -> TestEnvironment {
        let database = try await setupDatabase()
        let chatId = try await setupChat(database)
        let mockSession = MockLLMSession()

        let coordinator = ModelStateCoordinator(
            database: database,
            mlxSession: mockSession,
            ggufSession: MockLLMSession(),
            imageGenerator: MockImageGenerating(),
            modelDownloader: MockModelDownloader.createConfiguredMock()
        )

        let persistor = MessagePersistor(database: database)
        let contextBuilder = ContextBuilder(tooling: ToolManager())

        let orchestrator = AgentOrchestrator(
            modelCoordinator: coordinator,
            persistor: persistor,
            contextBuilder: contextBuilder
        )

        return TestEnvironment(
            database: database,
            chatId: chatId,
            orchestrator: orchestrator,
            mockSession: mockSession
        )
    }

    private func setupDatabase() async throws -> Database {
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )

        let database = try Database.new(configuration: config)
        _ = try await database.execute(AppCommands.Initialize())

        let model = ModelDTO(
            type: .language,
            backend: .mlx,
            name: "test-mlx-llm",
            displayName: "Test Model",
            displayDescription: "Test model for events",
            skills: ["text-generation"],
            parameters: Self.kModelParams,
            ramNeeded: Self.kMegabyte * 100,
            size: Self.kMegabyte * 50,
            locationHuggingface: "test/mlx-llm",
            version: 1,
            architecture: .llama
        )

        try await database.write(ModelCommands.AddModels(modelDTOs: [model]))

        return database
    }

    private func setupChat(_ database: Database) async throws -> UUID {
        let personalityId = try await database.read(PersonalityCommands.GetDefault())
        let models: [SendableModel] = try await database.read(ModelCommands.FetchAll())

        guard let model = models.first(where: { $0.location == "test/mlx-llm" }) else {
            throw DatabaseError.modelNotFound
        }

        return try await database.write(
            ChatCommands.CreateWithModel(modelId: model.id, personalityId: personalityId)
        )
    }

    private struct TestEnvironment {
        let database: Database
        let chatId: UUID
        let orchestrator: AgentOrchestrator
        let mockSession: MockLLMSession
    }
}

// swiftlint:enable explicit_acl explicit_type_interface function_body_length explicit_top_level_acl

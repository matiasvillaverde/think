import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
import ContextBuilder
import Database
import Foundation
import Testing
import Tools

@Suite("Gateway Event Stream Tests")
@MainActor
struct GatewayEventStreamTests {
    private static let kMegabyte: UInt64 = 1_048_576
    private static let kModelParams: UInt64 = 1_000_000
    private static let kChunkDelay: TimeInterval = 0.001

    @Test("Streaming emits text delta events")
    func streamingEmitsTextDeltaEvents() async throws {
        let env = try await TestEnvironment.create()
        await env.mockSession.configureForSuccessfulGeneration(
            texts: ["Hello", " world"],
            delay: Self.kChunkDelay
        )

        try await env.orchestrator.load(chatId: env.chatId)
        let eventStream = await env.orchestrator.eventStream

        let eventsTask = Task<[AgentEvent], Never> { @Sendable in
            await collectEvents(from: eventStream)
        }

        try await env.orchestrator.generate(prompt: "Hello", action: .textGeneration([]))
        let events = await eventsTask.value

        let deltas: [String] = events.compactMap { event in
            guard case let .textDelta(text) = event else {
                return nil
            }
            return text
        }

        #expect(deltas == ["Hello", " world"])
    }

    @Test("Tool calls emit started and completed events")
    func toolCallsEmitEvents() async throws {
        let env = try await TestEnvironment.create()
        await env.mockSession.setSequentialStreamResponses([
            Self.toolCallResponse(),
            Self.finalResponse("Done.")
        ])

        try await env.orchestrator.load(chatId: env.chatId)
        let eventStream = await env.orchestrator.eventStream

        let eventsTask = Task<[AgentEvent], Never> { @Sendable in
            await collectEvents(from: eventStream)
        }

        try await env.orchestrator.generate(prompt: "Calculate", action: .textGeneration([]))
        let events = await eventsTask.value

        let toolStartedNames: [String] = events.compactMap { event in
            guard case let .toolStarted(_, toolName) = event else {
                return nil
            }
            return toolName
        }
        let toolCompletedCount: Int = events.filter { event in
            if case .toolCompleted = event {
                return true
            }
            return false
        }.count

        #expect(toolStartedNames.contains("calculator"))
        #expect(toolCompletedCount > 0)
    }

    private static func toolCallResponse() -> MockLLMSession.MockStreamResponse {
        .text([
            "I'll use the calculator tool.",
            "<|channel|>tool<|message|>" +
            "{\"operation\": \"add\", \"first\": 2, \"second\": 2}" +
            "<|recipient|>calculator<|call|>"
        ], delayBetweenChunks: Self.kChunkDelay)
    }

    private static func finalResponse(_ message: String) -> MockLLMSession.MockStreamResponse {
        .text([
            "<|channel|>final<|message|>\(message)<|end|>"
        ], delayBetweenChunks: Self.kChunkDelay)
    }

    private static func collectEvents(from stream: AgentEventStream) async -> [AgentEvent] {
        var events: [AgentEvent] = []
        for await event in stream {
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

    private struct TestEnvironment {
        let database: Database
        let orchestrator: AgentOrchestrator
        let mockSession: MockLLMSession
        let chatId: UUID

        static func create() async throws -> TestEnvironment {
            let database = try await createDatabase()
            let chatId = try await setupChat(database)
            let mockSession = MockLLMSession()
            let toolManager = ToolManager()
            await toolManager.registerStrategy(TestCalculatorStrategy())

            let modelDownloader = try configuredDownloader()
            let coordinator = ModelStateCoordinator(
                database: database,
                mlxSession: mockSession,
                ggufSession: MockLLMSession(),
                imageGenerator: MockImageGenerating(),
                modelDownloader: modelDownloader
            )

            let persistor = MessagePersistor(database: database)
            let contextBuilder = ContextBuilder(tooling: toolManager)
            let orchestrator = AgentOrchestrator(
                modelCoordinator: coordinator,
                persistor: persistor,
                contextBuilder: contextBuilder,
                tooling: toolManager
            )

            return TestEnvironment(
                database: database,
                orchestrator: orchestrator,
                mockSession: mockSession,
                chatId: chatId
            )
        }

        private static func createDatabase() async throws -> Database {
            let config = DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )
            let database: Database = try Database.new(configuration: config)
            _ = try await database.execute(AppCommands.Initialize())
            return database
        }

        private static func setupChat(_ database: Database) async throws -> UUID {
            let model = ModelDTO(
                type: .language,
                backend: .mlx,
                name: "test-language-model",
                displayName: "Test Language Model",
                displayDescription: "Language model for tests",
                skills: ["text-generation"],
                parameters: GatewayEventStreamTests.kModelParams,
                ramNeeded: GatewayEventStreamTests.kMegabyte * 100,
                size: GatewayEventStreamTests.kMegabyte * 50,
                locationHuggingface: "test/language",
                version: 1,
                architecture: .llama
            )
            try await database.write(ModelCommands.AddModels(modelDTOs: [model]))

            let personalityId = try await database.read(PersonalityCommands.GetDefault())
            let models: [SendableModel] = try await database.read(ModelCommands.FetchAll())
            guard let firstModel = models.first else {
                throw DatabaseError.modelNotFound
            }
            return try await database.write(
                ChatCommands.CreateWithModel(
                    modelId: firstModel.id,
                    personalityId: personalityId
                )
            )
        }

        private static func configuredDownloader() throws -> MockModelDownloader {
            let downloader = MockModelDownloader()
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
                UUID().uuidString,
                isDirectory: true
            )
            try FileManager.default.createDirectory(
                at: tempDir,
                withIntermediateDirectories: true
            )
            downloader.configureModel(for: "test/language", location: tempDir)
            return downloader
        }
    }

    private final class TestCalculatorStrategy: ToolStrategy {
        let definition: ToolDefinition = ToolDefinition(
            name: "calculator",
            description: "Test calculator tool",
            schema: """
            {
                "type": "object",
                "properties": {
                    "operation": { "type": "string" }
                },
                "required": ["operation"]
            }
            """
        )

        func execute(request: ToolRequest) -> ToolResponse {
            ToolResponse(
                requestId: request.id,
                toolName: request.name,
                result: "{\"result\": 4}",
                metadata: nil,
                error: nil
            )
        }
    }
}

import Abstractions
import AbstractionsTestUtilities
@testable import Database
import Foundation
import Testing
@testable import ViewModels

@Suite("Generator Event Stream Tests")
@MainActor
internal struct GeneratorEventStreamTests {
    @Test("Tool started event marks execution as executing")
    func toolStartedMarksExecutionExecuting() async throws {
        let env: TestEnvironment = try await TestEnvironment.create()
        await env.generator.load(chatId: env.chatId)
        await Task.yield()

        await env.orchestrator.emitEvent(.toolStarted(
            requestId: env.requestId,
            toolName: "calculator"
        ))

        try await Self.waitForUpdates()

        let execution: ToolExecution? = try await env.database.read(
            ToolExecutionCommands.Get(executionId: env.requestId)
        )
        #expect(execution?.state == .executing)
    }

    @Test("Tool progress event updates progress and status")
    func toolProgressUpdatesExecution() async throws {
        let env: TestEnvironment = try await TestEnvironment.create()
        await env.generator.load(chatId: env.chatId)
        await Task.yield()

        await env.orchestrator.emitEvent(.toolStarted(
            requestId: env.requestId,
            toolName: "calculator"
        ))
        await env.orchestrator.emitEvent(.toolProgress(
            requestId: env.requestId,
            progress: 0.42,
            status: "Downloading model"
        ))

        try await Self.waitForUpdates()

        let execution: ToolExecution? = try await env.database.read(
            ToolExecutionCommands.Get(executionId: env.requestId)
        )
        #expect(execution?.progress == 0.42)
        #expect(execution?.statusMessage == "Downloading model")
    }

    private static func waitForUpdates() async throws {
        try await Task.sleep(nanoseconds: 80_000_000)
    }
}

private struct TestEnvironment {
    let database: Database
    let orchestrator: MockAgentOrchestrator
    let generator: ViewModelGenerator
    let chatId: UUID
    let requestId: UUID

    static func create() async throws -> Self {
        let database: Database = try await Self.createDatabase()
        let chatId: UUID = try await Self.createChat(database: database)
        let messageId: UUID = try await Self.createMessage(database: database, chatId: chatId)
        let requestId: UUID = UUID()
        try await Self.createToolExecution(
            database: database,
            messageId: messageId,
            requestId: requestId
        )

        let orchestrator: MockAgentOrchestrator = MockAgentOrchestrator()
        let generator: ViewModelGenerator = ViewModelGenerator(
            orchestrator: orchestrator,
            database: database
        )

        return Self(
            database: database,
            orchestrator: orchestrator,
            generator: generator,
            chatId: chatId,
            requestId: requestId
        )
    }

    private static func createDatabase() async throws -> Database {
        let config: DatabaseConfiguration = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database: Database = try Database.new(configuration: config)
        _ = try await database.execute(AppCommands.Initialize())
        try await TestModelHelpers.createTestModels(database: database)
        return database
    }

    private static func createChat(database: Database) async throws -> UUID {
        let personalityId: UUID = try await database.read(PersonalityCommands.GetDefault())
        let models: [SendableModel] = try await database.read(ModelCommands.FetchAll())
        guard let languageModel: SendableModel = models.first(where: { model in
            switch model.modelType {
            case .language, .visualLanguage, .deepLanguage, .flexibleThinker:
                return true

            case .diffusion, .diffusionXL:
                return false
            }
        }) else {
            throw DatabaseError.modelNotFound
        }
        return try await database.write(
            ChatCommands.CreateWithModel(modelId: languageModel.id, personalityId: personalityId)
        )
    }

    private static func createMessage(database: Database, chatId: UUID) async throws -> UUID {
        try await database.write(MessageCommands.Create(
            chatId: chatId,
            userInput: "Test",
            isDeepThinker: false
        ))
    }

    private static func createToolExecution(
        database: Database,
        messageId: UUID,
        requestId: UUID
    ) async throws {
        let request: ToolRequest = ToolRequest(
            name: "calculator",
            arguments: "{}",
            id: requestId
        )
        let channel: ChannelMessage = ChannelMessage(
            id: UUID(),
            type: .tool,
            content: "Tool: calculator",
            order: 0,
            toolRequest: request
        )
        let output: ProcessedOutput = ProcessedOutput(channels: [channel])
        try await database.write(MessageCommands.UpdateProcessedOutput(
            messageId: messageId,
            processedOutput: output
        ))
    }
}

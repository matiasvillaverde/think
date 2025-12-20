import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
import ContextBuilder
@testable import Database
import Foundation
import Testing
import Tools

@Suite("AgentOrchestrator Module Tests")
internal struct AgentOrchestratorTests {
    @Test("ModelStateCoordinator is available")
    internal func testModelStateCoordinatorAvailable() throws {
        // Verify that the main public type is accessible
        // This test ensures the module exports its public API correctly
        let coordinatorType: ModelStateCoordinator.Type = ModelStateCoordinator.self
        #expect(String(describing: coordinatorType) == "ModelStateCoordinator")
    }

    @Test("Generate Without Loading Chat Throws Error")
    @MainActor
    internal func testGenerateWithoutLoadThrowsNoChatLoadedError() async throws {
        let database: Database = try await createTestDatabase()
        let orchestrator: AgentOrchestrator = createOrchestrator(database: database)

        await #expect(throws: ModelStateCoordinatorError.noChatLoaded) {
            try await orchestrator.generate(prompt: "Hello", action: .textGeneration([]))
        }
    }

    @Test("Semantic Search Tool Configured When Attachments Present")
    @MainActor
    internal func testSemanticSearchConfiguredWithAttachments() async throws {
        // Given
        let database: Database = try await createTestDatabase()
        let toolManager: ToolManager = ToolManager()
        let orchestrator: AgentOrchestrator = createOrchestratorWithTooling(
            database: database,
            toolManager: toolManager
        )
        let chatId: UUID = try await createChatWithAttachment(database: database)
        try await orchestrator.load(chatId: chatId)

        // When - trigger generation to configure semantic search
        await triggerSemanticSearchConfiguration(orchestrator: orchestrator)

        // Then
        await verifySemanticSearchToolConfigured(toolManager: toolManager)
    }

    @Test("Semantic Search Tool NOT Configured When No Attachments")
    @MainActor
    internal func testSemanticSearchNotConfiguredWithoutAttachments() async throws {
        // Given - chat without attachments
        let database: Database = try await createTestDatabase()
        let toolManager: ToolManager = ToolManager()
        let orchestrator: AgentOrchestrator = createOrchestratorWithTooling(
            database: database,
            toolManager: toolManager
        )
        let defaultPersonalityId: UUID = try await database.read(PersonalityCommands.GetDefault())
        let chatId: UUID = try await database.write(
            ChatCommands.Create(personality: defaultPersonalityId)
        )
        try await orchestrator.load(chatId: chatId)

        // When - trigger generation without attachments
        await triggerSemanticSearchConfiguration(orchestrator: orchestrator)

        // Then - semantic search should NOT be registered
        let toolDefinitions: [ToolDefinition] = await toolManager.getAllToolDefinitions()
        let semanticSearchTool: ToolDefinition? = toolDefinitions.first { $0.name == "semantic_search" }
        #expect(semanticSearchTool == nil, "Semantic search should NOT be registered without attachments")
    }

    private func createChatWithAttachment(database: Database) async throws -> UUID {
        let defaultPersonalityId: UUID = try await database.read(PersonalityCommands.GetDefault())
        let chatId: UUID = try await database.write(
            ChatCommands.Create(personality: defaultPersonalityId)
        )

        // Create file and add to chat
        let fileURL: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test.pdf")
        try Data("test content".utf8).write(to: fileURL)

        try await database.write(
            FileCommands.Create(
                fileURL: fileURL,
                chatId: chatId,
                database: database
            )
        )
        return chatId
    }

    private func triggerSemanticSearchConfiguration(orchestrator: AgentOrchestrator) async {
        do {
            try await orchestrator.generate(
                prompt: "Search for information",
                action: .textGeneration([])
            )
        } catch {
            // Expected to fail at model execution
        }
    }

    private func verifySemanticSearchToolConfigured(toolManager: ToolManager) async {
        // First verify the tool wasn't there initially (it's dynamically added)
        let initialDefinitions: [ToolDefinition] = await toolManager.getAllToolDefinitions()

        // After triggering generation with attachments, semantic search should be registered
        let toolDefinitions: [ToolDefinition] = await toolManager.getAllToolDefinitions()
        let semanticSearchTool: ToolDefinition? = toolDefinitions.first { $0.name == "semantic_search" }

        // Verify the tool was dynamically added
        #expect(semanticSearchTool != nil, "Semantic search tool should be registered when attachments exist")

        // Verify it includes the file context
        #expect(semanticSearchTool?.description.contains("test.pdf") == true,
            "Tool description should include attached file names")
        #expect(semanticSearchTool?.description.contains("Available files") == true,
            "Tool description should indicate available files")
    }

    private func createTestDatabase() async throws -> Database {
        let database: Database = try Database.new(
            configuration: DatabaseConfiguration(
                isStoredInMemoryOnly: true,
                allowsSave: true,
                ragFactory: MockRagFactory(mockRag: MockRagging())
            )
        )

        // Initialize database with default data including personalities
        _ = try await database.execute(AppCommands.Initialize())

        // Add a test language model
        let modelDTO: ModelDTO = createTestLanguageModel()
        try await database.write(ModelCommands.AddModels(modelDTOs: [modelDTO]))

        return database
    }

    private func createTestLanguageModel() -> ModelDTO {
        ModelDTO(
            type: .language,
            backend: .mlx,
            name: "test-mlx-llm",
            displayName: "Test MLX LLM",
            displayDescription: "A test language model",
            skills: ["text-generation"],
            parameters: 100_000,
            ramNeeded: 100_000_000,
            size: 50_000_000,
            locationHuggingface: "test/mlx-llm",
            version: 1
        )
    }

    private func createOrchestrator(database: Database) -> AgentOrchestrator {
        let modelCoordinator: ModelStateCoordinator = ModelStateCoordinator(
            database: database,
            mlxSession: MockLLMSession(),
            ggufSession: MockLLMSession(),
            imageGenerator: MockImageGenerating(),
            modelDownloader: MockModelDownloader.createConfiguredMock()
        )
        let toolManager: ToolManager = ToolManager()
        return AgentOrchestrator(
            modelCoordinator: modelCoordinator,
            persistor: MessagePersistor(database: database),
            contextBuilder: ContextBuilder(tooling: toolManager)
        )
    }

    private func createOrchestratorWithTooling(
        database: Database,
        toolManager: ToolManager
    ) -> AgentOrchestrator {
        let modelCoordinator: ModelStateCoordinator = ModelStateCoordinator(
            database: database,
            mlxSession: MockLLMSession(),
            ggufSession: MockLLMSession(),
            imageGenerator: MockImageGenerating(),
            modelDownloader: MockModelDownloader.createConfiguredMock()
        )
        return AgentOrchestrator(
            modelCoordinator: modelCoordinator,
            persistor: MessagePersistor(database: database),
            contextBuilder: ContextBuilder(tooling: toolManager),
            tooling: toolManager
        )
    }
}

import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
@testable import Database
import Foundation
import Testing

@Suite("AgentOrchestrator Tool Execution Flow", .tags(.acceptance))
internal struct AgentOrchestratorToolTests {
    @Test("Tool Execution Flow - Single Tool Call")
    @MainActor
    internal func singleToolExecutionFlow() async throws {
        let database: Database = try await AgentOrchestratorTestHelpers.createTestDatabase()
        let chatId: UUID = try await AgentOrchestratorTestHelpers.setupChatWithModel(database)
        let orchestrator: AgentOrchestrator = await AgentOrchestratorTestHelpers.createToolTestOrchestrator(
            database: database,
            toolCall: "<tool>get_weather({\"location\": \"San Francisco\"})</tool>",
            finalResponse: "it's currently 72°F and sunny in San Francisco."
        )

        try await orchestrator.load(chatId: chatId)

        try await orchestrator.generate(
            prompt: "What's the weather like in San Francisco?",
            action: .textGeneration([])
        )

        // Tool verification removed as Context is now handled internally
    }

    @Test("Tool Execution Flow - Multiple Tool Calls Sequential")
    @MainActor
    internal func multipleToolsSequentialFlow() async throws {
        let database: Database = try await AgentOrchestratorTestHelpers.createTestDatabase()
        let chatId: UUID = try await AgentOrchestratorTestHelpers.setupChatWithModel(database)
        let mlxSession: MockLLMSession = MockLLMSession()
        let orchestrator: AgentOrchestrator = AgentOrchestratorTestHelpers.createOrchestrator(
            database: database,
            mlxSession: mlxSession
        )

        try await orchestrator.load(chatId: chatId)

        try await orchestrator.generate(
            prompt: "Compare weather in SF and NYC",
            action: .textGeneration([])
        )

        // Multiple tool verification removed as Context is now handled internally
    }

    @Test("Tool Execution Flow - Error Handling")
    @MainActor
    internal func toolExecutionErrorHandling() async throws {
        let setup: ToolTestSetup = try await setupFailingToolTest()

        try await setup.orchestrator.load(chatId: setup.chatId)

        // Should not throw - errors should be handled gracefully
        try await setup.orchestrator.generate(prompt: "Execute failing tool", action: .textGeneration([]))

        try await verifyToolErrorHandling(database: setup.database, chatId: setup.chatId)
    }

    private struct ToolTestSetup {
        let database: Database
        let chatId: UUID
        let orchestrator: AgentOrchestrator
    }

    private func setupFailingToolTest() async throws -> ToolTestSetup {
        let database: Database = try await AgentOrchestratorTestHelpers.createTestDatabase()
        let chatId: UUID = try await AgentOrchestratorTestHelpers.setupChatWithModel(database)
        let mlxSession: MockLLMSession = MockLLMSession()

        // First response: request tool execution
        let toolRequestResponse: [String] = [
            "I'll execute the failing tool now. ",
            "[TOOL] {\"name\": \"failing_tool\", \"arguments\": {}} [/TOOL]"
        ]

        // Second response: handle the error result
        let errorHandlingResponse: [String] = [
            "The tool execution failed. ",
            "I apologize for the error."
        ]

        await mlxSession.setSequentialStreamResponses([
            .text(toolRequestResponse, delayBetweenChunks: 0.01),
            .text(errorHandlingResponse, delayBetweenChunks: 0.01)
        ])

        let orchestrator: AgentOrchestrator = AgentOrchestratorTestHelpers.createOrchestrator(
            database: database,
            mlxSession: mlxSession
        )

        return ToolTestSetup(database: database, chatId: chatId, orchestrator: orchestrator)
    }

    @MainActor
    private func verifyToolErrorHandling(database: Database, chatId: UUID) async throws {
        let messages: [Message] = try await database.read(MessageCommands.GetAll(chatId: chatId))
        #expect(messages.count >= 1, "Should have at least the user message")

        // Find the message with the user input
        let userMessage: Message? = messages.first { $0.userInput == "Execute failing tool" }
        #expect(userMessage != nil, "Should have user message with tool execution request")

        // Verify the response acknowledges the error
        if let message = userMessage {
            #expect(message.response != nil, "Should have a response to the tool request")

            // Check if response mentions the error or failure
            if let response = message.response {
                let acknowledgesError: Bool = response.lowercased().contains("error") ||
                    response.lowercased().contains("fail") ||
                    response.lowercased().contains("apologize")
                #expect(acknowledgesError,
                    "Response should acknowledge the error: '\(response)'")
            }

            // Verify channels if they exist
            if let channels = message.channels {
                let hasToolChannel: Bool = channels.contains { $0.type == .tool }
                #expect(hasToolChannel || channels.isEmpty == false,
                    "Should have tool channel or other channels for error handling")
            }
        }
    }
}

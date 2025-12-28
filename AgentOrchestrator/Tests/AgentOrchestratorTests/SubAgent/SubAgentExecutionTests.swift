import Abstractions
import AbstractionsTestUtilities
import Database
import Foundation
import Testing

@testable import AgentOrchestrator

@Suite("SubAgent Execution Tests")
internal struct SubAgentExecutionTests {
    @Test("Sub-agent executes tool calls and returns final output")
    @MainActor
    internal func subAgentExecutesToolLoop() async throws {
        let toolCallOutput: String = "Let me check. " +
            "<tool_call>{\"name\":\"functions\"," +
            "\"arguments\":{\"function_name\":\"get_timestamp\"}}</tool_call>"
        let responses: [MockLLMSession.MockStreamResponse] = [
            .text([toolCallOutput], delayBetweenChunks: 0.001),
            .text(["All done."], delayBetweenChunks: 0.001)
        ]
        let result: SubAgentResult = try await runSubAgent(
            responses: responses,
            prompt: "Run the tool",
            tools: [.functions],
            timeout: .seconds(5)
        )

        #expect(result.status == .completed)
        #expect(result.output.contains("All done"))
        #expect(result.toolsUsed.contains(ToolIdentifier.functions.toolName))
    }

    @Test("Sub-agent returns timed out result when duration exceeded")
    @MainActor
    internal func subAgentTimesOut() async throws {
        let responses: [MockLLMSession.MockStreamResponse] = [
            .text(["Slow response"], delayBetweenChunks: 0.5)
        ]
        let result: SubAgentResult = try await runSubAgent(
            responses: responses,
            prompt: "Slow task",
            tools: [],
            timeout: .milliseconds(10)
        )

        #expect(result.status == .timedOut)
    }

    @MainActor
    private func runSubAgent(
        responses: [MockLLMSession.MockStreamResponse],
        prompt: String,
        tools: Set<ToolIdentifier>,
        timeout: Duration
    ) async throws -> SubAgentResult {
        let (coordinator, chatId): (SubAgentCoordinator, UUID) = try await createCoordinator(
            responses: responses
        )
        let request: SubAgentRequest = SubAgentRequest(
            parentMessageId: UUID(),
            parentChatId: chatId,
            prompt: prompt,
            tools: tools,
            timeout: timeout
        )

        _ = await coordinator.spawn(request: request)
        return try await coordinator.waitForCompletion(requestId: request.id)
    }

    @MainActor
    private func createCoordinator(
        responses: [MockLLMSession.MockStreamResponse]
    ) async throws -> (SubAgentCoordinator, UUID) {
        let database: Database = try await AgentOrchestratorTestHelpers.createTestDatabase()
        let chatId: UUID = try await AgentOrchestratorTestHelpers.setupChatWithModel(database)

        let mockSession: MockLLMSession = MockLLMSession()
        await mockSession.setSequentialStreamResponses(responses)

        let modelDownloader: MockModelDownloader = MockModelDownloader.createConfiguredMock()
        let modelCoordinator: ModelStateCoordinator = ModelStateCoordinator(
            database: database,
            mlxSession: mockSession,
            ggufSession: MockLLMSession(),
            imageGenerator: MockImageGenerating(),
            modelDownloader: modelDownloader
        )

        let subAgentCoordinator: SubAgentCoordinator = SubAgentCoordinator(
            database: database,
            modelCoordinator: modelCoordinator
        )

        return (subAgentCoordinator, chatId)
    }
}

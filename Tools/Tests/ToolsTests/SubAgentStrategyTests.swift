import Abstractions
import Foundation
import Testing
@testable import Tools

@Suite("SubAgentStrategy Tests")
internal struct SubAgentStrategyTests {
    @Test("Missing prompt returns error")
    func missingPromptReturnsError() async {
        let orchestrator: MockSubAgentOrchestrator = MockSubAgentOrchestrator()
        let strategy: SubAgentStrategy = SubAgentStrategy(orchestrator: orchestrator)
        let request: ToolRequest = ToolRequest(
            name: "sub_agent",
            arguments: "{}"
        )

        let response: ToolResponse = await strategy.execute(request: request)

        #expect(response.error != nil)
    }

    @Test("Background mode returns spawned status")
    func backgroundModeReturnsSpawned() async {
        let orchestrator: MockSubAgentOrchestrator = MockSubAgentOrchestrator()
        let strategy: SubAgentStrategy = SubAgentStrategy(orchestrator: orchestrator)
        let request: ToolRequest = ToolRequest(
            name: "sub_agent",
            arguments: "{\"prompt\":\"Do task\",\"mode\":\"background\"}"
        )

        let response: ToolResponse = await strategy.execute(request: request)

        #expect(response.error == nil)
        #expect(response.result.contains("\"status\":\"spawned\""))
        let lastRequest: SubAgentRequest? = await orchestrator.lastRequest
        #expect(lastRequest?.prompt == "Do task")
        #expect(lastRequest?.mode == .background)
    }

    @Test("Sequential mode waits for completion and returns output")
    func sequentialModeWaitsForCompletion() async {
        let orchestrator: MockSubAgentOrchestrator = MockSubAgentOrchestrator()
        await orchestrator.setMockResult(SubAgentResult.success(
            id: UUID(),
            output: "done",
            toolsUsed: [],
            durationMs: 10
        ))
        let strategy: SubAgentStrategy = SubAgentStrategy(orchestrator: orchestrator)
        let request: ToolRequest = ToolRequest(
            name: "sub_agent",
            arguments: "{\"prompt\":\"Do task\",\"mode\":\"sequential\"}"
        )

        let response: ToolResponse = await strategy.execute(request: request)

        #expect(response.error == nil)
        #expect(response.result.contains("\"status\":\"completed\""))
        #expect(response.result.contains("\"output\":\"done\""))
    }

    @Test("Tool request context is propagated to sub-agent request")
    func toolRequestContextPropagated() async {
        let orchestrator: MockSubAgentOrchestrator = MockSubAgentOrchestrator()
        let strategy: SubAgentStrategy = SubAgentStrategy(orchestrator: orchestrator)
        let chatId: UUID = UUID()
        let messageId: UUID = UUID()
        let context: ToolRequestContext = ToolRequestContext(
            chatId: chatId,
            messageId: messageId
        )
        let request: ToolRequest = ToolRequest(
            name: "sub_agent",
            arguments: "{\"prompt\":\"Do task\"}",
            context: context
        )

        _ = await strategy.execute(request: request)

        let lastRequest: SubAgentRequest? = await orchestrator.lastRequest
        #expect(lastRequest?.parentChatId == chatId)
        #expect(lastRequest?.parentMessageId == messageId)
    }
}

private actor MockSubAgentOrchestrator: SubAgentOrchestrating {
    private(set) var lastRequest: SubAgentRequest?
    private var mockResult: SubAgentResult?

    func spawn(request: SubAgentRequest) async -> UUID {
        await Task.yield()
        lastRequest = request
        return request.id
    }

    func setMockResult(_ result: SubAgentResult) async {
        await Task.yield()
        mockResult = result
    }

    func cancel(requestId _: UUID) async {
        await Task.yield()
    }

    func getResult(for requestId: UUID) async -> SubAgentResult? {
        await Task.yield()
        _ = requestId
        return mockResult
    }

    func waitForCompletion(requestId: UUID) async throws -> SubAgentResult {
        await Task.yield()
        _ = requestId
        if false {
            throw ToolError("Unexpected")
        }
        if let mockResult {
            return mockResult
        }
        return SubAgentResult.success(
            id: UUID(),
            output: "ok",
            toolsUsed: [],
            durationMs: 1
        )
    }

    func getActiveRequests() async -> [SubAgentRequest] {
        await Task.yield()
        return lastRequest.map { [$0] } ?? []
    }

    var resultStream: AsyncStream<SubAgentResult> {
        get async {
            await Task.yield()
            return AsyncStream { _ in
                // No-op stream for tests.
            }
        }
    }
}

import Abstractions
import Foundation
import Testing

@testable import AgentOrchestrator

/// Tests for the SubAgentCoordinator
@Suite("SubAgentCoordinator Tests")
internal struct SubAgentCoordinatorTests {
    @Test("Spawn creates a sub-agent request")
    internal func spawnCreatesRequest() async {
        let coordinator: SubAgentCoordinator = SubAgentCoordinator()
        let request: SubAgentRequest = SubAgentRequest(
            parentMessageId: UUID(),
            parentChatId: UUID(),
            prompt: "Test task"
        )

        let requestId: UUID = await coordinator.spawn(request: request)

        #expect(requestId == request.id)
    }

    @Test("Get active requests returns spawned requests")
    internal func getActiveRequestsReturnsSpawned() async {
        let coordinator: SubAgentCoordinator = SubAgentCoordinator()
        let request: SubAgentRequest = SubAgentRequest(
            parentMessageId: UUID(),
            parentChatId: UUID(),
            prompt: "Test task"
        )

        _ = await coordinator.spawn(request: request)
        let activeRequests: [SubAgentRequest] = await coordinator.getActiveRequests()

        #expect(activeRequests.count == 1)
        #expect(activeRequests.first?.id == request.id)
    }

    @Test("Wait for completion returns result")
    internal func waitForCompletionReturnsResult() async throws {
        let coordinator: SubAgentCoordinator = SubAgentCoordinator()
        let request: SubAgentRequest = SubAgentRequest(
            parentMessageId: UUID(),
            parentChatId: UUID(),
            prompt: "Quick task",
            timeout: .seconds(5)
        )

        _ = await coordinator.spawn(request: request)
        let result: SubAgentResult = try await coordinator.waitForCompletion(requestId: request.id)

        #expect(result.id == request.id)
        #expect(result.status == .completed)
    }

    @Test("Cancel cancels running sub-agent")
    internal func cancelCancelsSubAgent() async {
        let coordinator: SubAgentCoordinator = SubAgentCoordinator()
        let request: SubAgentRequest = SubAgentRequest(
            parentMessageId: UUID(),
            parentChatId: UUID(),
            prompt: "Long task",
            timeout: .seconds(300)
        )

        _ = await coordinator.spawn(request: request)
        await coordinator.cancel(requestId: request.id)

        let result: SubAgentResult? = await coordinator.getResult(for: request.id)
        #expect(result?.status == .cancelled)
    }

    @Test("Get result returns nil for unknown request")
    internal func getResultReturnsNilForUnknown() async {
        let coordinator: SubAgentCoordinator = SubAgentCoordinator()

        let result: SubAgentResult? = await coordinator.getResult(for: UUID())

        #expect(result == nil)
    }
}

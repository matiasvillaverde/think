import Abstractions
import AbstractionsTestUtilities
import Database
import Foundation
import Testing

@testable import AgentOrchestrator

/// Tests for the SubAgentCoordinator
@Suite("SubAgentCoordinator Tests")
internal struct SubAgentCoordinatorTests {
    @Test("Spawn creates a sub-agent request")
    @MainActor
    internal func spawnCreatesRequest() async throws {
        let environment: SubAgentTestEnvironment = try await createCoordinator(
            response: .text(["Hello"], delayBetweenChunks: 0.001)
        )
        let request: SubAgentRequest = makeRequest(
            chatId: environment.chatId,
            prompt: "Test task"
        )
        let result: SubAgentResult = try await spawnAndWait(
            environment: environment,
            request: request
        )

        #expect(result.id == request.id)
        #expect(result.status == .completed)
    }

    @Test("Get active requests returns spawned requests")
    @MainActor
    internal func getActiveRequestsReturnsSpawned() async throws {
        let environment: SubAgentTestEnvironment = try await createCoordinator(
            response: .text(["Hello"], delayBetweenChunks: 0.1)
        )
        let request: SubAgentRequest = makeRequest(
            chatId: environment.chatId,
            prompt: "Test task",
            timeout: .seconds(5)
        )

        _ = await environment.coordinator.spawn(request: request)
        let activeRequests: [SubAgentRequest] = await environment.coordinator.getActiveRequests()

        #expect(activeRequests.contains { $0.id == request.id })
    }

    @Test("Wait for completion returns result")
    @MainActor
    internal func waitForCompletionReturnsResult() async throws {
        let environment: SubAgentTestEnvironment = try await createCoordinator(
            response: .text(["Done"], delayBetweenChunks: 0.001)
        )
        let request: SubAgentRequest = makeRequest(
            chatId: environment.chatId,
            prompt: "Quick task",
            timeout: .seconds(30)
        )
        let result: SubAgentResult = try await spawnAndWait(
            environment: environment,
            request: request
        )

        #expect(result.id == request.id)
        #expect(result.status == .completed)
        #expect(result.output.contains("Done"))
    }

    @Test("Cancel cancels running sub-agent")
    @MainActor
    internal func cancelCancelsSubAgent() async throws {
        let environment: SubAgentTestEnvironment = try await createCoordinator(
            response: .text(["Waiting"], delayBetweenChunks: 0.2)
        )
        let request: SubAgentRequest = makeRequest(
            chatId: environment.chatId,
            prompt: "Long task",
            timeout: .seconds(5)
        )

        _ = await environment.coordinator.spawn(request: request)
        await environment.coordinator.cancel(requestId: request.id)

        let result: SubAgentResult? = await environment.coordinator.getResult(for: request.id)
        #expect(result?.status == .cancelled)
    }

    @Test("Get result returns nil for unknown request")
    @MainActor
    internal func getResultReturnsNilForUnknown() async throws {
        let environment: SubAgentTestEnvironment = try await createCoordinator(
            response: .text(["Hello"], delayBetweenChunks: 0.001)
        )

        let result: SubAgentResult? = await environment.coordinator.getResult(for: UUID())

        #expect(result == nil)
    }

    @MainActor
    private func createCoordinator(
        response: MockLLMSession.MockStreamResponse
    ) async throws -> SubAgentTestEnvironment {
        let database: Database = try await AgentOrchestratorTestHelpers.createTestDatabase()
        let chatId: UUID = try await AgentOrchestratorTestHelpers.setupChatWithModel(database)

        let mockSession: MockLLMSession = MockLLMSession()
        await mockSession.setSequentialStreamResponses([response])

        let coordinator: ModelStateCoordinator = makeModelCoordinator(
            database: database,
            mockSession: mockSession
        )
        let subAgentCoordinator: SubAgentCoordinator = SubAgentCoordinator(
            database: database,
            modelCoordinator: coordinator
        )

        return SubAgentTestEnvironment(
            coordinator: subAgentCoordinator,
            chatId: chatId,
            mockSession: mockSession
        )
    }

    private func makeModelCoordinator(
        database: Database,
        mockSession: MockLLMSession
    ) -> ModelStateCoordinator {
        let modelDownloader: MockModelDownloader = MockModelDownloader.createConfiguredMock()
        return ModelStateCoordinator(
            database: database,
            mlxSession: mockSession,
            ggufSession: MockLLMSession(),
            imageGenerator: MockImageGenerating(),
            modelDownloader: modelDownloader
        )
    }

    private func makeRequest(
        chatId: UUID,
        prompt: String,
        timeout: Duration = .seconds(300)
    ) -> SubAgentRequest {
        SubAgentRequest(
            parentMessageId: UUID(),
            parentChatId: chatId,
            prompt: prompt,
            timeout: timeout
        )
    }

    @MainActor
    private func spawnAndWait(
        environment: SubAgentTestEnvironment,
        request: SubAgentRequest
    ) async throws -> SubAgentResult {
        _ = await environment.coordinator.spawn(request: request)
        return try await environment.coordinator.waitForCompletion(requestId: request.id)
    }

    private struct SubAgentTestEnvironment {
        let coordinator: SubAgentCoordinator
        let chatId: UUID
        let mockSession: MockLLMSession
    }
}

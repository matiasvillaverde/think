import Abstractions
import AbstractionsTestUtilities
import Database
import Foundation
import Testing

@testable import AgentOrchestrator

@Suite("LocalGatewayService Tests")
@MainActor
internal struct LocalGatewayServiceTests {
    @Test("Create session adds chat and listSessions returns it")
    internal func createSessionAddsChat() async throws {
        let database: Database = try await makeDatabase()
        let gateway: LocalGatewayService = makeGateway(database: database)

        let session: GatewaySession = try await gateway.createSession(title: "Gateway Session")
        let sessions: [GatewaySession] = try await gateway.listSessions()

        #expect(session.title == "Gateway Session")
        #expect(sessions.contains { $0.id == session.id })
    }

    @Test("Create session creates unique sessions")
    internal func createSessionCreatesUniqueSessions() async throws {
        let database: Database = try await makeDatabase()
        let gateway: LocalGatewayService = makeGateway(database: database)

        let sessionOne: GatewaySession = try await gateway.createSession(title: "One")
        let sessionTwo: GatewaySession = try await gateway.createSession(title: "Two")
        let sessions: [GatewaySession] = try await gateway.listSessions()

        #expect(sessionOne.id != sessionTwo.id)
        #expect(sessions.count == 2)
        #expect(sessions.contains { $0.id == sessionOne.id })
        #expect(sessions.contains { $0.id == sessionTwo.id })
    }

    @Test("Send returns assistant response and history includes user/assistant")
    internal func sendReturnsResponse() async throws {
        let database: Database = try await makeDatabase()
        let mockSession: MockLLMSession = MockLLMSession()
        await configureMockSession(mockSession)

        let gateway: LocalGatewayService = makeGateway(database: database, session: mockSession)
        let sendOutcome: SendOutcome = try await sendMessage(
            using: gateway,
            sessionTitle: nil
        )
        let result: GatewaySendResult = sendOutcome.result
        let history: [GatewayMessage] = sendOutcome.history

        #expect(result.assistantMessage?.content.contains("Hello from the model.") == true)
        #expect(history.count == 2)
        #expect(history.first?.role == .user)
        #expect(history.last?.role == .assistant)
    }

    @Test("Spawn sub-agent adapts chat id")
    internal func spawnSubAgentUsesSessionId() async throws {
        let database: Database = try await makeDatabase()
        let gatewayResult: SubAgentGateway = makeSubAgentGateway(database: database)
        let gateway: LocalGatewayService = gatewayResult.gateway
        let stubCoordinator: StubSubAgentCoordinator = gatewayResult.coordinator

        let session: GatewaySession = try await gateway.createSession(title: "Sub-agent Session")
        let request: SubAgentRequest = SubAgentRequest(
            parentMessageId: UUID(),
            parentChatId: UUID(),
            prompt: "Do work"
        )

        _ = try await gateway.spawnSubAgent(sessionId: session.id, request: request)
        let captured: SubAgentRequest? = await stubCoordinator.lastRequest()

        #expect(captured?.parentChatId == session.id)
    }

    private func makeDatabase() async throws -> Database {
        let database: Database = try await AgentOrchestratorTestHelpers.createTestDatabase()
        try await database.write(
            ModelCommands.AddModels(
                modelDTOs: [AgentOrchestratorTestHelpers.createLanguageModelDTO()]
            )
        )
        return database
    }

    private func makeGateway(
        database: Database,
        session: MockLLMSession = MockLLMSession(),
        subAgentCoordinator: SubAgentOrchestrating? = nil
    ) -> LocalGatewayService {
        let orchestrator: AgentOrchestrating = AgentOrchestratorTestHelpers.createOrchestrator(
            database: database,
            mlxSession: session
        )
        return LocalGatewayService(
            database: database,
            orchestrator: orchestrator,
            subAgentCoordinator: subAgentCoordinator
        )
    }

    private typealias SendOutcome = (result: GatewaySendResult, history: [GatewayMessage])
    private typealias SubAgentGateway = (gateway: LocalGatewayService, coordinator: StubSubAgentCoordinator)

    private func sendMessage(
        using gateway: LocalGatewayService,
        sessionTitle: String?
    ) async throws -> SendOutcome {
        let session: GatewaySession = try await gateway.createSession(title: sessionTitle)
        let result: GatewaySendResult = try await gateway.send(
            sessionId: session.id,
            input: "Hi",
            options: GatewaySendOptions()
        )
        let history: [GatewayMessage] = try await gateway.history(
            sessionId: session.id,
            options: GatewayHistoryOptions(limit: 10)
        )
        return (result: result, history: history)
    }

    private func makeSubAgentGateway(database: Database) -> SubAgentGateway {
        let orchestrator: AgentOrchestrating = AgentOrchestratorTestHelpers.createOrchestrator(
            database: database,
            mlxSession: MockLLMSession()
        )
        let result: SubAgentResult = SubAgentResult.success(
            id: UUID(),
            output: "Done",
            toolsUsed: [],
            durationMs: 1
        )
        let coordinator: StubSubAgentCoordinator = StubSubAgentCoordinator(result: result)
        let gateway: LocalGatewayService = LocalGatewayService(
            database: database,
            orchestrator: orchestrator,
            subAgentCoordinator: coordinator
        )
        return (gateway: gateway, coordinator: coordinator)
    }

    private func configureMockSession(_ session: MockLLMSession) async {
        await session.setSequentialStreamResponses(
            [
                .text(["Hello from the model."], delayBetweenChunks: 0.001)
            ]
        )
    }
}

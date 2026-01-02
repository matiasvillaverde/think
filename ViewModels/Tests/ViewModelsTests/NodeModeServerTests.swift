import Abstractions
import Foundation
import Testing
@testable import ViewModels

@Suite("Node Mode Server Tests")
internal struct NodeModeServerTests {
    @Test("Unauthorized request returns 401")
    @MainActor
    func unauthorizedRequestReturns401() async {
        let gateway: MockGatewayService = MockGatewayService()
        let handler: NodeModeRequestHandler = NodeModeRequestHandler(gateway: gateway)

        let request: HTTPRequest = HTTPRequest(
            method: "GET",
            path: "/sessions",
            queryItems: [],
            headers: [:],
            body: Data()
        )

        let response: HTTPResponse = await handler.handle(
            request: request,
            configuration: NodeModeConfiguration(port: 9_999, authToken: "secret")
        )

        #expect(response.statusCode == 401)
    }

    @Test("List sessions returns payload")
    @MainActor
    func listSessionsReturnsPayload() async throws {
        let session: GatewaySession = GatewaySession(
            id: UUID(),
            title: "Test",
            createdAt: Date(),
            updatedAt: Date()
        )
        let gateway: MockGatewayService = MockGatewayService(sessions: [session])
        let handler: NodeModeRequestHandler = NodeModeRequestHandler(gateway: gateway)

        let request: HTTPRequest = HTTPRequest(
            method: "GET",
            path: "/sessions",
            queryItems: [],
            headers: ["authorization": "Bearer secret"],
            body: Data()
        )

        let response: HTTPResponse = await handler.handle(
            request: request,
            configuration: NodeModeConfiguration(port: 9_999, authToken: "secret")
        )

        #expect(response.statusCode == 200)

        let decoder: JSONDecoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded: [GatewaySession] = try decoder.decode(
            [GatewaySession].self,
            from: response.body
        )
        #expect(decoded.count == 1)
        #expect(decoded.first?.title == "Test")
    }
}

private actor MockGatewayService: GatewayServicing {
    private let sessions: [GatewaySession]

    init(sessions: [GatewaySession] = []) {
        self.sessions = sessions
    }

    func createSession(title: String?) async throws -> GatewaySession {
        try await Task.sleep(nanoseconds: 0)
        return GatewaySession(
            id: UUID(),
            title: title ?? "Untitled",
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func listSessions() async throws -> [GatewaySession] {
        try await Task.sleep(nanoseconds: 0)
        return sessions
    }

    func getSession(id: UUID) async throws -> GatewaySession {
        try await Task.sleep(nanoseconds: 0)
        guard let session: GatewaySession = sessions.first(where: { $0.id == id }) else {
            throw GatewayError.sessionNotFound
        }
        return session
    }

    func history(
        sessionId: UUID,
        options: GatewayHistoryOptions
    ) async throws -> [GatewayMessage] {
        try await Task.sleep(nanoseconds: 0)
        return []
    }

    func send(
        sessionId: UUID,
        input: String,
        options: GatewaySendOptions
    ) async throws -> GatewaySendResult {
        try await Task.sleep(nanoseconds: 0)
        return GatewaySendResult(messageId: UUID(), assistantMessage: nil)
    }

    func spawnSubAgent(
        sessionId: UUID,
        request: SubAgentRequest
    ) async throws -> SubAgentResult {
        try await Task.sleep(nanoseconds: 0)
        return SubAgentResult(
            id: request.id,
            output: "",
            durationMs: 0,
            status: .completed,
            toolsUsed: [],
            errorMessage: nil,
            completedAt: Date()
        )
    }
}

import Abstractions
import Foundation
import Testing
@testable import ViewModels

@Suite("Node Mode Server Tests")
struct NodeModeServerTests {
    @Test("Unauthorized request returns 401")
    @MainActor
    func unauthorizedRequestReturns401() async throws {
        let gateway = MockGatewayService()
        let handler = NodeModeRequestHandler(gateway: gateway)

        let request = HTTPRequest(
            method: "GET",
            path: "/sessions",
            queryItems: [],
            headers: [:],
            body: Data()
        )

        let response = await handler.handle(
            request: request,
            configuration: NodeModeConfiguration(port: 9999, authToken: "secret")
        )

        #expect(response.statusCode == 401)
    }

    @Test("List sessions returns payload")
    @MainActor
    func listSessionsReturnsPayload() async throws {
        let session = GatewaySession(
            id: UUID(),
            title: "Test",
            createdAt: Date(),
            updatedAt: Date()
        )
        let gateway = MockGatewayService(sessions: [session])
        let handler = NodeModeRequestHandler(gateway: gateway)

        let request = HTTPRequest(
            method: "GET",
            path: "/sessions",
            queryItems: [],
            headers: ["authorization": "Bearer secret"],
            body: Data()
        )

        let response = await handler.handle(
            request: request,
            configuration: NodeModeConfiguration(port: 9999, authToken: "secret")
        )

        #expect(response.statusCode == 200)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([GatewaySession].self, from: response.body)
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
        let session = GatewaySession(
            id: UUID(),
            title: title ?? "Untitled",
            createdAt: Date(),
            updatedAt: Date()
        )
        return session
    }

    func listSessions() async throws -> [GatewaySession] {
        sessions
    }

    func getSession(id: UUID) async throws -> GatewaySession {
        guard let session = sessions.first(where: { $0.id == id }) else {
            throw GatewayError.sessionNotFound
        }
        return session
    }

    func history(
        sessionId: UUID,
        options: GatewayHistoryOptions
    ) async throws -> [GatewayMessage] {
        []
    }

    func send(
        sessionId: UUID,
        input: String,
        options: GatewaySendOptions
    ) async throws -> GatewaySendResult {
        GatewaySendResult(messageId: UUID(), assistantMessage: nil)
    }

    func spawnSubAgent(
        sessionId: UUID,
        request: SubAgentRequest
    ) async throws -> SubAgentResult {
        SubAgentResult(
            id: request.id,
            output: "",
            toolsUsed: [],
            durationMs: 0,
            status: .completed,
            errorMessage: nil,
            completedAt: Date()
        )
    }
}

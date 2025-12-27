import Foundation

public enum GatewayError: Error, Sendable, Equatable {
    case sessionNotFound
    case responseNotAvailable
    case subAgentUnavailable
}

public protocol GatewayServicing: Sendable {
    func createSession(title: String?) async throws -> GatewaySession
    func listSessions() async throws -> [GatewaySession]
    func getSession(id: UUID) async throws -> GatewaySession
    func history(
        sessionId: UUID,
        options: GatewayHistoryOptions
    ) async throws -> [GatewayMessage]
    func send(
        sessionId: UUID,
        input: String,
        options: GatewaySendOptions
    ) async throws -> GatewaySendResult
    func spawnSubAgent(
        sessionId: UUID,
        request: SubAgentRequest
    ) async throws -> SubAgentResult
}

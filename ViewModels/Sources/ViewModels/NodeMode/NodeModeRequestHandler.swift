import Abstractions
import Foundation

// MARK: - Request Handler

internal struct NodeModeRequestHandler: Sendable {
    private let gateway: GatewayServicing
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(gateway: GatewayServicing) {
        self.gateway = gateway
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func handle(
        request: HTTPRequest,
        configuration: NodeModeConfiguration
    ) async -> HTTPResponse {
        if let token: String = configuration.authToken {
            guard let authHeader: String = request.headers["authorization"],
                  authHeader == "Bearer \(token)" else {
                return HTTPResponse(statusCode: 401, headers: [:], body: Data())
            }
        }

        do {
            return try await route(request: request)
        } catch {
            let statusCode: Int = (error is DecodingError) ? 400 : 500
            return HTTPResponse(
                statusCode: statusCode,
                headers: [:],
                body: Data("{\"error\":\"\(error.localizedDescription)\"}".utf8)
            )
        }
    }

    private func route(request: HTTPRequest) async throws -> HTTPResponse {
        switch (request.method.uppercased(), request.path) {
        case ("GET", "/health"):
            return respondJSON(["status": "ok"])

        case ("GET", "/sessions"):
            let sessions: [GatewaySession] = try await gateway.listSessions()
            return try respondEncodable(sessions)

        case ("POST", "/sessions"):
            let payload: CreateSessionPayload = try decode(CreateSessionPayload.self, from: request.body)
            let session: GatewaySession = try await gateway.createSession(title: payload.title)
            return try respondEncodable(session, statusCode: 201)

        default:
            break
        }

        if request.path.hasPrefix("/sessions/") {
            return try await routeSession(request: request)
        }

        return HTTPResponse(statusCode: 404, headers: [:], body: Data())
    }

    private func routeSession(request: HTTPRequest) async throws -> HTTPResponse {
        let path: String = request.path
        let components: [Substring] = path.split(separator: "/")
        guard components.count >= 2 else {
            return HTTPResponse(statusCode: 404, headers: [:], body: Data())
        }

        let idString: String = String(components[1])
        guard let sessionId: UUID = UUID(uuidString: idString) else {
            return HTTPResponse(statusCode: 400, headers: [:], body: Data())
        }

        if components.count == 2,
           let response: HTTPResponse = try await routeSessionRoot(
               request: request,
               sessionId: sessionId
           ) {
            return response
        }

        if components.count >= 3 {
            let action: String = String(components[2])
            if let response: HTTPResponse = try await routeSessionAction(
                request: request,
                sessionId: sessionId,
                action: action
            ) {
                return response
            }
        }

        return HTTPResponse(statusCode: 404, headers: [:], body: Data())
    }

    private func routeSessionRoot(
        request: HTTPRequest,
        sessionId: UUID
    ) async throws -> HTTPResponse? {
        guard request.method.uppercased() == "GET" else {
            return nil
        }
        let session: GatewaySession = try await gateway.getSession(id: sessionId)
        return try respondEncodable(session)
    }

    private func routeSessionAction(
        request: HTTPRequest,
        sessionId: UUID,
        action: String
    ) async throws -> HTTPResponse? {
        switch (request.method.uppercased(), action) {
        case ("GET", "history"):
            let limit: String? = request.queryItems.first { $0.name == "limit" }?.value
            let limitValue: Int = Int(limit ?? "") ?? 50
            let history: [GatewayMessage] = try await gateway.history(
                sessionId: sessionId,
                options: GatewayHistoryOptions(limit: limitValue)
            )
            return try respondEncodable(history)

        case ("POST", "messages"):
            let payload: SendRequestPayload = try decode(
                SendRequestPayload.self,
                from: request.body
            )
            let actionValue: Action = payload.action.toAction()
            let result: GatewaySendResult = try await gateway.send(
                sessionId: sessionId,
                input: payload.input,
                options: GatewaySendOptions(action: actionValue)
            )
            return try respondEncodable(result)

        case ("POST", "subagents"):
            let payload: SubAgentRequestPayloadWrapper = try decode(
                SubAgentRequestPayloadWrapper.self,
                from: request.body
            )
            let result: SubAgentResult = try await gateway.spawnSubAgent(
                sessionId: sessionId,
                request: payload.request.toRequest()
            )
            let responsePayload: SubAgentResultPayload = SubAgentResultPayload(result: result)
            return try respondEncodable(responsePayload)

        default:
            return nil
        }
    }

    private func respondJSON(_ payload: [String: String]) -> HTTPResponse {
        let data: Data = (try? JSONSerialization.data(withJSONObject: payload, options: [])) ?? Data()
        return HTTPResponse(statusCode: 200, headers: [:], body: data)
    }

    private func respondEncodable<T: Encodable>(
        _ payload: T,
        statusCode: Int = 200
    ) throws -> HTTPResponse {
        let data: Data = try encoder.encode(payload)
        return HTTPResponse(statusCode: statusCode, headers: [:], body: data)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(T.self, from: data)
    }
}

// MARK: - Payloads

private struct CreateSessionPayload: Codable {
    let title: String?
}

private struct ActionPayload: Codable {
    let type: String
    let tools: [String]

    func toAction() -> Action {
        let identifiers: Set<ToolIdentifier> = Set(
            tools.compactMap { ToolIdentifier.from(toolName: $0) }
        )
        if type.lowercased() == "image_generation" {
            return .imageGeneration(identifiers)
        }
        return .textGeneration(identifiers)
    }
}

private struct SendRequestPayload: Codable {
    let input: String
    let action: ActionPayload
}

private struct SubAgentRequestPayloadWrapper: Codable {
    let request: SubAgentRequestPayload
}

private struct SubAgentRequestPayload: Codable {
    private static let millisecondsPerSecond: Int = 1_000
    private static let attosecondsToMilliseconds: Int64 = 1_000_000_000_000_000

    let id: UUID
    let parentMessageId: UUID
    let parentChatId: UUID
    let prompt: String
    let tools: [String]
    let mode: SubAgentMode
    let timeoutMs: Int
    let systemInstruction: String?
    let createdAt: Date

    func toRequest() -> SubAgentRequest {
        let toolIdentifiers: Set<ToolIdentifier> = Set(
            tools.compactMap { ToolIdentifier.from(toolName: $0) }
        )
        let duration: Duration = Self.duration(from: timeoutMs)
        return SubAgentRequest(
            parentMessageId: parentMessageId,
            parentChatId: parentChatId,
            prompt: prompt,
            id: id,
            tools: toolIdentifiers,
            mode: mode,
            timeout: duration,
            systemInstruction: systemInstruction,
            createdAt: createdAt
        )
    }

    private static func duration(from milliseconds: Int) -> Duration {
        let seconds: Int = milliseconds / millisecondsPerSecond
        let remainingMs: Int = milliseconds % millisecondsPerSecond
        let attoseconds: Int64 = Int64(remainingMs) * attosecondsToMilliseconds
        return Duration(secondsComponent: Int64(seconds), attosecondsComponent: attoseconds)
    }
}

private struct SubAgentResultPayload: Codable {
    let id: UUID
    let output: String
    let toolsUsed: [String]
    let durationMs: Int
    let status: SubAgentStatus
    let errorMessage: String?
    let completedAt: Date

    init(result: SubAgentResult) {
        self.id = result.id
        self.output = result.output
        self.toolsUsed = result.toolsUsed
        self.durationMs = result.durationMs
        self.status = result.status
        self.errorMessage = result.errorMessage
        self.completedAt = result.completedAt
    }
}

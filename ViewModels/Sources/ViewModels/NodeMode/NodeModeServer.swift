import Abstractions
import Foundation
import Network
import OSLog

public struct NodeModeConfiguration: Sendable, Equatable {
    public let port: UInt16
    public let authToken: String?

    public init(port: UInt16, authToken: String?) {
        self.port = port
        self.authToken = authToken
    }
}

public actor NodeModeServer {
    private let logger: Logger = Logger(subsystem: "ViewModels", category: "NodeModeServer")
    private let handler: NodeModeRequestHandler
    private let queue = DispatchQueue(label: "node.mode.server")
    private var listener: NWListener?
    private var configuration: NodeModeConfiguration?

    public var isRunning: Bool {
        listener != nil
    }

    public init(gateway: GatewayServicing) {
        self.handler = NodeModeRequestHandler(gateway: gateway)
    }

    public func start(configuration: NodeModeConfiguration) async throws {
        if let listener {
            listener.cancel()
            self.listener = nil
        }

        let params = NWParameters.tcp
        guard let port = NWEndpoint.Port(rawValue: configuration.port) else {
            throw NodeModeServerError.invalidPort
        }
        let listener = try NWListener(using: params, on: port)
        self.configuration = configuration

        try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if !didResume {
                        didResume = true
                        continuation.resume()
                    }
                case .failed(let error):
                    if !didResume {
                        didResume = true
                        continuation.resume(throwing: error)
                    }
                default:
                    break
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                guard let self else { return }
                self.handleConnection(connection)
            }

            listener.start(queue: queue)
        }

        self.listener = listener
        logger.notice("Node mode server started on port \(configuration.port)")
    }

    public func stop() async {
        listener?.cancel()
        listener = nil
        configuration = nil
        logger.notice("Node mode server stopped")
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        let context = ConnectionContext(connection: connection)
        receiveNext(on: context)
    }

    private func receiveNext(on context: ConnectionContext) {
        context.connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: 65_536
        ) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data {
                context.buffer.append(data)
                while let request = HTTPParser.parse(from: &context.buffer) {
                    Task {
                        await self.respond(to: request, on: context.connection)
                    }
                }
            }

            if isComplete || error != nil {
                context.connection.cancel()
                return
            }

            self.receiveNext(on: context)
        }
    }

    private func respond(to request: HTTPRequest, on connection: NWConnection) async {
        let config = configuration ?? NodeModeConfiguration(port: 0, authToken: nil)
        let response = await handler.handle(request: request, configuration: config)
        let data = response.serialized()

        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

private enum NodeModeServerError: Error {
    case invalidPort
}

// MARK: - Connection Context

private final class ConnectionContext {
    let connection: NWConnection
    var buffer: Data = Data()

    init(connection: NWConnection) {
        self.connection = connection
    }
}

// MARK: - HTTP Types

internal struct HTTPRequest: Sendable {
    let method: String
    let path: String
    let queryItems: [URLQueryItem]
    let headers: [String: String]
    let body: Data
}

internal struct HTTPResponse: Sendable {
    let statusCode: Int
    let headers: [String: String]
    let body: Data

    func serialized() -> Data {
        var lines: [String] = []
        lines.append("HTTP/1.1 \(statusCode) \(HTTPResponse.reasonPhrase(for: statusCode))")

        var finalHeaders = headers
        finalHeaders["Content-Length"] = "\(body.count)"
        finalHeaders["Connection"] = "close"
        if finalHeaders["Content-Type"] == nil {
            finalHeaders["Content-Type"] = "application/json"
        }

        for (key, value) in finalHeaders {
            lines.append("\(key): \(value)")
        }
        lines.append("")
        let headerData = lines.joined(separator: "\r\n").data(using: .utf8) ?? Data()
        return headerData + body
    }

    private static func reasonPhrase(for status: Int) -> String {
        switch status {
        case 200: return "OK"
        case 201: return "Created"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 404: return "Not Found"
        case 500: return "Internal Server Error"
        default: return "OK"
        }
    }
}

// MARK: - HTTP Parsing

private enum HTTPParser {
    static func parse(from buffer: inout Data) -> HTTPRequest? {
        guard let headerRange = buffer.range(of: Data("\r\n\r\n".utf8)) else {
            return nil
        }

        let headerData = buffer.subdata(in: 0..<headerRange.lowerBound)
        guard let headerString = String(data: headerData, encoding: .utf8) else {
            return nil
        }

        let lines = headerString.split(separator: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }

        let method = String(parts[0])
        let urlString = String(parts[1])

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let segments = line.split(separator: ":", maxSplits: 1)
            guard segments.count == 2 else { continue }
            let key = segments[0].trimmingCharacters(in: .whitespaces).lowercased()
            let value = segments[1].trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }

        let contentLength = Int(headers["content-length"] ?? "") ?? 0
        let bodyStart = headerRange.upperBound
        let bodyEnd = bodyStart + contentLength
        guard buffer.count >= bodyEnd else {
            return nil
        }

        let body = buffer.subdata(in: bodyStart..<bodyEnd)
        buffer.removeSubrange(0..<bodyEnd)

        let urlComponents = URLComponents(string: "http://localhost\(urlString)")
        let path = urlComponents?.path ?? urlString
        let queryItems = urlComponents?.queryItems ?? []

        return HTTPRequest(
            method: method,
            path: path,
            queryItems: queryItems,
            headers: headers,
            body: body
        )
    }
}

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
        if let token = configuration.authToken {
            guard let authHeader = request.headers["authorization"],
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
            let sessions = try await gateway.listSessions()
            return try respondEncodable(sessions)

        case ("POST", "/sessions"):
            let payload = try decode(CreateSessionPayload.self, from: request.body)
            let session = try await gateway.createSession(title: payload.title)
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
        let path = request.path
        let components = path.split(separator: "/")
        guard components.count >= 2 else {
            return HTTPResponse(statusCode: 404, headers: [:], body: Data())
        }

        let idString = String(components[1])
        guard let sessionId = UUID(uuidString: idString) else {
            return HTTPResponse(statusCode: 400, headers: [:], body: Data())
        }

        if components.count == 2 {
            if request.method.uppercased() == "GET" {
                let session = try await gateway.getSession(id: sessionId)
                return try respondEncodable(session)
            }
        }

        if components.count >= 3 {
            let action = components[2]
            switch (request.method.uppercased(), action) {
            case ("GET", "history"):
                let limit = request.queryItems.first(where: { $0.name == "limit" })?.value
                let limitValue = Int(limit ?? "") ?? 50
                let history = try await gateway.history(
                    sessionId: sessionId,
                    options: GatewayHistoryOptions(limit: limitValue)
                )
                return try respondEncodable(history)

            case ("POST", "messages"):
                let payload = try decode(SendRequestPayload.self, from: request.body)
                let action = payload.action.toAction()
                let result = try await gateway.send(
                    sessionId: sessionId,
                    input: payload.input,
                    options: GatewaySendOptions(action: action)
                )
                return try respondEncodable(result)

            case ("POST", "subagents"):
                let payload = try decode(SubAgentRequestPayloadWrapper.self, from: request.body)
                let result = try await gateway.spawnSubAgent(
                    sessionId: sessionId,
                    request: payload.request.toRequest()
                )
                let responsePayload = SubAgentResultPayload(result: result)
                return try respondEncodable(responsePayload)

            default:
                break
            }
        }

        return HTTPResponse(statusCode: 404, headers: [:], body: Data())
    }

    private func respondJSON(_ payload: [String: String]) -> HTTPResponse {
        let data = (try? JSONSerialization.data(withJSONObject: payload, options: [])) ?? Data()
        return HTTPResponse(statusCode: 200, headers: [:], body: data)
    }

    private func respondEncodable<T: Encodable>(
        _ payload: T,
        statusCode: Int = 200
    ) throws -> HTTPResponse {
        let data = try encoder.encode(payload)
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
        let identifiers = Set(tools.compactMap(ToolIdentifier.from(toolName:)))
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
        let toolIdentifiers = Set(tools.compactMap(ToolIdentifier.from(toolName:)))
        let duration = Self.duration(from: timeoutMs)
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
        let seconds = milliseconds / millisecondsPerSecond
        let remainingMs = milliseconds % millisecondsPerSecond
        let attoseconds = Int64(remainingMs) * attosecondsToMilliseconds
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

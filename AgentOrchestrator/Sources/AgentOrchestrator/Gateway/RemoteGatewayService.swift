import Abstractions
import Foundation

public final actor RemoteGatewayService: GatewayServicing {
    private static let successStatusCodeRange: Range<Int> = 200..<300

    private let configuration: RemoteGatewayConfiguration
    private let client: GatewayHTTPClient
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        configuration: RemoteGatewayConfiguration,
        client: GatewayHTTPClient = URLSessionGatewayHTTPClient()
    ) {
        self.configuration = configuration
        self.client = client
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public func createSession(title: String?) async throws -> GatewaySession {
        let payload: CreateSessionPayload = CreateSessionPayload(title: title)
        return try await request(
            path: "sessions",
            method: .post,
            body: payload
        )
    }

    public func listSessions() async throws -> [GatewaySession] {
        try await request(path: "sessions", method: .get)
    }

    public func getSession(id: UUID) async throws -> GatewaySession {
        try await request(path: "sessions/\(id.uuidString)", method: .get)
    }

    public func history(
        sessionId: UUID,
        options: GatewayHistoryOptions
    ) async throws -> [GatewayMessage] {
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(options.limit)")
        ]
        return try await request(
            path: "sessions/\(sessionId.uuidString)/history",
            method: .get,
            queryItems: queryItems
        )
    }

    public func send(
        sessionId: UUID,
        input: String,
        options: GatewaySendOptions
    ) async throws -> GatewaySendResult {
        let payload: SendRequestPayload = SendRequestPayload(
            input: input,
            action: actionPayload(for: options.action)
        )
        return try await request(
            path: "sessions/\(sessionId.uuidString)/messages",
            method: .post,
            body: payload
        )
    }

    public func spawnSubAgent(
        sessionId: UUID,
        request subAgentRequest: SubAgentRequest
    ) async throws -> SubAgentResult {
        let payload: SubAgentRequestPayload = SubAgentRequestPayload(request: subAgentRequest)
        let resultPayload: SubAgentResultPayload = try await request(
            path: "sessions/\(sessionId.uuidString)/subagents",
            method: .post,
            body: payload
        )
        return resultPayload.toResult()
    }

    private func request<Response: Decodable>(
        path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        let url: URL = try makeURL(path: path, queryItems: queryItems)
        var urlRequest: URLRequest = makeRequest(url: url, method: method)
        urlRequest.httpBody = nil
        return try await perform(request: urlRequest)
    }

    private func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: HTTPMethod,
        body: Body,
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        let url: URL = try makeURL(path: path, queryItems: queryItems)
        var urlRequest: URLRequest = makeRequest(url: url, method: method)
        urlRequest.httpBody = try encoder.encode(body)
        return try await perform(request: urlRequest)
    }

    private func perform<Response: Decodable>(
        request: URLRequest
    ) async throws -> Response {
        let response: (Data, HTTPURLResponse) = try await client.data(for: request)
        let data: Data = response.0
        let httpResponse: HTTPURLResponse = response.1
        try validate(response: httpResponse, data: data)
        return try decoder.decode(Response.self, from: data)
    }

    private func validate(response: HTTPURLResponse, data: Data) throws {
        guard Self.successStatusCodeRange.contains(response.statusCode) else {
            throw RemoteGatewayError.httpError(statusCode: response.statusCode, payload: data)
        }
    }

    private func makeURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
        var components: URLComponents = try makeComponents(for: path)
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url: URL = components.url else {
            throw RemoteGatewayError.invalidBaseURL
        }
        return url
    }

    private func makeComponents(for path: String) throws -> URLComponents {
        let baseURL: URL = configuration.baseURL
        guard var components: URLComponents = URLComponents(
            url: baseURL,
            resolvingAgainstBaseURL: false
        ) else {
            throw RemoteGatewayError.invalidBaseURL
        }
        let combinedPath: String = buildPath(
            basePath: components.path,
            incomingPath: path
        )
        components.path = "/\(combinedPath)"
        return components
    }

    private func buildPath(basePath: String, incomingPath: String) -> String {
        let trimmedBase: String = basePath.trimmingCharacters(
            in: CharacterSet(charactersIn: "/")
        )
        let trimmedPath: String = incomingPath.trimmingCharacters(
            in: CharacterSet(charactersIn: "/")
        )
        return [trimmedBase, trimmedPath]
            .filter { !$0.isEmpty }
            .joined(separator: "/")
    }

    private func makeRequest(url: URL, method: HTTPMethod) -> URLRequest {
        var request: URLRequest = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = configuration.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        configuration.additionalHeaders.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        return request
    }

    private func actionPayload(for action: Action) -> ActionPayload {
        let type: String = action.isVisual ? "image_generation" : "text_generation"
        let tools: [String] = action.tools.map(\.toolName).sorted()
        return ActionPayload(type: type, tools: tools)
    }

    private enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
    }

    private enum RemoteGatewayError: Error {
        case httpError(statusCode: Int, payload: Data)
        case invalidBaseURL
    }

    private struct CreateSessionPayload: Codable {
        let title: String?
    }

    private struct ActionPayload: Codable {
        let type: String
        let tools: [String]
    }

    private struct SendRequestPayload: Codable {
        let input: String
        let action: ActionPayload
    }

    private struct SubAgentRequestPayload: Codable {
        private static let secondsToMilliseconds: Int = 1_000
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

        init(request: SubAgentRequest) {
            self.id = request.id
            self.parentMessageId = request.parentMessageId
            self.parentChatId = request.parentChatId
            self.prompt = request.prompt
            self.tools = request.tools.map(\.toolName).sorted()
            self.mode = request.mode
            self.timeoutMs = Self.convertDurationToMs(request.timeout)
            self.systemInstruction = request.systemInstruction
            self.createdAt = request.createdAt
        }

        private static func convertDurationToMs(_ duration: Duration) -> Int {
            let secondsMs: Int = Int(duration.components.seconds) * Self.secondsToMilliseconds
            let attosecondsMs: Int = Int(
                duration.components.attoseconds / Self.attosecondsToMilliseconds
            )
            return secondsMs + attosecondsMs
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

        func toResult() -> SubAgentResult {
            SubAgentResult(
                id: id,
                output: output,
                durationMs: durationMs,
                status: status,
                toolsUsed: toolsUsed,
                errorMessage: errorMessage,
                completedAt: completedAt
            )
        }
    }
}

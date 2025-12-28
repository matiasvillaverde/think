import Abstractions
import Foundation
import Testing

@testable import AgentOrchestrator

@Suite("RemoteGatewayService Tests")
internal struct RemoteGatewayServiceTests {
    @Test("Creates session with auth header and request body")
    internal func createSessionUsesAuthHeader() async throws {
        let client: MockGatewayHTTPClient = MockGatewayHTTPClient()
        let session: GatewaySession = makeSession(title: "Remote Session")
        await client.setNextResponse(data: try JSONEncoder.iso8601.encode(session))

        let service: RemoteGatewayService = try makeService(
            client: client,
            token: "token-123"
        )

        let result: GatewaySession = try await service.createSession(title: session.title)
        let request: URLRequest? = await client.lastRequest
        let body: [String: Any] = try decodeBody(from: request)

        #expect(result.id == session.id)
        #expect(request?.httpMethod == "POST")
        #expect(request?.url?.absoluteString == "https://example.com/api/sessions")
        #expect(request?.value(forHTTPHeaderField: "Authorization") == "Bearer token-123")
        #expect(body["title"] as? String == session.title)
    }

    @Test("Send builds action payload with tool names")
    internal func sendBuildsActionPayload() async throws {
        let client: MockGatewayHTTPClient = MockGatewayHTTPClient()
        let sendResult: GatewaySendResult = makeSendResult()
        await client.setNextResponse(data: try JSONEncoder.iso8601.encode(sendResult))

        let service: RemoteGatewayService = try makeService(client: client)
        let sessionId: UUID = UUID()
        _ = try await service.send(
            sessionId: sessionId,
            input: "Hi",
            options: GatewaySendOptions(action: .textGeneration([.browser, .python]))
        )

        let request: URLRequest? = await client.lastRequest
        let body: [String: Any] = try decodeBody(from: request)
        let action: [String: Any] = body["action"] as? [String: Any] ?? [:]
        let tools: [String] = action["tools"] as? [String] ?? []
        let expectedTools: Set<String> = ["browser.search", "python_exec"]

        #expect(body["input"] as? String == "Hi")
        #expect(action["type"] as? String == "text_generation")
        #expect(Set(tools) == expectedTools)
    }

    private func makeService(
        client: MockGatewayHTTPClient,
        token: String? = nil
    ) throws -> RemoteGatewayService {
        let baseURL: URL = try makeBaseURL()
        let config: RemoteGatewayConfiguration = RemoteGatewayConfiguration(
            baseURL: baseURL,
            authToken: token
        )
        return RemoteGatewayService(configuration: config, client: client)
    }

    private func makeBaseURL() throws -> URL {
        guard let url: URL = URL(string: "https://example.com/api") else {
            throw URLError(.badURL)
        }
        return url
    }

    private func makeSession(title: String) -> GatewaySession {
        let createdAt: Date = Date(timeIntervalSince1970: 1)
        let updatedAt: Date = Date(timeIntervalSince1970: 2)
        return GatewaySession(
            id: UUID(),
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func makeSendResult() -> GatewaySendResult {
        let message: GatewayMessage = GatewayMessage(
            id: UUID(),
            role: .assistant,
            content: "Hello",
            createdAt: Date(timeIntervalSince1970: 10)
        )
        return GatewaySendResult(messageId: message.id, assistantMessage: message)
    }

    private func decodeBody(from request: URLRequest?) throws -> [String: Any] {
        let data: Data = request?.httpBody ?? Data()
        let object: Any = try JSONSerialization.jsonObject(with: data)
        return object as? [String: Any] ?? [:]
    }
}

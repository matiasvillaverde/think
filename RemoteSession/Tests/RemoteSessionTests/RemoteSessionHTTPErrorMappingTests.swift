import Abstractions
import Foundation
import Testing
@testable import RemoteSession

@Suite("Remote Session HTTP Error Mapping")
struct RemoteSessionHTTPErrorMappingTests {
    @Test("Maps provider HTTP errors to LLMError with message")
    func mapsStatusCodeBodyToLLMError() async throws {
        let errorJSON = """
        {"error":{"message":"Invalid API key","type":"invalid_request_error"}}
        """
        let httpClient = MockHTTPClient(error: .statusCode(401, Data(errorJSON.utf8)))
        let apiKeyManager = MockAPIKeyManager(keys: [.openRouter: "sk-test-key"])

        let session = RemoteSession(
            apiKeyManager: apiKeyManager,
            httpClient: httpClient,
            retryPolicy: .default
        )

        let configuration = ProviderConfiguration(
            location: URL(fileURLWithPath: "/"),
            authentication: .noAuth,
            modelName: "openrouter:google/gemma-3n-e2b-it:free",
            compute: .init(contextSize: 8_192, batchSize: 512, threadCount: 4)
        )

        for try await _ in await session.preload(configuration: configuration) {
            // Drain preload stream.
        }

        let input = LLMInput(context: "Hello")

        do {
            for try await _ in await session.stream(input) {
                Issue.record("Expected stream to fail before yielding chunks")
            }
            Issue.record("Expected stream to throw")
        } catch let error as LLMError {
            switch error {
            case .authenticationFailed(let message):
                #expect(message.contains("Invalid API key"))

            default:
                Issue.record("Unexpected LLMError: \(error)")
            }
        }
    }
}

private struct MockHTTPClient: HTTPClientProtocol {
    let error: HTTPError

    func stream(_: URLRequest) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: error)
        }
    }
}

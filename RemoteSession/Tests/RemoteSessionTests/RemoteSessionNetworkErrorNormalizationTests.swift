import Abstractions
import Foundation
import Testing
@testable import RemoteSession

@Suite("Remote Session Network Error Normalization")
struct RemoteSessionNetworkErrorTests {
    @Test("Normalizes invalidResponse to LLMError.networkError with readable message")
    func invalidResponseBecomesNetworkLLMError() async throws {
        let httpClient = MockHTTPClient(error: .invalidResponse)
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
            case .networkError(let underlying):
                #expect(underlying.localizedDescription.contains("Invalid response"))
            default:
                Issue.record("Unexpected LLMError: \(error)")
            }
        }
    }

    @Test("Normalizes non-HTTP errors (e.g. URLError) to LLMError.networkError")
    func urlErrorBecomesNetworkLLMError() async throws {
        struct URLErrorClient: HTTPClientProtocol {
            func stream(_: URLRequest) -> AsyncThrowingStream<Data, Error> {
                AsyncThrowingStream { continuation in
                    continuation.finish(throwing: URLError(.notConnectedToInternet))
                }
            }
        }

        let apiKeyManager = MockAPIKeyManager(keys: [.openRouter: "sk-test-key"])
        let session = RemoteSession(
            apiKeyManager: apiKeyManager,
            httpClient: URLErrorClient(),
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
            case .networkError(let underlying):
                let urlError = try #require(underlying as? URLError)
                #expect(urlError.code == .notConnectedToInternet)
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

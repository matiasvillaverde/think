import Abstractions
import Foundation
import Testing
@testable import RemoteSession

@Suite("Remote Session Metrics Tests")
struct RemoteMetricsTests {
    @Test("RemoteSession propagates usage metrics into stream chunks")
    func remoteSessionIncludesUsageMetrics() async throws {
        let responses: [String] = [
            "data: {\"id\":\"1\",\"object\":\"chat.completion.chunk\",\"created\":0," +
                "\"model\":\"gpt-4o-mini\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\"Hello\"}}]}" +
                "\n\n",
            "data: {\"id\":\"1\",\"object\":\"chat.completion.chunk\",\"created\":0," +
                "\"model\":\"gpt-4o-mini\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\"\"}," +
                "\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":5," +
                "\"completion_tokens\":2,\"total_tokens\":7}}" +
                "\n\n"
        ]
        let httpClient = MockHTTPClient(responses: responses)
        let apiKeyManager = MockAPIKeyManager(keys: [.openAI: "sk-test-key"])

        let session = RemoteSession(
            apiKeyManager: apiKeyManager,
            httpClient: httpClient,
            retryPolicy: .default
        )

        let configuration = ProviderConfiguration(
            location: URL(fileURLWithPath: "/"),
            authentication: .noAuth,
            modelName: "openai:gpt-4o-mini",
            compute: .init(contextSize: 8_192, batchSize: 512, threadCount: 4)
        )

        for try await _ in await session.preload(configuration: configuration) {
            // Drain preload stream.
        }

        let input = LLMInput(
            context: "Hello",
            sampling: .default,
            limits: .default
        )

        var lastMetrics: ChunkMetrics?
        for try await chunk in await session.stream(input) {
            if let metrics = chunk.metrics {
                lastMetrics = metrics
            }
        }

        let usage = try #require(lastMetrics?.usage)
        #expect(usage.promptTokens == 5)
        #expect(usage.generatedTokens == 2)
        #expect(usage.totalTokens == 7)
        #expect(usage.contextWindowSize == 8_192)
        #expect(usage.contextTokensUsed == 7)
    }
}

private struct MockHTTPClient: HTTPClientProtocol {
    let responses: [String]

    func stream(_: URLRequest) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            for response in responses {
                if let data = response.data(using: .utf8) {
                    continuation.yield(data)
                }
            }
            continuation.finish()
        }
    }
}

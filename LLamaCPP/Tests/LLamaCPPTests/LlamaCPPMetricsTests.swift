import Abstractions
import Foundation
@testable import LLamaCPP
import Testing

extension LlamaCPPModelTestSuite {
    @Test("Stream includes timing metrics")
    internal func testTimingMetrics() async throws {
        guard let configuration: ProviderConfiguration = TestHelpers.createTestConfiguration() else {
            return
        }
        let session: LlamaCPPSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        for try await _ in preloadStream {
            // Just consume the progress updates
        }
        let input: LLMInput = TestHelpers.createTestInput(context: "Hi", maxTokens: 3)

        let stream: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)
        let chunks: [LLMStreamChunk] = try await TestHelpers.collectChunks(from: stream, limit: 10)

        let chunksWithMetrics: [LLMStreamChunk] = chunks.filter { $0.metrics != nil }
        #expect(
            chunksWithMetrics.count >= 1,
            "Should have at least 1 chunk with metrics, got \(chunksWithMetrics.count)"
        )

        if let firstMetrics = chunksWithMetrics.first?.metrics {
            TestAssertions.assertMetrics(
                firstMetrics,
                expectedGeneratedTokens: nil,  // Will be set progressively
                expectedPromptTokens: 1,  // "Hi" typically tokenizes to 1 token
                hasTimingMetrics: true
            )
        }

        await session.unload()
    }

    @Test("Stream includes usage metrics")
    internal func testUsageMetrics() async throws {
        guard let configuration: ProviderConfiguration = TestHelpers.createTestConfiguration() else {
            return
        }
        let session: LlamaCPPSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        for try await _ in preloadStream {
            // Just consume the progress updates
        }
        let input: LLMInput = TestHelpers.createTestInput(
            context: "Hello world",
            maxTokens: 2
        )

        let stream: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)
        let chunks: [LLMStreamChunk] = try await TestHelpers.collectChunks(from: stream, limit: 10)

        let chunksWithUsage: [LLMStreamChunk] = chunks.filter { $0.metrics?.usage != nil }
        #expect(
            !chunksWithUsage.isEmpty,
            "Should have chunks with usage metrics"
        )

        if let lastChunk = chunksWithUsage.last,
            let metrics = lastChunk.metrics {
            // "Hello world" typically tokenizes to 2-3 tokens
            // With maxTokens=2, we expect exactly 2 generated tokens
            TestAssertions.assertMetrics(
                metrics,
                expectedGeneratedTokens: 2,
                expectedPromptTokens: 2,  // "Hello world" usually 2 tokens
                hasTimingMetrics: true
            )
        }

        await session.unload()
    }
}

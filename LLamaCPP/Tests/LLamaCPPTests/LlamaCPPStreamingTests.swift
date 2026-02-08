import Abstractions
import Foundation
@testable import LLamaCPP
import Testing

extension LlamaCPPModelTestSuite {
    @Test("Stream returns text chunks")
    internal func testStreamReturnsChunks() async throws {
        let configuration: ProviderConfiguration = try TestHelpers.createTestConfiguration()
        let session: LlamaCPPSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        for try await _ in preloadStream {
            // Just consume the progress updates
        }
        let input: LLMInput = TestHelpers.createTestInput()

        let stream: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)
        let chunks: [LLMStreamChunk] = try await TestHelpers.collectChunks(from: stream, limit: 5)

        let textChunks: [LLMStreamChunk] = chunks.filter { chunk in
            if case .text = chunk.event {
                return true
            }
            return false
        }
        #expect(!textChunks.isEmpty, "Should emit at least one text chunk")

        let finishedMetrics: ChunkMetrics? = chunks.first { chunk in
            if case .finished = chunk.event {
                return true
            }
            return false
        }?.metrics
        #expect(finishedMetrics != nil, "Should include finished event with metrics")

        let maxTokens: Int = input.limits.maxTokens
        TestAssertions.assertMetrics(
            finishedMetrics,
            expectedGeneratedTokens: maxTokens
        )

        await session.unload()
    }

    @Test("Stream sends error event on failure")
    internal func testStreamSendsErrorEvent() async throws {
        let configuration: ProviderConfiguration = ProviderConfiguration(
            location: URL(fileURLWithPath: "/invalid/model.gguf"),
            authentication: .noAuth,
            modelName: "invalid-model",
            compute: .small
        )
        let session: LlamaCPPSession = LlamaCPPSession()

        await TestAssertions.assertThrowsLLMError(
            {
                let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
                    configuration: configuration
                )
                for try await _ in preloadStream {
                    // Just consume the progress updates
                }
            },
            expectedError: .modelNotFound("/invalid/model.gguf")
        )
    }
}

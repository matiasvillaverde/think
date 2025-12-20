import Abstractions
import Foundation
@testable import LLamaCPP
import Testing

extension LlamaCPPModelTestSuite {
    @Test("Stream returns text chunks")
    internal func testStreamReturnsChunks() async throws {
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
        let input: LLMInput = TestHelpers.createTestInput()

        let stream: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)
        let chunks: [LLMStreamChunk] = try await TestHelpers.collectChunks(from: stream, limit: 5)

        // With default test input (usually 3 max tokens), expect 3 text + 1 finished
        TestAssertions.assertChunkSequence(
            chunks,
            expectedTextChunks: 3,
            expectedTotalChunks: 4,
            hasFinishedEvent: true
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

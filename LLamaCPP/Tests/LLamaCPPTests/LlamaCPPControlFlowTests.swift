import Abstractions
import Foundation
@testable import LLamaCPP
import Testing

extension LlamaCPPModelTestSuite {
    @Test("Stop cancels active generation")
    internal func testStopCancels() async throws {
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

        let input: LLMInput = LLMInput(
            context: "Write a long story about",
            sampling: SamplingParameters(temperature: 0.7, topP: 0.9),
            limits: ResourceLimits(maxTokens: 100)
        )

        let stream: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)
        var chunks: [LLMStreamChunk] = []

        for try await chunk in stream {
            chunks.append(chunk)
            if chunks.count >= 3 {
                session.stop()
            }
            if chunks.count >= 10 {
                break
            }
        }

        #expect(chunks.count >= 3)
        #expect(chunks.count < 10)

        await session.unload()
    }

    @Test("Stop sequences halt generation")
    internal func testStopSequences() async throws {
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

        let input: LLMInput = LLMInput(
            context: "List three items: apple",
            sampling: SamplingParameters(
                temperature: 0.7,
                topP: 0.9,
                topK: nil,
                repetitionPenalty: 1.0,
                seed: nil,
                stopSequences: ["\n", ".", "3"]
            ),
            limits: ResourceLimits(maxTokens: 50)
        )

        let stream: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)
        let chunks: [LLMStreamChunk] = try await TestHelpers.collectChunks(from: stream, limit: 100)

        #expect(chunks.count < 50)

        await session.unload()
    }
}

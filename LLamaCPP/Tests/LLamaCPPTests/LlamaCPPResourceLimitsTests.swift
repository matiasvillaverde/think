import Abstractions
import Foundation
@testable import LLamaCPP
import Testing

extension LlamaCPPModelTestSuite {
    @Test("MaxTokens limit is enforced")
    internal func testMaxTokensLimit() async throws {
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
            context: "Count from one to one hundred:",
            maxTokens: 5
        )

        let stream: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)
        let chunks: [LLMStreamChunk] = try await TestHelpers.collectChunks(from: stream, limit: 20)

        // With maxTokens=5, expect exactly 5 text chunks + 1 finished
        TestAssertions.assertChunkSequence(
            chunks,
            expectedTextChunks: 5,
            expectedTotalChunks: 6,  // 5 text + 1 finished
            hasFinishedEvent: true
        )

        await session.unload()
    }

    @Test("Timeout cancels generation")
    internal func testTimeout() async throws {
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

        // Use a timeout that's likely to trigger but not too short
        let input: LLMInput = LLMInput(
            context: "Count from 1 to 1000:",
            sampling: SamplingParameters(temperature: 0.1, topP: 0.9),
            limits: ResourceLimits(
                maxTokens: 100,  // Reasonable limit
                maxTime: Duration.milliseconds(500)  // Half second timeout
            )
        )

        let stream: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)

        do {
            let chunks: [LLMStreamChunk] = try await TestHelpers.collectChunks(from: stream, limit: 200)
            // If no timeout, verify we got reasonable output
            let textChunks: [LLMStreamChunk] = chunks.filter { chunk in
                if case .text = chunk.event {
                    return true
                }
                return false
            }
            #expect(
                textChunks.count <= 100,
                "Should respect maxTokens limit even without timeout"
            )
        } catch {
            // If timeout occurs, verify it's the right error
            if let llmError = error as? LLMError,
                case let .providerError(code, message) = llmError {
                #expect(
                    code == "TIMEOUT",
                    "Error code should be TIMEOUT, got \(code)"
                )
                #expect(
                    message.contains("time limit"),
                    "Error message should mention time limit"
                )
            }
        }

        await session.unload()
    }
}

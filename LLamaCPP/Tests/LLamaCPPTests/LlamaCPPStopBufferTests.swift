import Abstractions
import Foundation
@testable import LLamaCPP
import Testing

/// Tests for ensuring buffered text is emitted when stop is called
@Suite("LlamaCPP Stop Buffer Tests")
internal struct LlamaCPPStopBufferTests {
    private let stopAfterTokensConstant: Int = 5
    private let stopAfterChunksConstant: Int = 8

    @Test("Buffered text is emitted when stop() is called")
    internal func testBufferedTextEmittedOnStop() async throws {
        guard let config: ProviderConfiguration = TestHelpers.createTestConfiguration() else {
            return
        }
        let session: LlamaCPPSession = LlamaCPPSession()

        // Preload the model
        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: config
        )
        for try await _ in preloadStream {
            // Consume progress updates
        }

        // Create input with a simple prompt
        let input: LLMInput = LLMInput(
            context: "Count from one to twenty: ",
            sampling: SamplingParameters(
                temperature: 0.7,
                topP: 0.9,
                stopSequences: []  // No stop sequences to ensure we control the stop
            ),
            limits: ResourceLimits(maxTokens: 100)
        )

        var collectedText: String = ""
        var tokenCount: Int = 0

        // Start streaming
        let stream: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)
        streamLoop: for try await chunk in stream {
            switch chunk.event {
            case .text:
                collectedText += chunk.text
                tokenCount += 1

                // Stop after a few tokens to ensure there's buffered text
                if tokenCount >= stopAfterTokensConstant {
                    session.stop()
                }

            case .finished:
                // Check the stop reason
                if let stopReason = chunk.metrics?.generation?.stopReason {
                    #expect(
                        stopReason == .userRequested,
                        "Stop reason should be userRequested, got: \(stopReason)"
                    )
                }
                break streamLoop

            default:
                break
            }
        }

        // Verify we got some text before stopping
        #expect(
            !collectedText.isEmpty,
            "Should have collected some text before stopping"
        )

        #expect(
            tokenCount >= stopAfterTokensConstant,
            "Should have received at least \(stopAfterTokensConstant) tokens"
        )

        await session.unload()
    }

    @Test("Buffered text with partial stop sequence is emitted on user stop")
    internal func testPartialStopSequenceEmittedOnStop() async throws {
        guard let config: ProviderConfiguration = TestHelpers.createTestConfiguration() else {
            return
        }
        let session: LlamaCPPSession = LlamaCPPSession()

        // Preload the model
        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: config
        )
        for try await _ in preloadStream {
            // Consume progress updates
        }

        // Use a multi-character stop sequence
        let stopSequence: String = "STOP"
        let input: LLMInput = LLMInput(
            context: "Generate text and I will stop you: ",
            sampling: SamplingParameters(
                temperature: 0.7,
                topP: 0.9,
                stopSequences: [stopSequence]
            ),
            limits: ResourceLimits(maxTokens: 100)
        )

        var collectedText: String = ""
        var chunkCount: Int = 0

        // Start streaming
        let stream: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)
        streamLoop: for try await chunk in stream {
            switch chunk.event {
            case .text:
                collectedText += chunk.text
                chunkCount += 1

                // Stop after receiving some chunks
                // This might happen when partial stop sequence is in buffer
                if chunkCount >= stopAfterChunksConstant {
                    session.stop()
                }

            case .finished:
                // The buffered text should have been emitted
                break streamLoop

            default:
                break
            }
        }

        // Verify we collected text
        #expect(
            !collectedText.isEmpty,
            "Should have collected text before stopping"
        )

        // The collected text should not contain the complete stop sequence
        // (since we stopped before it could complete)
        #expect(
            !collectedText.contains(stopSequence),
            "Should not contain complete stop sequence when stopped by user"
        )

        await session.unload()
    }
}

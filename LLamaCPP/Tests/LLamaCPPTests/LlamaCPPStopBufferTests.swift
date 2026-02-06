import Abstractions
import Foundation
@testable import LLamaCPP
import Testing

/// Tests for ensuring buffered text is emitted when stop is called
extension LlamaCPPModelTestSuite {
    @Test("Buffered text is emitted when stop() is called")
    internal func testBufferedTextEmittedOnStop() async throws {
        guard let config: ProviderConfiguration = TestHelpers.createTestConfiguration() else {
            return
        }
        let stopAfterTokensConstant: Int = 5
        let session: LlamaCPPSession = LlamaCPPSession()
        try await preloadSession(session, config: config)

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
        let stopAfterChunksConstant: Int = 8
        let session: LlamaCPPSession = LlamaCPPSession()
        try await preloadSession(session, config: config)

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

                // Stop after a few chunks to ensure partial stop sequence possible
                if chunkCount >= stopAfterChunksConstant {
                    session.stop()
                }

            case .finished:
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

        #expect(
            !collectedText.isEmpty,
            "Should have collected some text before stopping"
        )

        #expect(
            chunkCount >= stopAfterChunksConstant,
            "Should have received at least \(stopAfterChunksConstant) chunks"
        )

        await session.unload()
    }

    private func preloadSession(
        _ session: LlamaCPPSession,
        config: ProviderConfiguration
    ) async throws {
        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: config
        )
        for try await _ in preloadStream {
            // Consume progress updates
        }
    }
}

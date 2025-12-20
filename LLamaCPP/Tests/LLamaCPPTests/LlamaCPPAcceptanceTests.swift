import Abstractions
import Foundation
@testable import LLamaCPP
import Testing

/// Acceptance tests that verify the LLMSession protocol works correctly
/// with real text generation and concrete assertions
extension LlamaCPPModelTestSuite {
    // MARK: - Test Constants
    private enum TestConstants {
        static let multiTurnMaxTokens: Int = 5
    }
    @Test("LLMSession generates deterministic text with temperature 0")
    internal func testLLMSessionGeneratesDeterministicText() async throws {
        guard let configuration: ProviderConfiguration = TestHelpers.createTestConfiguration() else {
            return
        }
        // Use the protocol type, not the concrete implementation
        let session: LLMSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        for try await _ in preloadStream {
            // Just consume the progress updates
        }

        // Test deterministic generation
        let input: LLMInput = LLMInput(
            context: "Once upon a time",
            sampling: SamplingParameters(
                temperature: 0.7,  // Deterministic
                topP: 1.0,
                topK: 1,
                seed: 42
            ),
            limits: ResourceLimits(maxTokens: 10)
        )

        // First generation
        var firstGeneration: String = ""
        let stream1: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)

        for try await chunk in stream1 {
            if case .text = chunk.event {
                firstGeneration += chunk.text
            }
        }

        // Second generation with same parameters
        var secondGeneration: String = ""
        let stream2: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)

        for try await chunk in stream2 {
            if case .text = chunk.event {
                secondGeneration += chunk.text
            }
        }

        // Assert deterministic behavior
        #expect(
            !firstGeneration.isEmpty,
            "Should generate text on first attempt"
        )

        #expect(
            firstGeneration == secondGeneration,
            """
            Deterministic generation should produce identical text
            First: '\(firstGeneration)'
            Second: '\(secondGeneration)'
            """
        )

        await session.unload()
    }

    @Test("LLMSession generates non-empty text for prompts")
    internal func testLLMSessionGeneratesNonEmptyText() async throws {
        guard let configuration: ProviderConfiguration = TestHelpers.createTestConfiguration() else {
            return
        }
        // Use protocol type for true acceptance testing
        let session: LLMSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        for try await _ in preloadStream {
            // Just consume the progress updates
        }

        let input: LLMInput = LLMInput(
            context: "Hello world",
            sampling: SamplingParameters(
                temperature: 0.5,
                topP: 0.9,
                topK: 40
            ),
            limits: ResourceLimits(maxTokens: 10)
        )

        var generatedText: String = ""
        var chunkCount: Int = 0
        let stream: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)

        for try await chunk in stream {
            if case .text = chunk.event {
                generatedText += chunk.text
                chunkCount += 1
            }
        }

        // Basic assertions about generation
        #expect(
            !generatedText.isEmpty,
            "Should generate non-empty text"
        )

        #expect(
            chunkCount > 0 && chunkCount <= 10,
            "Should generate between 1 and 10 chunks, got \(chunkCount)"
        )

        #expect(
            !generatedText.isEmpty,
            "Generated text should have non-zero length, got \(generatedText.count) characters"
        )

        await session.unload()
    }

    @Test("LLMSession provides consistent metrics")
    internal func testLLMSessionProvidesMetrics() async throws {
        guard let configuration: ProviderConfiguration = TestHelpers.createTestConfiguration() else {
            return
        }
        let session: LLMSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        for try await _ in preloadStream {
            // Just consume the progress updates
        }

        let input: LLMInput = LLMInput(
            context: "Hello",
            sampling: SamplingParameters(temperature: 0.0, topP: 1.0),
            limits: ResourceLimits(maxTokens: 3)
        )

        let (lastMetrics, tokenCount): (ChunkMetrics?, Int) = try await collectMetrics(
            from: session,
            input: input
        )
        validateMetrics(lastMetrics, tokenCount: tokenCount)

        await session.unload()
    }

    private func collectMetrics(
        from session: LLMSession,
        input: LLMInput
    ) async throws -> (ChunkMetrics?, Int) {
        var lastMetrics: ChunkMetrics?
        var tokenCount: Int = 0
        let stream: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)

        for try await chunk in stream {
            if case .text = chunk.event {
                tokenCount += 1
                if let metrics = chunk.metrics {
                    lastMetrics = metrics
                }
            }
        }

        return (lastMetrics, tokenCount)
    }

    private func validateMetrics(
        _ metrics: ChunkMetrics?,
        tokenCount: Int
    ) {
        #expect(metrics != nil, "Should have metrics in chunks")
        guard let metrics else {
            return
        }

        if let usage = metrics.usage {
            #expect(
                usage.generatedTokens == tokenCount,
                "Generated tokens should match actual count: \(usage.generatedTokens) vs \(tokenCount)"
            )
            #expect(usage.totalTokens > 0, "Total tokens should be positive")
        }

        if let timing = metrics.timing {
            #expect(timing.totalTime > Duration.zero, "Total time should be positive")
            if let ttft = timing.timeToFirstToken {
                #expect(
                    ttft >= Duration.zero && ttft <= timing.totalTime,
                    "TTFT should be between 0 and total time"
                )
            }
        }
    }

    @Test("LLMSession handles multi-turn conversation")
    internal func testLLMSessionMultiTurnConversation() async throws {
        guard let configuration: ProviderConfiguration = TestHelpers.createTestConfiguration() else {
            return
        }
        let session: LLMSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        for try await _ in preloadStream {
            // Just consume the progress updates
        }

        let response1: String = try await generateResponseForPrompt(
            "What color is the sky? Answer in one word:",
            session: session
        )
        let response2: String = try await generateResponseForPrompt(
            "The number after one is",
            session: session
        )

        validateMultiTurnResponses(response1: response1, response2: response2)
        await session.unload()
    }

    private func generateResponseForPrompt(_ prompt: String, session: LLMSession) async throws -> String {
        let input: LLMInput = LLMInput(
            context: prompt,
            sampling: SamplingParameters(
                temperature: 0.0,
                topP: 1.0,
                topK: 1
            ),
            limits: ResourceLimits(maxTokens: TestConstants.multiTurnMaxTokens)
        )

        var response: String = ""
        let stream: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)

        for try await chunk in stream {
            if case .text = chunk.event {
                response += chunk.text
            }
        }

        return response
    }

    private func validateMultiTurnResponses(response1: String, response2: String) {
        #expect(
            !response1.isEmpty,
            "First response should generate text"
        )
        #expect(
            !response2.isEmpty,
            "Second response should generate text"
        )
        #expect(
            response1 != response2,
            "Different prompts should produce different responses"
        )
    }
}

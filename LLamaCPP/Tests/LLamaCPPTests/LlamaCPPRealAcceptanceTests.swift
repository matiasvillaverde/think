import Abstractions
import Foundation
@testable import LLamaCPP
import Testing

/// Real acceptance tests with actual string assertions using the BF16 model
extension LlamaCPPModelTestSuite {
    // MARK: - Test Constants
    private enum TestConstants {
        static let seedForDeterministic: Int = 12_345
        static let seedForStandardTest: Int = 42
        static let maxTokensForCompletion: Int = 3
        static let maxTokensForSimpleTest: Int = 5
    }

    @Test("LLMSession generates expected response for Hello")
    internal func testLLMSessionHelloResponse() async throws {
        let configuration: ProviderConfiguration = try TestHelpers.createAcceptanceTestConfiguration()
        // Use the protocol type, not the concrete implementation
        let session: LLMSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        for try await _ in preloadStream {
            // Just consume the progress updates
        }

        let input: LLMInput = LLMInput(
            context: "Hello",
            sampling: SamplingParameters(
                temperature: 0.0,  // Deterministic
                topP: 1.0,
                topK: 1,
                seed: TestConstants.seedForStandardTest
            ),
            limits: ResourceLimits(maxTokens: TestConstants.maxTokensForSimpleTest)
        )

        var generatedText: String = ""
        let stream: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)

        for try await chunk in stream {
            if case .text = chunk.event {
                generatedText += chunk.text
            }
        }

        let trimmed: String = generatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(
            !trimmed.isEmpty,
            "Should generate a non-empty response for Hello, got: '\(generatedText)'"
        )

        await session.unload()
    }

    @Test("LLMSession generates deterministic output with seed")
    internal func testDeterministicGenerationWithSeed() async throws {
        let configuration: ProviderConfiguration = try TestHelpers.createAcceptanceTestConfiguration()
        let session: LLMSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        for try await _ in preloadStream {
            // Just consume the progress updates
        }

        let input: LLMInput = LLMInput(
            context: "Once upon a time",
            sampling: SamplingParameters(
                temperature: 0.0,
                topP: 1.0,
                topK: 1,
                seed: TestConstants.seedForDeterministic
            ),
            limits: ResourceLimits(maxTokens: 8)
        )

        // First generation
        var firstGen: String = ""
        let stream1: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)
        for try await chunk in stream1 {
            if case .text = chunk.event {
                firstGen += chunk.text
            }
        }

        // Second generation with same seed
        var secondGen: String = ""
        let stream2: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)
        for try await chunk in stream2 {
            if case .text = chunk.event {
                secondGen += chunk.text
            }
        }

        #expect(
            firstGen == secondGen,
            """
            Deterministic generation should produce identical results
            First: '\(firstGen)'
            Second: '\(secondGen)'
            """
        )

        #expect(
            !firstGen.isEmpty,
            "Should generate non-empty text"
        )

        await session.unload()
    }

    @Test("LLMSession completes simple prompts correctly")
    internal func testSimplePromptCompletion() async throws {
        let configuration: ProviderConfiguration = try TestHelpers.createAcceptanceTestConfiguration()
        let session: LLMSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        for try await _ in preloadStream {
            // Just consume the progress updates
        }

        let testCases: [TestCase] = Self.createSimplePromptTestCases()

        for testCase in testCases {
            try await Self.validatePromptResponse(testCase, session: session)
        }

        await session.unload()
    }

    private struct TestCase {
        let prompt: String
        let maxTokens: Int
        let mustContain: String?
    }

    private static func createSimplePromptTestCases() -> [TestCase] {
        [
            TestCase(
                prompt: "The number 1 plus 1 equals",
                maxTokens: TestConstants.maxTokensForCompletion,
                mustContain: "2"
            ),
            TestCase(
                prompt: "Hello, my name is",
                maxTokens: TestConstants.maxTokensForSimpleTest,
                mustContain: nil
            ),
            TestCase(
                prompt: "The color of the sky is",
                maxTokens: TestConstants.maxTokensForCompletion,
                mustContain: nil
            ),
            TestCase(
                prompt: "One, two, three,",
                maxTokens: TestConstants.maxTokensForCompletion,
                mustContain: "four"
            )
        ]
    }

    private static func validatePromptResponse(_ testCase: TestCase, session: LLMSession) async throws {
        let input: LLMInput = LLMInput(
            context: testCase.prompt,
            sampling: SamplingParameters(temperature: 0.0, topP: 1.0, topK: 1),
            limits: ResourceLimits(maxTokens: testCase.maxTokens)
        )

        var generated: String = ""
        let stream: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)

        for try await chunk in stream {
            if case .text = chunk.event {
                generated += chunk.text
            }
        }

        #expect(!generated.isEmpty, "Should generate text for prompt: '\(testCase.prompt)'")

        if let expected = testCase.mustContain {
            #expect(
                generated.lowercased().contains(expected.lowercased()),
                "Response to '\(testCase.prompt)' should contain '\(expected)', got: '\(generated)'"
            )
        }
    }

    @Test("LLMSession respects max tokens limit in acceptance")
    internal func testMaxTokensLimitAcceptance() async throws {
        let configuration: ProviderConfiguration = try TestHelpers.createAcceptanceTestConfiguration()
        let session: LLMSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        for try await _ in preloadStream {
            // Just consume the progress updates
        }

        let maxTokens: Int = 3
        let input: LLMInput = LLMInput(
            context: "Tell me a very long story about",
            sampling: SamplingParameters(
                temperature: 0.5,
                topP: 0.9
            ),
            limits: ResourceLimits(maxTokens: maxTokens)
        )

        var tokenCount: Int = 0
        let stream: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)

        for try await chunk in stream {
            if case .text = chunk.event {
                tokenCount += 1
            }
        }

        #expect(
            tokenCount == maxTokens,
            "Should generate exactly \(maxTokens) tokens, got \(tokenCount)"
        )

        await session.unload()
    }

    @Test("LLMSession provides valid metrics")
    internal func testMetricsValidity() async throws {
        let configuration: ProviderConfiguration = try TestHelpers.createAcceptanceTestConfiguration()
        let session: LLMSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        for try await _ in preloadStream {
            // Just consume the progress updates
        }

        let (lastMetrics, generatedTokens): (ChunkMetrics?, Int) =
            try await Self.collectMetricsFromSession(session)

        Self.validateUsageMetrics(lastMetrics, expectedGeneratedTokens: generatedTokens)
        Self.validateTimingMetrics(lastMetrics)

        await session.unload()
    }

    private static func collectMetricsFromSession(
        _ session: LLMSession
    ) async throws -> (ChunkMetrics?, Int) {
        let input: LLMInput = LLMInput(
            context: "Test",
            sampling: SamplingParameters(temperature: 0.0, topP: 1.0),
            limits: ResourceLimits(maxTokens: TestConstants.maxTokensForCompletion)
        )

        var lastMetrics: ChunkMetrics?
        var generatedTokens: Int = 0
        let stream: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)

        for try await chunk in stream {
            if case .text = chunk.event {
                generatedTokens += 1
                lastMetrics = chunk.metrics
            }
        }

        return (lastMetrics, generatedTokens)
    }

    private static func validateUsageMetrics(_ lastMetrics: ChunkMetrics?, expectedGeneratedTokens: Int) {
        #expect(lastMetrics != nil, "Should have metrics")

        if let metrics = lastMetrics, let usage = metrics.usage {
            #expect(
                usage.generatedTokens == expectedGeneratedTokens,
                """
                Metrics should report \(expectedGeneratedTokens) generated tokens,
                got \(usage.generatedTokens)
                """
            )
            #expect(
                usage.totalTokens > expectedGeneratedTokens,
                "Total tokens should include prompt tokens"
            )
        }
    }

    private static func validateTimingMetrics(_ lastMetrics: ChunkMetrics?) {
        if let metrics = lastMetrics, let timing = metrics.timing {
            #expect(timing.totalTime > Duration.zero, "Should have positive total time")

            if let ttft = timing.timeToFirstToken {
                #expect(
                    ttft >= Duration.zero && ttft < timing.totalTime,
                    "TTFT should be between 0 and total time"
                )
            }
        }
    }
}

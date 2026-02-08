import Abstractions
import Foundation
@testable import LLamaCPP
import Testing

/// Acceptance tests for comprehensive metrics collection
extension LlamaCPPModelTestSuite {
    // MARK: - Test Constants
    private enum TestConstants {
        static let detailedMetricsMaxTokens: Int = 5
        static let medianPercentile: Double = 0.5
        static let p95Percentile: Double = 0.95
        static let deterministicTemperature: Double = 0.0
    }

    // MARK: - Detailed Metrics Collection Tests

    @Test("Detailed metrics collection when flag is enabled")
    internal func testDetailedMetricsCollection() async throws {
        let configuration: ProviderConfiguration = try TestHelpers.createTestConfiguration()
        let session: LlamaCPPSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        for try await _ in preloadStream {
            // Just consume the progress updates
        }

        let input: LLMInput = createDetailedMetricsInput()
        let stream: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)
        let chunks: [LLMStreamChunk] = try await TestHelpers.collectChunks(from: stream, limit: 20)

        let finishedChunk: LLMStreamChunk? = findFinishedChunk(in: chunks)
        #expect(finishedChunk != nil, "Should have a finished chunk")

        if let metrics = finishedChunk?.metrics {
            verifyDetailedMetrics(metrics)
        }

        await session.unload()
    }

    private func createDetailedMetricsInput() -> LLMInput {
        LLMInput(
            context: "The quick brown fox",
            sampling: SamplingParameters(temperature: 0.0, topP: 1.0),
            limits: ResourceLimits(
                maxTokens: TestConstants.detailedMetricsMaxTokens,
                collectDetailedMetrics: true  // Enable detailed collection
            )
        )
    }

    private func findFinishedChunk(in chunks: [LLMStreamChunk]) -> LLMStreamChunk? {
        chunks.first { chunk in
            if case .finished = chunk.event {
                true
            } else {
                false
            }
        }
    }

    private func verifyDetailedMetrics(_ metrics: ChunkMetrics) {
        verifyTimingMetrics(metrics.timing)
        verifyUsageMetrics(metrics.usage)
        verifyGenerationMetrics(metrics.generation)
    }

    private func verifyTimingMetrics(_ timing: TimingMetrics?) {
        #expect(timing != nil, "Should have timing metrics")
        if let timing {
            #expect(timing.totalTime > Duration.zero, "Total time should be positive")
            #expect(timing.timeToFirstToken != nil, "Should track time to first token")
            #expect(!timing.tokenTimings.isEmpty, "Should have individual token timings")

            let p50: Duration? = timing.percentile(TestConstants.medianPercentile)
            let p95: Duration? = timing.percentile(TestConstants.p95Percentile)
            #expect(p50 != nil, "Should calculate median")
            #expect(p95 != nil, "Should calculate 95th percentile")
        }
    }

    private func verifyUsageMetrics(_ usage: UsageMetrics?) {
        #expect(usage != nil, "Should have usage metrics")
        if let usage {
            #expect(
                usage.generatedTokens == TestConstants.detailedMetricsMaxTokens,
                "Should generate exactly \(TestConstants.detailedMetricsMaxTokens) tokens"
            )
            if let promptTokens = usage.promptTokens {
                #expect(promptTokens > 0, "Should have prompt tokens")
                #expect(
                    usage.totalTokens == promptTokens + TestConstants.detailedMetricsMaxTokens,
                    "Total should be prompt + generated"
                )
            } else {
                Issue.record("Prompt tokens should not be nil")
            }
        }
    }

    private func verifyGenerationMetrics(_ generation: GenerationMetrics?) {
        #expect(generation != nil, "Should have generation metrics with detailed flag")
        if let generation {
            #expect(generation.stopReason != nil, "Should record stop reason")
            #expect(
                generation.temperature == Float32(TestConstants.deterministicTemperature),
                "Should record temperature"
            )
        }
    }

    @Test("Minimal metrics collection when flag is disabled")
    internal func testMinimalMetricsCollection() async throws {
        let configuration: ProviderConfiguration = try TestHelpers.createTestConfiguration()
        let session: LlamaCPPSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        for try await _ in preloadStream {
            // Just consume the progress updates
        }

        // Disable detailed metrics collection
        let input: LLMInput = LLMInput(
            context: "Hello",
            sampling: SamplingParameters(temperature: 0.5, topP: 0.95),
            limits: ResourceLimits(
                maxTokens: 3,
                collectDetailedMetrics: false  // Disable detailed collection
            )
        )

        let stream: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)
        let chunks: [LLMStreamChunk] = try await TestHelpers.collectChunks(from: stream, limit: 10)

        let finishedChunk: LLMStreamChunk? = chunks.first { chunk in
            if case .finished = chunk.event {
                return true
            }
            return false
        }

        #expect(finishedChunk != nil, "Should have a finished chunk")

        if let metrics = finishedChunk?.metrics {
            // Should still have basic metrics
            #expect(metrics.timing != nil, "Should have timing metrics")
            #expect(metrics.usage != nil, "Should have usage metrics")

            if let timing = metrics.timing {
                // Should have essential timing but not detailed token timings
                #expect(timing.totalTime > Duration.zero, "Should have total time")
                #expect(timing.tokenTimings.isEmpty, "Should not have individual token timings")
            }

            // Generation metrics might be minimal
            if let generation = metrics.generation {
                #expect(generation.stopReason != nil, "Should still record stop reason")
                // Token details should be empty
                #expect(generation.tokens.isEmpty, "Should not have detailed token info")
            }
        }

        await session.unload()
    }

    // MARK: - Prompt Processing Metrics Tests

    @Test("Prompt processing time is tracked correctly")
    internal func testPromptProcessingMetrics() async throws {
        let configuration: ProviderConfiguration = try TestHelpers.createTestConfiguration()
        let session: LlamaCPPSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        for try await _ in preloadStream {
            // Just consume the progress updates
        }

        // Use a longer prompt to ensure measurable processing time
        let longPrompt: String = """
            Once upon a time in a land far, far away, there lived a wise old wizard \
            who possessed great knowledge of the ancient arts. He spent his days \
            studying mystical texts and brewing powerful potions.
            """

        let input: LLMInput = LLMInput(
            context: longPrompt,
            sampling: SamplingParameters(temperature: 0.0, topP: 1.0),
            limits: ResourceLimits(
                maxTokens: 2,
                collectDetailedMetrics: true
            )
        )

        let stream: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)
        let chunks: [LLMStreamChunk] = try await TestHelpers.collectChunks(from: stream, limit: 10)

        let finishedChunk: LLMStreamChunk? = chunks.first { chunk in
            if case .finished = chunk.event {
                return true
            }
            return false
        }

        if let timing = finishedChunk?.metrics?.timing {
            #expect(timing.promptProcessingTime != nil, "Should track prompt processing time")
            if let promptTime = timing.promptProcessingTime {
                #expect(promptTime >= Duration.zero, "Prompt processing time should be non-negative")
            }
        }

        await session.unload()
    }

    // MARK: - Context Window Metrics Tests

    @Test("Context window information is tracked")
    internal func testContextWindowMetrics() async throws {
        let modelPath: String = try TestHelpers.requireTestModelPath()
        let configuration: ProviderConfiguration = ProviderConfiguration(
            location: URL(fileURLWithPath: modelPath),
            authentication: .noAuth,
            modelName: "test-model",
            compute: ComputeConfiguration(
                contextSize: 2_048,  // Specific context size
                batchSize: 512,
                threadCount: 4
            )
        )
        let session: LlamaCPPSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        for try await _ in preloadStream {
            // Just consume the progress updates
        }

        let input: LLMInput = LLMInput(
            context: "Test context",
            sampling: SamplingParameters(temperature: 0.0, topP: 1.0),
            limits: ResourceLimits(
                maxTokens: 2,
                collectDetailedMetrics: true
            )
        )

        let stream: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)
        let chunks: [LLMStreamChunk] = try await TestHelpers.collectChunks(from: stream, limit: 10)

        let finishedChunk: LLMStreamChunk? = chunks.first { chunk in
            if case .finished = chunk.event {
                return true
            }
            return false
        }

        if let usage = finishedChunk?.metrics?.usage {
            #expect(usage.contextWindowSize == 2_048, "Should report context window size")
            #expect(usage.contextTokensUsed != nil, "Should track tokens used in context")
            if let tokensUsed = usage.contextTokensUsed {
                #expect(tokensUsed > 0, "Should have used some context tokens")
                #expect(tokensUsed <= 2_048, "Should not exceed context window")
            }
        }

        await session.unload()
    }

    // MARK: - Stop Reason Metrics Tests

    @Test("Stop reason is correctly identified for max tokens")
    internal func testStopReasonMaxTokens() async throws {
        let configuration: ProviderConfiguration = try TestHelpers.createTestConfiguration()
        let session: LlamaCPPSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        for try await _ in preloadStream {
            // Just consume the progress updates
        }

        let input: LLMInput = LLMInput(
            context: "Count from one to one hundred:",
            sampling: SamplingParameters(temperature: 0.0, topP: 1.0),
            limits: ResourceLimits(
                maxTokens: 3,
                collectDetailedMetrics: true
            )
        )

        let stream: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)
        let chunks: [LLMStreamChunk] = try await TestHelpers.collectChunks(from: stream, limit: 10)

        let finishedChunk: LLMStreamChunk? = chunks.first { chunk in
            if case .finished = chunk.event {
                return true
            }
            return false
        }

        if let generation = finishedChunk?.metrics?.generation {
            #expect(
                generation.stopReason == .maxTokens,
                "Should stop due to max tokens, got \(String(describing: generation.stopReason))"
            )
        }

        await session.unload()
    }

    @Test("Stop reason is correctly identified for stop sequence")
    internal func testStopReasonStopSequence() async throws {
        let configuration: ProviderConfiguration = try TestHelpers.createTestConfiguration()
        let session: LlamaCPPSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        for try await _ in preloadStream {
            // Just consume the progress updates
        }

        let input: LLMInput = LLMInput(
            context: "Write a sentence",
            sampling: SamplingParameters(
                temperature: 0.7,
                topP: 0.9,
                stopSequences: [".", "!", "?"]  // Stop on punctuation
            ),
            limits: ResourceLimits(
                maxTokens: 50,
                collectDetailedMetrics: true
            )
        )

        let stream: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)
        let chunks: [LLMStreamChunk] = try await TestHelpers.collectChunks(from: stream, limit: 60)

        let finishedChunk: LLMStreamChunk? = chunks.first { chunk in
            if case .finished = chunk.event {
                return true
            }
            return false
        }

        if let generation = finishedChunk?.metrics?.generation {
            let validStopReasons: Set<GenerationMetrics.StopReason> = [
                .stopSequence,
                .endOfSequence,
                .maxTokens
            ]
            #expect(
                generation.stopReason.map { validStopReasons.contains($0) } ?? false,
                "Should have a valid stop reason, got \(String(describing: generation.stopReason))"
            )
        }

        await session.unload()
    }

    // MARK: - Performance Metrics Tests

    @Test("Tokens per second calculation is accurate")
    internal func testTokensPerSecondCalculation() async throws {
        let configuration: ProviderConfiguration = try TestHelpers.createTestConfiguration()
        let session: LlamaCPPSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        for try await _ in preloadStream {
            // Just consume the progress updates
        }

        let input: LLMInput = LLMInput(
            context: "Hello",
            sampling: SamplingParameters(temperature: 0.0, topP: 1.0),
            limits: ResourceLimits(
                maxTokens: 10,
                collectDetailedMetrics: false  // Don't need detailed for TPS
            )
        )

        let stream: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)
        let chunks: [LLMStreamChunk] = try await TestHelpers.collectChunks(from: stream, limit: 20)

        let finishedChunk: LLMStreamChunk? = chunks.first { chunk in
            if case .finished = chunk.event {
                return true
            }
            return false
        }

        if let metrics = finishedChunk?.metrics,
            let timing = metrics.timing,
            let usage = metrics.usage {
            // When not collecting detailed metrics, use the external token count method
            let tps: Double? = timing.tokensPerSecond(tokenCount: usage.generatedTokens)
            #expect(tps != nil, "Should calculate tokens per second")
            if let tps {
                #expect(tps > 0, "Tokens per second should be positive")
            }

            // Verify the calculation is correct
            let totalSeconds: Double = Double(timing.totalTime.components.seconds) +
                Double(timing.totalTime.components.attoseconds) / 1e18
            if totalSeconds > 0 {
                let expectedTPS: Double = Double(usage.generatedTokens) / totalSeconds
                if let actualTPS = tps {
                    let difference: Double = abs(actualTPS - expectedTPS)
                    #expect(
                        difference < 1.0,
                        "TPS calculation should be accurate (expected ~\(expectedTPS), got \(actualTPS))"
                    )
                }
            }
        }

        await session.unload()
    }
}

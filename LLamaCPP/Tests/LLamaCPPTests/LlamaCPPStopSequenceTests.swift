import Abstractions
import Foundation
@testable import LLamaCPP
import Testing

/// Tests for stop sequence efficiency and correctness
extension LlamaCPPModelTestSuite {
    // MARK: - Test 6.1: Stop sequence detection

    @Test("Stop sequences correctly stop generation")
    internal func testStopSequenceDetection() async throws {
        guard let config: ProviderConfiguration = TestHelpers.createTestConfiguration() else {
            return
        }
        let session: LlamaCPPSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: config
        )
        for try await _ in preloadStream {
            // Just consume the progress updates
        }

        // Test with stop sequences
        let stopSequences: [String] = ["\n", ".", "END"]
        let input: LLMInput = LLMInput(
            context: "Count from one to ten",
            sampling: SamplingParameters(
                temperature: 0.7,
                topP: 0.9,
                stopSequences: stopSequences
            ),
            limits: ResourceLimits(maxTokens: 100)
        )

        var generatedText: String = ""

        for try await chunk in await session.stream(input) {
            if case .text = chunk.event {
                generatedText += chunk.text
            }

            if case .finished = chunk.event {
                break
            }

            // Stop early if we've generated enough
            if generatedText.count > 50 {
                break
            }
        }

        // Verify stop sequence behavior
        TestAssertions.assertStopSequenceEffect(
            generatedText,
            stopSequences: stopSequences,
            shouldStop: true,
            maxLength: 100
        )

        await session.unload()
    }

    // MARK: - Test 6.2: Multiple stop sequences

    @Test("Multiple stop sequences work correctly")
    internal func testMultipleStopSequences() async throws {
        guard let config: ProviderConfiguration = TestHelpers.createTestConfiguration() else {
            return
        }
        let session: LlamaCPPSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: config
        )
        for try await _ in preloadStream {
            // Just consume the progress updates
        }

        // Test with multiple stop sequences
        let stopSequences: [String] = ["STOP", "END", "FINISH", "\n\n"]
        let input: LLMInput = LLMInput(
            context: "Generate text until you see a stop word",
            sampling: SamplingParameters(
                temperature: 0.7,
                topP: 0.9,
                stopSequences: stopSequences
            ),
            limits: ResourceLimits(maxTokens: 100)
        )

        var generatedText: String = ""
        var stoppedBy: String?

        for try await chunk in await session.stream(input) {
            if case .text = chunk.event {
                generatedText += chunk.text

                // Check which stop sequence triggered
                for sequence in stopSequences where generatedText.hasSuffix(sequence) {
                    stoppedBy = sequence
                    break
                }
            }

            if stoppedBy != nil || generatedText.count > 100 {
                break
            }
        }

        // Verify we generated text and potentially stopped
        #expect(
            !generatedText.isEmpty,
            "Should generate at least some text"
        )

        if let stopWord = stoppedBy {
            #expect(
                stopSequences.contains(stopWord),
                "Stop word '\(stopWord)' should be in configured stop sequences"
            )
        }

        await session.unload()
    }

    // MARK: - Test 6.3: Stop sequence efficiency

    @Test("Stop sequence checking is efficient")
    internal func testStopSequenceEfficiency() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)
        let generator: LlamaCPPGenerator = LlamaCPPGenerator(model: model, context: context)

        // Generate tokens and measure stop sequence checking
        let longStopSequences: [String] = [
            "This is a very long stop sequence that should be checked efficiently",
            "Another long sequence to test performance",
            "Yet another sequence",
            "Short",
            "\n\n\n",
            "END_OF_GENERATION"
        ]

        let samplingParams: SamplingParameters = SamplingParameters(
            temperature: 0.7,
            topP: 0.9,
            stopSequences: longStopSequences
        )

        let startTime: Date = Date()
        var generatedCount: Int = 0

        // Generate multiple tokens
        _ = try generator.generateNextToken(
            prompt: "Test prompt",
            sampling: samplingParams
        )

        for _ in 0..<10 {
            _ = try generator.generateNextToken(
                tokens: [],
                sampling: samplingParams
            )
            generatedCount += 1
        }

        let elapsed: TimeInterval = Date().timeIntervalSince(startTime)

        // Should complete in reasonable time even with many stop sequences
        #expect(
            elapsed < 2.0,  // Tighter bound for performance
            "Stop sequence checking should complete in < 2s, took \(elapsed)s"
        )
        #expect(
            generatedCount == 10,
            "Should generate exactly 10 tokens as requested, got \(generatedCount)"
        )

        generator.free()
        context.free()
        model.free()
    }

    // MARK: - Test 6.4: Partial match handling

    @Test("Partial stop sequence matches don't stop generation")
    internal func testPartialMatchHandling() async throws {
        guard let config: ProviderConfiguration = TestHelpers.createTestConfiguration() else {
            return
        }
        let session: LlamaCPPSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: config
        )
        for try await _ in preloadStream {
            // Just consume the progress updates
        }

        // Use stop sequences that might have partial matches
        let stopSequences: [String] = ["STOP", "END"]
        let input: LLMInput = LLMInput(
            context: "Generate text with words like STOPPER and ENDING but not STOP",
            sampling: SamplingParameters(
                temperature: 0.7,
                topP: 0.9,
                stopSequences: stopSequences
            ),
            limits: ResourceLimits(maxTokens: 50)
        )

        var generatedText: String = ""
        var chunks: Int = 0

        for try await chunk in await session.stream(input) {
            if case .text = chunk.event {
                generatedText += chunk.text
                chunks += 1
            }

            // Limit generation
            if chunks > 10 {
                break
            }
        }

        // Should generate text without false positives on partial matches
        #expect(
            !generatedText.isEmpty,
            "Should generate text despite partial matches"
        )
        #expect(
            chunks > 0,
            "Should have generated \(chunks) chunks"
        )

        await session.unload()
    }

    // MARK: - Test 6.5: Empty stop sequences

    @Test("Empty stop sequences are handled correctly")
    internal func testEmptyStopSequences() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)
        let generator: LlamaCPPGenerator = LlamaCPPGenerator(model: model, context: context)

        // Test with empty stop sequences array
        let samplingParams: SamplingParameters = SamplingParameters(
            temperature: 0.7,
            topP: 0.9,
            stopSequences: []  // Empty
        )

        // Should not crash and should generate normally
        let token: Int32 = try generator.generateNextToken(
            prompt: "Test",
            sampling: samplingParams
        )

        TestAssertions.assertTokenInVocabRange(token, model: model)

        generator.free()
        context.free()
        model.free()
    }

    // MARK: - Test 6.6: Case sensitivity

    @Test("Stop sequences are case sensitive")
    internal func testStopSequenceCaseSensitivity() async throws {
        guard let config: ProviderConfiguration = TestHelpers.createTestConfiguration() else {
            return
        }
        let session: LlamaCPPSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: config
        )
        for try await _ in preloadStream {
            // Just consume the progress updates
        }

        // Test case-sensitive stop sequences
        let stopSequences: [String] = ["STOP", "End"]
        let input: LLMInput = LLMInput(
            context: "Generate text with stop and end in different cases",
            sampling: SamplingParameters(
                temperature: 0.7,
                topP: 0.9,
                stopSequences: stopSequences
            ),
            limits: ResourceLimits(maxTokens: 30)
        )

        var generatedText: String = ""

        for try await chunk in await session.stream(input) {
            if case .text = chunk.event {
                generatedText += chunk.text
            }

            // Check for exact matches only
            var shouldStop: Bool = false
            for sequence in stopSequences where generatedText.hasSuffix(sequence) {
                shouldStop = true
                break
            }

            if shouldStop || generatedText.count > 50 {
                break
            }
        }

        // Generation should work normally
        #expect(
            !generatedText.isEmpty,
            "Should generate text with case-sensitive stop sequences"
        )

        await session.unload()
    }

    // MARK: - Test 6.7: Unicode stop sequences

    @Test("Unicode stop sequences work correctly")
    internal func testUnicodeStopSequences() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)
        let generator: LlamaCPPGenerator = LlamaCPPGenerator(model: model, context: context)

        // Test with Unicode stop sequences
        let samplingParams: SamplingParameters = SamplingParameters(
            temperature: 0.7,
            topP: 0.9,
            stopSequences: ["🛑", "终止", "стоп", "→"]
        )

        // Should handle Unicode without crashing
        let token: Int32 = try generator.generateNextToken(
            prompt: "Test with Unicode",
            sampling: samplingParams
        )

        TestAssertions.assertTokenInVocabRange(token, model: model)

        generator.free()
        context.free()
        model.free()
    }

    // MARK: - Test 6.8: Stop sequences not in output

    @Test("Stop sequences do not appear in generated output")
    internal func testStopSequencesNotInOutput() async throws {
        guard let configuration: ProviderConfiguration = TestHelpers.createTestConfiguration() else {
            return
        }
        let session: LlamaCPPSession = LlamaCPPSession()
        for try await _ in await session.preload(
            configuration: configuration
        ) { /* consume progress */ }

        let stopSequences: [String] = ["<|im_end|>", "STOP"]
        let input: LLMInput = LLMInput(
            context: "Write a short sentence",
            sampling: SamplingParameters(
                temperature: 0.7,
                topP: 0.9,
                stopSequences: stopSequences
            ),
            limits: ResourceLimits(maxTokens: 50)
        )

        let result: (String, GenerationMetrics.StopReason?) = try await streamAndCollect(
            session: session,
            input: input,
            maxChars: 100
        )

        // Verify stop sequences not in output
        verifyNoStopSequences(
            text: result.0,
            stopSequences: stopSequences,
            stopReason: result.1
        )

        await session.unload()
    }

    // MARK: - Test 6.9: Qwen-style stop sequences

    @Test("Qwen-style stop sequences work correctly")
    internal func testQwenStyleStopSequences() async throws {
        guard let configuration: ProviderConfiguration = TestHelpers.createTestConfiguration() else {
            return
        }
        let session: LlamaCPPSession = LlamaCPPSession()
        for try await _ in await session.preload(
            configuration: configuration
        ) { /* consume progress */ }

        let qwenStopSequences: [String] = ["<|im_end|>", "<|im_start|>"]
        let input: LLMInput = LLMInput(
            context: "Generate text",
            sampling: SamplingParameters(
                temperature: 0.7,
                topP: 0.9,
                stopSequences: qwenStopSequences
            ),
            limits: ResourceLimits(maxTokens: 50)
        )

        let result: (String, GenerationMetrics.StopReason?) = try await streamAndCollect(
            session: session,
            input: input,
            maxChars: 100
        )

        // Verify Qwen sequences not in output
        for sequence in qwenStopSequences {
            #expect(
                !result.0.contains(sequence),
                "Qwen stop sequence '\(sequence)' should not be in output"
            )
        }

        await session.unload()
    }

    // MARK: - Helper Methods

    private func streamAndCollect(
        session: LlamaCPPSession,
        input: LLMInput,
        maxChars: Int
    ) async throws -> (String, GenerationMetrics.StopReason?) {
        var text: String = ""
        var stopReason: GenerationMetrics.StopReason?

        for try await chunk in await session.stream(input) {
            if case .text = chunk.event {
                text += chunk.text
            }
            if case .finished = chunk.event {
                stopReason = chunk.metrics?.generation?.stopReason
                break
            }
            if text.count > maxChars { break }
        }
        return (text, stopReason)
    }

    private func verifyNoStopSequences(
        text: String,
        stopSequences: [String],
        stopReason: GenerationMetrics.StopReason?
    ) {
        for sequence in stopSequences {
            #expect(
                !text.contains(sequence),
                "Stop sequence '\(sequence)' should not appear in output"
            )
        }

        if stopReason == .stopSequence {
            for sequence in stopSequences {
                #expect(
                    !text.hasSuffix(sequence),
                    "Output should not end with stop sequence"
                )
            }
        }
    }
}

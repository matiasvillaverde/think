import Abstractions
import Foundation
@testable import LLamaCPP
import Testing

/// Custom assertion helpers for LlamaCPP tests with specific expected values
internal enum TestAssertions {
    // MARK: - Model Assertions
    internal static func assertTokenInVocabRange(
        _ token: Int32,
        model: LlamaCPPModel,
        file _: StaticString = #file,
        line _: UInt = #line
    ) {
        ModelAssertions.assertTokenInVocabRange(token, model: model)
    }

    internal static func assertTestModelMetadata(
        _ model: LlamaCPPModel,
        expectedVocabSize: Int32 = 151_936,
        expectedContextLength: Int32 = 40_960,
        expectedEmbeddingSize: Int32 = 1_024,
        file _: StaticString = #file,
        line _: UInt = #line
    ) {
        ModelAssertions.assertTestModelMetadata(
            model,
            expectedVocabSize: expectedVocabSize,
            expectedContextLength: expectedContextLength,
            expectedEmbeddingSize: expectedEmbeddingSize
        )
    }

    // MARK: - Chunk Assertions
    /// Assert that a chunk has expected event type and content
    internal static func assertChunkEvent(
        _ chunk: LLMStreamChunk,
        expectedEvent: StreamEvent,
        expectedTextLength: Int? = nil,
        file _: StaticString = #file,
        line _: UInt = #line
    ) {
        switch (chunk.event, expectedEvent) {
        case (.text, .text):
            #expect(true, "Event type matches: text")
            if let expectedLength = expectedTextLength {
                #expect(
                    chunk.text.count == expectedLength,
                    "Text length should be \(expectedLength), got \(chunk.text.count)"
                )
            }

        case (.finished, .finished):
            #expect(true, "Event type matches: finished")

        case let (.error(actual), .error(expected)):
            #expect(
                actual.localizedDescription == expected.localizedDescription,
                "Error should match expected: \(expected)"
            )

        default:
            Issue.record("Event type mismatch: expected \(expectedEvent), got \(chunk.event)")
        }
    }

    /// Assert chunks array matches expected pattern
    internal static func assertChunkSequence(
        _ chunks: [LLMStreamChunk],
        expectedTextChunks: Int,
        expectedTotalChunks: Int? = nil,
        hasFinishedEvent: Bool = true,
        file _: StaticString = #file,
        line _: UInt = #line
    ) {
        assertTextChunkCount(chunks, expected: expectedTextChunks)

        if let total = expectedTotalChunks {
            assertTotalChunkCount(chunks, expected: total)
        }

        if hasFinishedEvent {
            assertFinishedEvent(chunks)
        }
    }

    private static func assertTextChunkCount(
        _ chunks: [LLMStreamChunk],
        expected: Int
    ) {
        let textChunks: [LLMStreamChunk] = chunks.filter { chunk in
            if case .text = chunk.event {
                return true
            }
            return false
        }
        #expect(
            textChunks.count == expected,
            "Should have exactly \(expected) text chunks, got \(textChunks.count)"
        )
    }

    private static func assertTotalChunkCount(
        _ chunks: [LLMStreamChunk],
        expected: Int
    ) {
        #expect(
            chunks.count == expected,
            "Should have exactly \(expected) total chunks, got \(chunks.count)"
        )
    }

    private static func assertFinishedEvent(
        _ chunks: [LLMStreamChunk]
    ) {
        let finishedChunks: [LLMStreamChunk] = chunks.filter { chunk in
            if case .finished = chunk.event {
                return true
            }
            return false
        }
        #expect(
            finishedChunks.count == 1,
            "Should have exactly 1 finished event, got \(finishedChunks.count)"
        )
    }

    // MARK: - Metrics Assertions
    internal static func assertMetrics(
        _ metrics: ChunkMetrics?,
        expectedGeneratedTokens: Int? = nil,
        expectedPromptTokens: Int? = nil,
        hasTimingMetrics: Bool = true,
        file _: StaticString = #file,
        line _: UInt = #line
    ) {
        MetricsAssertions.assertMetrics(
            metrics,
            expectedGeneratedTokens: expectedGeneratedTokens,
            expectedPromptTokens: expectedPromptTokens,
            hasTimingMetrics: hasTimingMetrics
        )
    }

    // MARK: - Tokenization Assertions
    internal static func assertTokenization(
        _ tokens: [Int32],
        expectedCount: Int? = nil,
        expectedFirstToken: Int32? = nil,
        maxCount: Int = 100,
        file _: StaticString = #file,
        line _: UInt = #line
    ) {
        TokenizationAssertions.assertTokenization(
            tokens,
            expectedCount: expectedCount,
            expectedFirstToken: expectedFirstToken,
            maxCount: maxCount
        )
    }

    // MARK: - Error Assertions
    /// Assert that an expression throws a specific LLMError case
    internal static func assertThrowsLLMError<T>(
        _ expression: () async throws -> T,
        expectedError: LLMError,
        file _: StaticString = #file,
        line _: UInt = #line
    ) async {
        do {
            _ = try await expression()
            Issue.record("Expected to throw \(expectedError), but no error was thrown")
        } catch {
            assertLLMError(error, expected: expectedError)
        }
    }

    private static func assertLLMError(_ error: Error, expected: LLMError) {
        guard let llmError = error as? LLMError else {
            Issue.record("Expected LLMError, got \(type(of: error)): \(error)")
            return
        }

        assertLLMErrorCase(llmError, expected: expected)
    }

    private static func assertLLMErrorCase(_ llmError: LLMError, expected: LLMError) {
        switch (llmError, expected) {
        case let (.modelNotFound(actualPath), .modelNotFound(expectedPath)):
            #expect(
                actualPath == expectedPath,
                "Model path mismatch: expected \(expectedPath), got \(actualPath)"
            )

        case let (.invalidConfiguration(actualMsg), .invalidConfiguration(expectedMsg)):
            #expect(
                actualMsg == expectedMsg,
                "Config message mismatch: expected \(expectedMsg), got \(actualMsg)"
            )

        case let (.providerError(actualCode, _), .providerError(expectedCode, _)):
            #expect(
                actualCode == expectedCode,
                "Error code mismatch: expected \(expectedCode), got \(actualCode)"
            )

        default:
            Issue.record("Error case mismatch: expected \(expected), got \(llmError)")
        }
    }

    // MARK: - Sampling Assertions
    /// Assert that sampling parameters produce deterministic results
    internal static func assertDeterministicGeneration(
        _ token1: Int32,
        _ token2: Int32,
        message: String = "Deterministic sampling should produce identical tokens",
        file _: StaticString = #file,
        line _: UInt = #line
    ) {
        #expect(
            token1 == token2,
            "\(message): token1=\(token1), token2=\(token2)"
        )
    }

    /// Assert stop sequence behavior
    internal static func assertStopSequenceEffect(
        _ generatedText: String,
        stopSequences: [String],
        shouldStop: Bool,
        maxLength: Int? = nil,
        file _: StaticString = #file,
        line _: UInt = #line
    ) {
        if shouldStop {
            assertStopSequenceFound(generatedText, stopSequences: stopSequences)
        }

        if let max = maxLength {
            assertMaxLength(generatedText, max: max)
        }
    }

    private static func assertStopSequenceFound(
        _ generatedText: String,
        stopSequences: [String]
    ) {
        // Stop sequences should NOT appear in the output - they trigger stopping but are not emitted
        let foundSequence: String? = findStopSequence(in: generatedText, from: stopSequences)

        #expect(
            foundSequence == nil,
            """
            Generated text should NOT contain stop sequences (they should be filtered): \
            found '\(foundSequence ?? "")' in output
            """
        )
    }

    private static func findStopSequence(
        in text: String,
        from sequences: [String]
    ) -> String? {
        for sequence in sequences where text.contains(sequence) {
            return sequence
        }
        return nil
    }

    private static func assertStopPosition(
        _ generatedText: String,
        foundSequence: String
    ) {
        if let range = generatedText.range(of: foundSequence) {
            let offset: Int = range.upperBound.utf16Offset(in: generatedText)
            let stopBuffer: Int = 10
            #expect(
                generatedText.hasSuffix(foundSequence) ||
                offset >= generatedText.count - stopBuffer,
                "Generation should stop shortly after stop sequence '\(foundSequence)'"
            )
        } else {
            #expect(
                generatedText.hasSuffix(foundSequence),
                "Generation should stop shortly after stop sequence '\(foundSequence)'"
            )
        }
    }

    private static func assertMaxLength(_ text: String, max: Int) {
        #expect(
            text.count <= max,
            "Generated text length (\(text.count)) should not exceed \(max)"
        )
    }

    // MARK: - Context Configuration Assertions
    /// Assert context configuration matches expected values
    internal static func assertContextConfiguration(
        _ context: LlamaCPPContext,
        expectedContextSize: Int32,
        expectedBatchSize: Int32,
        expectedThreadCount: Int32,
        file _: StaticString = #file,
        line _: UInt = #line
    ) {
        let config: ComputeConfiguration = context.configuration
        #expect(
            Int32(config.contextSize) == expectedContextSize,
            "Context size should be \(expectedContextSize), got \(config.contextSize)"
        )
        #expect(
            Int32(config.batchSize) == expectedBatchSize,
            "Batch size should be \(expectedBatchSize), got \(config.batchSize)"
        )
        #expect(
            Int32(config.threadCount) == expectedThreadCount,
            "Thread count should be \(expectedThreadCount), got \(config.threadCount)"
        )
    }

    // MARK: - Memory State Assertions
    /// Assert model/context loaded state
    internal static func assertLoadedState(
        expectedModelLoaded: Bool,
        model: LlamaCPPModel? = nil,
        context: LlamaCPPContext? = nil,
        expectedContextLoaded: Bool = false,
        file _: StaticString = #file,
        line _: UInt = #line
    ) {
        if let model {
            #expect(
                model.isLoaded == expectedModelLoaded,
                "Model loaded state should be \(expectedModelLoaded), got \(model.isLoaded)"
            )
        }
        if let context {
            #expect(
                context.isLoaded == expectedContextLoaded,
                "Context loaded state should be \(expectedContextLoaded), got \(context.isLoaded)"
            )
        }
    }
}

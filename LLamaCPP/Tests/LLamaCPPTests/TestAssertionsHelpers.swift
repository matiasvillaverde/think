import Abstractions
import Foundation
@testable import LLamaCPP
import Testing

/// Helper enums to split TestAssertions functionality and reduce type body length
internal enum ModelAssertions {
    /// Assert that a token is within the valid vocabulary range
    internal static func assertTokenInVocabRange(
        _ token: Int32,
        model: LlamaCPPModel,
        file _: StaticString = #file,
        line _: UInt = #line
    ) {
        let vocabSize: Int32 = model.vocabSize
        #expect(
            token >= 0 && token < vocabSize,
            "Token \(token) should be in valid range [0, \(vocabSize))"
        )
    }

    /// Assert specific model metadata values for Qwen3-0.6B test model
    internal static func assertTestModelMetadata(
        _ model: LlamaCPPModel,
        expectedVocabSize: Int32 = 151_936,
        expectedContextLength: Int32 = 40_960,
        expectedEmbeddingSize: Int32 = 1_024,
        file _: StaticString = #file,
        line _: UInt = #line
    ) {
        #expect(
            model.vocabSize == expectedVocabSize,
            "Vocab size should be \(expectedVocabSize), got \(model.vocabSize)"
        )
        #expect(
            model.contextLength == expectedContextLength,
            "Context length should be \(expectedContextLength), got \(model.contextLength)"
        )
        #expect(
            model.embeddingSize == expectedEmbeddingSize,
            "Embedding size should be \(expectedEmbeddingSize), got \(model.embeddingSize)"
        )
    }
}

internal enum MetricsAssertions {
    /// Assert specific metric values
    internal static func assertMetrics(
        _ metrics: ChunkMetrics?,
        expectedGeneratedTokens: Int? = nil,
        expectedPromptTokens: Int? = nil,
        hasTimingMetrics: Bool = true,
        file _: StaticString = #file,
        line _: UInt = #line
    ) {
        #expect(metrics != nil, "Metrics should be present")
        guard let metrics else {
            return
        }

        if let usage = metrics.usage {
            assertUsageMetrics(
                usage,
                expectedGeneratedTokens: expectedGeneratedTokens,
                expectedPromptTokens: expectedPromptTokens
            )
        }

        if hasTimingMetrics {
            assertTimingMetrics(metrics.timing)
        }
    }

    private static func assertUsageMetrics(
        _ usage: UsageMetrics,
        expectedGeneratedTokens: Int?,
        expectedPromptTokens: Int?
    ) {
        if let expected = expectedGeneratedTokens {
            #expect(
                usage.generatedTokens == expected,
                "Generated tokens should be \(expected), got \(usage.generatedTokens)"
            )
        }

        if let expected = expectedPromptTokens,
            let actual = usage.promptTokens {
            #expect(
                actual == expected,
                "Prompt tokens should be \(expected), got \(actual)"
            )
        }

        #expect(
            usage.totalTokens == (usage.generatedTokens + (usage.promptTokens ?? 0)),
            "Total tokens should equal sum of generated + prompt tokens"
        )
    }

    private static func assertTimingMetrics(_ timing: TimingMetrics?) {
        #expect(timing != nil, "Timing metrics should be present")
        guard let timing else {
            return
        }

        #expect(
            timing.totalTime > Duration.zero,
            "Total time should be positive"
        )

        if let timeToFirstToken = timing.timeToFirstToken {
            #expect(
                timeToFirstToken > Duration.zero,
                "Time to first token should be positive"
            )
            #expect(
                timeToFirstToken <= timing.totalTime,
                "TTFT should be less than total time"
            )
        }
    }
}

internal enum TokenizationAssertions {
    /// Assert tokenization produces expected results
    internal static func assertTokenization(
        _ tokens: [Int32],
        expectedCount: Int? = nil,
        expectedFirstToken: Int32? = nil,
        maxCount: Int = 100,
        file _: StaticString = #file,
        line _: UInt = #line
    ) {
        assertBasicTokenization(tokens, maxCount: maxCount)
        assertExpectedTokenCount(tokens, expected: expectedCount)
        assertFirstToken(tokens, expected: expectedFirstToken)
        assertAllTokensValid(tokens)
    }

    private static func assertBasicTokenization(_ tokens: [Int32], maxCount: Int) {
        #expect(!tokens.isEmpty, "Tokenization should produce at least one token")
        #expect(
            tokens.count <= maxCount,
            "Token count should be <= \(maxCount), got \(tokens.count)"
        )
    }

    private static func assertExpectedTokenCount(_ tokens: [Int32], expected: Int?) {
        guard let expected else {
            return
        }
        #expect(tokens.count == expected, "Token count should be \(expected), got \(tokens.count)")
    }

    private static func assertFirstToken(_ tokens: [Int32], expected: Int32?) {
        guard let expected else {
            return
        }
        #expect(
            tokens.first == expected,
            "First token should be \(expected), got \(String(describing: tokens.first))"
        )
    }

    private static func assertAllTokensValid(_ tokens: [Int32]) {
        for (index, token) in tokens.enumerated() {
            #expect(
                token >= 0,
                "Token at index \(index) should be non-negative, got \(token)"
            )
        }
    }
}

import Testing
import Foundation
@testable import Abstractions

@Suite("GenerationMetrics Tests")
struct GenerationMetricsTests {
    @Suite("Perplexity Calculation")
    struct PerplexityCalculation {
        @Test("Basic perplexity calculation from log probabilities")
        func testBasicPerplexity() {
            // Create tokens with known log probabilities
            let tokens = [
                GenerationMetrics.TokenInfo(
                    tokenId: 1,
                    text: "Hello",
                    logProb: -1.0,
                    duration: .milliseconds(10)
                ),
                GenerationMetrics.TokenInfo(
                    tokenId: 2,
                    text: "world",
                    logProb: -2.0,
                    duration: .milliseconds(10)
                ),
                GenerationMetrics.TokenInfo(
                    tokenId: 3,
                    text: "!",
                    logProb: -1.5,
                    duration: .milliseconds(10)
                )
            ]

            let metrics = GenerationMetrics(tokens: tokens)

            // Perplexity = exp(average negative log likelihood)
            // Average NLL = (1.0 + 2.0 + 1.5) / 3 = 1.5
            // Perplexity = exp(1.5) ≈ 4.48
            let perplexity = metrics.perplexity
            #expect(perplexity != nil)
            if let perplexity {
                #expect(abs(perplexity - 4.48) < 0.01)
            }

            // Empty tokens should return nil
            let emptyMetrics = GenerationMetrics(tokens: [])
            #expect(emptyMetrics.perplexity == nil)
        }
    }

    @Suite("Entropy Calculation")
    struct EntropyCalculation {
        @Test("Basic entropy calculation from log probabilities")
        func testBasicEntropy() {
            // Create tokens with varying log probabilities
            let uniformTokens = [
                GenerationMetrics.TokenInfo(
                    tokenId: 1,
                    text: "a",
                    logProb: -0.693,  // log(0.5)
                    duration: .milliseconds(10)
                ),
                GenerationMetrics.TokenInfo(
                    tokenId: 2,
                    text: "b",
                    logProb: -0.693,  // log(0.5)
                    duration: .milliseconds(10)
                )
            ]

            let uniformMetrics = GenerationMetrics(tokens: uniformTokens)
            let entropy = uniformMetrics.entropy
            #expect(entropy != nil)
            // Higher entropy for uniform distribution

            // Empty tokens should return nil
            let emptyMetrics = GenerationMetrics(tokens: [])
            #expect(emptyMetrics.entropy == nil)
        }
    }

    @Suite("Repetition Rate")
    struct RepetitionRate {
        @Test("Repetition detection within sliding window")
        func testRepetitionRate() {
            // Create tokens with some repetitions
            let tokensWithRepetition = [
                GenerationMetrics.TokenInfo(tokenId: 1, text: "the", logProb: -1.0, duration: .milliseconds(10)),
                GenerationMetrics.TokenInfo(tokenId: 2, text: "cat", logProb: -1.0, duration: .milliseconds(10)),
                GenerationMetrics.TokenInfo(tokenId: 3, text: "sat", logProb: -1.0, duration: .milliseconds(10)),
                GenerationMetrics.TokenInfo(tokenId: 4, text: "on", logProb: -1.0, duration: .milliseconds(10)),
                GenerationMetrics.TokenInfo(tokenId: 1, text: "the", logProb: -1.0, duration: .milliseconds(10)),  // Repetition
                GenerationMetrics.TokenInfo(tokenId: 5, text: "mat", logProb: -1.0, duration: .milliseconds(10))
            ]

            let metrics = GenerationMetrics(tokens: tokensWithRepetition)

            // With window size 3, we check tokens at index 3, 4, 5
            // Token at index 3 (id=4): not in previous 3 tokens [1, 2, 3]
            // Token at index 4 (id=1): IS in previous 3 tokens [2, 3, 4] - NO, it's not
            // Token at index 4 (id=1): IS in previous 3 tokens [2, 3, 4] - actually checking [1, 2, 3] and 1 is there!
            // Token at index 5 (id=5): not in previous 3 tokens [3, 4, 1]
            // So 1 out of 3 checks = 33.3% repetition
            let rate = metrics.repetitionRate(windowSize: 3)
            #expect(rate != nil)

            // No repetitions case
            let uniqueTokens = [
                GenerationMetrics.TokenInfo(tokenId: 1, text: "a", logProb: -1.0, duration: .milliseconds(10)),
                GenerationMetrics.TokenInfo(tokenId: 2, text: "b", logProb: -1.0, duration: .milliseconds(10)),
                GenerationMetrics.TokenInfo(tokenId: 3, text: "c", logProb: -1.0, duration: .milliseconds(10)),
                GenerationMetrics.TokenInfo(tokenId: 4, text: "d", logProb: -1.0, duration: .milliseconds(10))
            ]
            let uniqueMetrics = GenerationMetrics(tokens: uniqueTokens)
            let uniqueRate = uniqueMetrics.repetitionRate(windowSize: 2)
            #expect(uniqueRate == 0.0)

            // Insufficient tokens for window
            let shortMetrics = GenerationMetrics(tokens: Array(uniqueTokens.prefix(2)))
            #expect(shortMetrics.repetitionRate(windowSize: 5) == nil)
        }
    }
}

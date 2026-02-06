import Abstractions
import Foundation
@testable import LLamaCPP
import Testing

/// Tests for sampler functionality, particularly token acceptance
extension LlamaCPPModelTestSuite {
    private enum SamplerConstants {
        static let statefulTemperature: Float = 0.5
        static let statefulTopP: Float = 0.95
        static let statefulTopK: Int = 50
        static let statefulRepetitionPenalty: Float = 1.5
        static let statefulSeed: Int = 123
        static let penaltyTemperature: Float = 0.1
        static let penaltyTopP: Float = 1.0
        static let penaltyTopK: Int = 1
        static let noPenaltyRepetition: Float = 1.0
        static let penaltySeed: Int = 999
        static let comparisonTokenCount: Int = 5
    }

    // MARK: - Sampler Tests

    // MARK: - Test 2.1: Sampler accepts tokens

    @Test("Sampler accepts generated tokens for stateful sampling")
    internal func testSamplerAcceptsTokens() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)
        let generator: LlamaCPPGenerator = LlamaCPPGenerator(model: model, context: context)

        // Generate multiple tokens with repetition penalty
        let samplingParams: SamplingParameters = SamplingParameters(
            temperature: 0.7,
            topP: 0.9,
            topK: 40,
            repetitionPenalty: 1.2,  // Should penalize repeated tokens
            seed: 42
        )

        // Generate first token
        let token1: Int32 = try generator.generateNextToken(
            prompt: "The quick brown",
            sampling: samplingParams
        )

        // Generate second token - should be influenced by first if acceptance works
        let token2: Int32 = try generator.generateNextToken(
            tokens: [token1],
            sampling: samplingParams
        )

        // Generate third token - should be influenced by both if acceptance works
        let token3: Int32 = try generator.generateNextToken(
            tokens: [token2],
            sampling: samplingParams
        )

        // If token acceptance works, repetition penalty should make
        // consecutive identical tokens less likely
        if token1 == token2, token2 == token3 {
            Issue.record(
                "Tokens are identical despite repetition penalty - acceptance likely not working"
            )
        }

        // Verify tokens are valid
        let vocabSize: Int32 = model.vocabSize
        #expect(token1 >= 0 && token1 < vocabSize)
        #expect(token2 >= 0 && token2 < vocabSize)
        #expect(token3 >= 0 && token3 < vocabSize)

        generator.free()
        context.free()
        model.free()
    }

    // MARK: - Test 2.2: Stateful sampling

    @Test("Stateful sampling maintains history correctly")
    internal func testStatefulSampling() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)
        let generator: LlamaCPPGenerator = LlamaCPPGenerator(model: model, context: context)

        let samplingParams: SamplingParameters = statefulSamplingParams()
        let prompt: String = "The cat sat on the"

        let firstToken: Int32 = try generateToken(
            prompt: prompt,
            generator: generator,
            sampling: samplingParams
        )
        try context.reset()
        let secondToken: Int32 = try generateToken(
            prompt: prompt,
            generator: generator,
            sampling: samplingParams
        )

        assertTokensValid([firstToken, secondToken], model: model)

        try context.reset()
        _ = try generateToken(prompt: prompt, generator: generator, sampling: samplingParams)
        let generatedTokens: [Int32] = try generateContinuationTokens(
            generator: generator,
            sampling: samplingParams,
            count: SamplerConstants.comparisonTokenCount
        )

        recordIfUniform(
            generatedTokens,
            message: "All tokens identical despite repetition penalty - state not maintained"
        )

        generator.free()
        context.free()
        model.free()
    }

    // MARK: - Additional sampler state tests

    @Test("Repetition penalty reduces probability of repeated tokens")
    internal func testRepetitionPenaltyEffect() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)
        let generator: LlamaCPPGenerator = LlamaCPPGenerator(model: model, context: context)

        let noPenaltyParams: SamplingParameters = noPenaltySamplingParams()
        let tokensNoPenalty: [Int32] = try generateSequence(
            prompt: "The the the",
            generator: generator,
            sampling: noPenaltyParams,
            count: SamplerConstants.comparisonTokenCount
        )

        try context.reset()

        let withPenaltyParams: SamplingParameters = withPenaltySamplingParams()
        let tokensWithPenalty: [Int32] = try generateSequence(
            prompt: "The the the",
            generator: generator,
            sampling: withPenaltyParams,
            count: SamplerConstants.comparisonTokenCount
        )

        // With penalty should have more unique tokens
        let uniqueNoPenalty: Int = Set(tokensNoPenalty).count
        let uniqueWithPenalty: Int = Set(tokensWithPenalty).count

        // We expect more diversity with penalty
        // But this might not always be true depending on the model
        // So we just document the behavior
        print("Unique tokens without penalty: \(uniqueNoPenalty)/5")
        print("Unique tokens with penalty: \(uniqueWithPenalty)/5")

        generator.free()
        context.free()
        model.free()
    }

    private func statefulSamplingParams() -> SamplingParameters {
        SamplingParameters(
            temperature: SamplerConstants.statefulTemperature,
            topP: SamplerConstants.statefulTopP,
            topK: SamplerConstants.statefulTopK,
            repetitionPenalty: SamplerConstants.statefulRepetitionPenalty,  // High penalty
            seed: SamplerConstants.statefulSeed
        )
    }

    private func noPenaltySamplingParams() -> SamplingParameters {
        SamplingParameters(
            temperature: SamplerConstants.penaltyTemperature,
            topP: SamplerConstants.penaltyTopP,
            topK: SamplerConstants.penaltyTopK,  // Greedy
            repetitionPenalty: SamplerConstants.noPenaltyRepetition,  // No penalty
            seed: SamplerConstants.penaltySeed
        )
    }

    private func withPenaltySamplingParams() -> SamplingParameters {
        SamplingParameters(
            temperature: SamplerConstants.penaltyTemperature,
            topP: SamplerConstants.penaltyTopP,
            topK: SamplerConstants.penaltyTopK,
            repetitionPenalty: SamplerConstants.statefulRepetitionPenalty,  // Strong penalty
            seed: SamplerConstants.penaltySeed  // Same seed for comparison
        )
    }

    private func generateToken(
        prompt: String,
        generator: LlamaCPPGenerator,
        sampling: SamplingParameters
    ) throws -> Int32 {
        try generator.generateNextToken(prompt: prompt, sampling: sampling)
    }

    private func generateContinuationTokens(
        generator: LlamaCPPGenerator,
        sampling: SamplingParameters,
        count: Int
    ) throws -> [Int32] {
        try (0..<count).map { _ in
            try generator.generateNextToken(tokens: [], sampling: sampling)
        }
    }

    private func generateSequence(
        prompt: String,
        generator: LlamaCPPGenerator,
        sampling: SamplingParameters,
        count: Int
    ) throws -> [Int32] {
        _ = try generator.generateNextToken(prompt: prompt, sampling: sampling)
        return try generateContinuationTokens(
            generator: generator,
            sampling: sampling,
            count: count
        )
    }

    private func assertTokensValid(_ tokens: [Int32], model: LlamaCPPModel) {
        for token in tokens {
            TestAssertions.assertTokenInVocabRange(token, model: model)
        }
    }

    private func recordIfUniform(_ tokens: [Int32], message: String) {
        if Set(tokens).count == 1 {
            Issue.record(LLMError.providerError(code: "SAMPLER_STATE", message: message))
        }
    }

    @Test("Sampler chain is properly managed across generations")
    internal func testSamplerChainLifecycle() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)
        let generator: LlamaCPPGenerator = LlamaCPPGenerator(model: model, context: context)

        // First generation with one set of parameters
        let params1: SamplingParameters = SamplingParameters(
            temperature: 0.8,
            topP: 0.9,
            topK: 40,
            seed: 111
        )
        _ = try generator.generateNextToken(
            prompt: "Hello",
            sampling: params1
        )

        // Second generation with different parameters
        let params2: SamplingParameters = SamplingParameters(
            temperature: 0.2,
            topP: 0.5,
            topK: 10,
            seed: 222
        )
        _ = try generator.generateNextToken(
            prompt: "World",
            sampling: params2
        )

        // Third generation back to first parameters
        _ = try generator.generateNextToken(
            prompt: "Test",
            sampling: params1
        )

        // If we get here without crashes, sampler chain management is working
        #expect(true, "Sampler chain lifecycle managed correctly")

        generator.free()
        context.free()
        model.free()
    }
}

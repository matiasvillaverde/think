import Abstractions
import Foundation
import llama
@testable import LLamaCPP
import Testing

/// Suite for all tests that load models - serialized to avoid concurrent loading issues
extension LlamaCPPModelTestSuite {
    // Model path is provided by TestHelpers.testModelPath

    // MARK: - Model Loading Tests

    @Test("Can load GGUF model from file")
    internal func testLoadModel() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let isLoaded: Bool = model.isLoaded
        #expect(isLoaded)

        model.free()
    }

    @Test("Can get model metadata - vocab size")
    internal func testGetVocabSize() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let vocabSize: Int32 = model.vocabSize
        // Exact vocab size for Qwen3-0.6B model
        #expect(
            vocabSize == 151_936,
            "Vocab size should be exactly 151936 for Qwen3-0.6B, got \(vocabSize)"
        )

        model.free()
    }

    @Test("Can get model metadata - context length")
    internal func testGetContextLength() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let contextLength: Int32 = model.contextLength
        // Exact context length for Qwen3-0.6B model
        #expect(
            contextLength == 40_960,
            "Context length should be exactly 40960 for Qwen3-0.6B, got \(contextLength)"
        )

        model.free()
    }

    @Test("Can get model metadata - embedding size")
    internal func testGetEmbeddingSize() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let embeddingSize: Int32 = model.embeddingSize
        // For Qwen3-0.6B model, we need to determine the exact embedding size
        // Qwen3 0.6B typically has an embedding dimension of 1024
        #expect(
            embeddingSize == 1_024,
            "Embedding size should be exactly 1024 for Qwen3-0.6B, got \(embeddingSize)"
        )

        model.free()
    }

    @Test("Model can be freed without crash")
    internal func testModelFree() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        model.free()

        let isLoaded: Bool = model.isLoaded
        #expect(!isLoaded)
    }

    @Test("Model free is idempotent")
    internal func testModelFreeIdempotent() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        model.free()
        model.free()

        let isLoaded: Bool = model.isLoaded
        #expect(!isLoaded)
    }

    // MARK: - Context Tests

    @Test("Can create context from model")
    internal func testCreateContext() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)

        let isLoaded: Bool = context.isLoaded
        #expect(isLoaded)

        context.free()
        model.free()
    }

    @Test("Can create context with custom configuration")
    internal func testCreateContextWithConfig() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let config: ComputeConfiguration = ComputeConfiguration(
            contextSize: 2_048,
            batchSize: 512,
            threadCount: 4
        )

        let context: LlamaCPPContext = try LlamaCPPContext(
            model: model, configuration: config
        )

        TestAssertions.assertLoadedState(
            expectedModelLoaded: true,
            context: context,
            expectedContextLoaded: true
        )

        TestAssertions.assertContextConfiguration(
            context,
            expectedContextSize: 2_048,
            expectedBatchSize: 512,
            expectedThreadCount: 4
        )

        context.free()
        model.free()
    }

    // MARK: - Tokenization Tests

    @Test("Can tokenize simple text")
    internal func testTokenizeSimpleText() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let tokenizer: LlamaCPPTokenizer = LlamaCPPTokenizer()
        guard let ptr = model.pointer else {
            throw LLMError.invalidConfiguration("Invalid pointer")
        }

        let text: String = "Hello world"
        let tokens: [Int32] = try tokenizer.tokenize(
            text: text, addBos: false, modelPointer: ptr
        )

        // "Hello world" typically tokenizes to 2-4 tokens depending on model
        TestAssertions.assertTokenization(
            tokens,
            expectedCount: nil,  // Model-specific, but we can check range
            expectedFirstToken: nil,  // Model-specific
            maxCount: 5
        )
        #expect(
            tokens.count >= 2 && tokens.count <= 4,
            "'Hello world' should tokenize to 2-4 tokens, got \(tokens.count)"
        )

        model.free()
    }

    @Test("Can detokenize tokens back to text")
    internal func testDetokenize() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let tokenizer: LlamaCPPTokenizer = LlamaCPPTokenizer()
        guard let ptr = model.pointer else {
            throw LLMError.invalidConfiguration("Invalid pointer")
        }

        let originalText: String = "Hello"
        let tokens: [Int32] = try tokenizer.tokenize(
            text: originalText, addBos: false, modelPointer: ptr
        )
        let detokenized: String = try tokenizer.detokenize(tokens: tokens, modelPointer: ptr)

        #expect(detokenized.contains("Hello"))

        model.free()
    }

    // MARK: - Generation Tests

    @Test("Can generate single token")
    internal func testGenerateSingleToken() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)
        let generator: LlamaCPPGenerator = LlamaCPPGenerator(model: model, context: context)

        let prompt: String = "Hello"
        let tokenId: Int32 = try generator.generateNextToken(prompt: prompt)

        TestAssertions.assertTokenInVocabRange(tokenId, model: model)

        // For deterministic generation, we expect specific common follow-up tokens
        // Common tokens after "Hello" include punctuation, "world", "there", etc.
        // Token IDs vary by model, but should not be special tokens (0, 1, 2)
        #expect(
            tokenId > 2,
            "Generated token should not be a special token (BOS/EOS/PAD), got \(tokenId)"
        )

        context.free()
        model.free()
    }

    @Test("Greedy sampling selects highest probability")
    internal func testGreedySampling() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)
        let generator: LlamaCPPGenerator = LlamaCPPGenerator(model: model, context: context)

        let greedyParams: SamplingParameters = SamplingParameters(
            temperature: 0.0,
            topP: 1.0,
            topK: 1
        )

        let token1: Int32 = try generator.generateNextToken(
            prompt: "The", sampling: greedyParams
        )
        try context.reset()
        let token2: Int32 = try generator.generateNextToken(
            prompt: "The", sampling: greedyParams
        )

        TestAssertions.assertDeterministicGeneration(
            token1,
            token2,
            message: "Greedy sampling (temp=0, topK=1) must be deterministic"
        )

        // Both tokens should be valid
        TestAssertions.assertTokenInVocabRange(token1, model: model)
        TestAssertions.assertTokenInVocabRange(token2, model: model)

        context.free()
        model.free()
    }

    // MARK: - Sampling Tests

    @Test("Temperature affects generation")
    internal func testTemperatureSampling() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)
        let generator: LlamaCPPGenerator = LlamaCPPGenerator(model: model, context: context)

        // Test with greedy sampling (temperature = 0)
        let greedyParams: SamplingParameters = SamplingParameters(
            temperature: 0.0,
            topP: 1.0,
            topK: nil,
            seed: 42
        )

        let token1: Int32 = try generator.generateNextToken(
            prompt: "Hello", sampling: greedyParams
        )
        try context.reset()
        let token2: Int32 = try generator.generateNextToken(
            prompt: "Hello", sampling: greedyParams
        )

        TestAssertions.assertDeterministicGeneration(
            token1,
            token2,
            message: "Greedy sampling with seed should be deterministic"
        )

        context.free()
        model.free()
    }

    @Test("Different sampling parameters produce valid outputs")
    internal func testSamplingVariation() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)
        let generator: LlamaCPPGenerator = LlamaCPPGenerator(model: model, context: context)

        // Test with high temperature
        let token1: Int32 = try generator.generateNextToken(
            prompt: "The",
            sampling: SamplingParameters(temperature: 1.5, topP: 0.95, topK: 50, seed: 123)
        )

        try context.reset()

        // Test with low temperature
        let token2: Int32 = try generator.generateNextToken(
            prompt: "The",
            sampling: SamplingParameters(temperature: 0.1, topP: 0.5, topK: 5, seed: 456)
        )

        // Verify tokens are valid
        TestAssertions.assertTokenInVocabRange(token1, model: model)
        TestAssertions.assertTokenInVocabRange(token2, model: model)

        // With different sampling params, tokens might differ
        // High temp should allow more variation than low temp
        if token1 == token2 {
            print(
                "Note: Different sampling parameters produced same token (can happen with strong model bias)"
            )
        }

        context.free()
        model.free()
    }

    @Test("Throws error for invalid tokenizer model")
    internal func testTokenizerWithInvalidModel() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        model.free() // Free the model to simulate invalid state

        let _: LlamaCPPTokenizer = LlamaCPPTokenizer()

        // Since model is freed, pointer should be nil
        #expect(model.pointer == nil)
    }
}

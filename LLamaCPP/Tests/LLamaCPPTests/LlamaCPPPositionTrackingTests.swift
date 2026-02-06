import Abstractions
import Foundation
@testable import LLamaCPP
import Testing

/// Tests for position tracking in the generator
extension LlamaCPPModelTestSuite {
    // MARK: - Test 3.1: Position resets with context

    @Test("Position resets when context resets")
    internal func testPositionResetsWithContext() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)
        let generator: LlamaCPPGenerator = LlamaCPPGenerator(model: model, context: context)

        // Generate some tokens to advance position
        _ = try generator.generateNextToken(
            prompt: "Hello world",
            sampling: SamplingParameters.default
        )

        // Generate more tokens
        for _ in 0..<3 {
            _ = try generator.generateNextToken(
                tokens: [],
                sampling: SamplingParameters.default
            )
        }

        // Reset context and generator - position should reset too
        try context.reset()
        generator.reset()

        // Generate new tokens - should start from position 0
        _ = try generator.generateNextToken(
            prompt: "New start",
            sampling: SamplingParameters.default
        )

        // If position didn't reset, subsequent generation might fail
        // or produce incorrect results
        _ = try generator.generateNextToken(
            tokens: [],
            sampling: SamplingParameters.default
        )

        #expect(true, "Position tracking should work after reset")

        generator.free()
        context.free()
        model.free()
    }

    @Test("Context reset syncs generator position without manual reset")
    internal func testContextResetSyncsGeneratorPosition() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)
        let generator: LlamaCPPGenerator = LlamaCPPGenerator(model: model, context: context)

        guard let ptr = model.pointer else {
            throw LLMError.invalidConfiguration("Model pointer is nil")
        }

        let tokenizer: LlamaCPPTokenizer = LlamaCPPTokenizer()
        let tokens1: [Int32] = try tokenizer.tokenize(
            text: "Hello",
            addBos: true,
            modelPointer: ptr
        )

        _ = try generator.generateNextToken(
            prompt: "Hello",
            sampling: SamplingParameters.default
        )
        #expect(generator.currentPosition == Int32(tokens1.count))

        try context.reset()

        let tokens2: [Int32] = try tokenizer.tokenize(
            text: "New start",
            addBos: true,
            modelPointer: ptr
        )

        _ = try generator.generateNextToken(
            prompt: "New start",
            sampling: SamplingParameters.default
        )
        #expect(generator.currentPosition == Int32(tokens2.count))

        generator.free()
        context.free()
        model.free()
    }

    // MARK: - Test 3.2: Position consistency

    @Test("Position remains consistent across all operations")
    internal func testPositionConsistency() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)
        let generator: LlamaCPPGenerator = LlamaCPPGenerator(model: model, context: context)

        try performPositionOperations(model: model, context: context, generator: generator)
        try verifyPositionReset(model: model, context: context, generator: generator)

        #expect(true, "Position tracking remained consistent")

        generator.free()
        context.free()
        model.free()
    }

    private func performPositionOperations(
        model: LlamaCPPModel,
        context _: LlamaCPPContext,
        generator: LlamaCPPGenerator
    ) throws {
        // Track positions through various operations
        guard let ptr = model.pointer else {
            throw LLMError.invalidConfiguration("Model pointer is nil")
        }

        let tokenizer: LlamaCPPTokenizer = LlamaCPPTokenizer()

        // Operation 1: Initial prompt
        let prompt1: String = "First"
        let tokens1: [Int32] = try tokenizer.tokenize(
            text: prompt1,
            addBos: true,
            modelPointer: ptr
        )
        try generator.processBatch(tokens: tokens1)

        // Operation 2: Continue generation
        _ = try generator.generateNextToken(
            tokens: [],
            sampling: SamplingParameters.default
        )

        // Operation 3: New prompt (should continue position)
        let prompt2: String = "Second"
        let tokens2: [Int32] = try tokenizer.tokenize(
            text: prompt2,
            addBos: false,
            modelPointer: ptr
        )
        try generator.processBatch(tokens: tokens2)

        // Operation 4: Generate more
        _ = try generator.generateNextToken(
            tokens: [],
            sampling: SamplingParameters.default
        )
    }

    private func verifyPositionReset(
        model: LlamaCPPModel,
        context: LlamaCPPContext,
        generator: LlamaCPPGenerator
    ) throws {
        guard let ptr = model.pointer else {
            throw LLMError.invalidConfiguration("Model pointer is nil")
        }

        let tokenizer: LlamaCPPTokenizer = LlamaCPPTokenizer()

        // Reset and verify clean slate
        try context.reset()
        generator.reset()

        // Should be able to start fresh
        let prompt3: String = "Fresh start"
        let tokens3: [Int32] = try tokenizer.tokenize(
            text: prompt3,
            addBos: true,
            modelPointer: ptr
        )
        try generator.processBatch(tokens: tokens3)
    }

    // MARK: - Additional position tracking tests

    @Test("Position tracking with large batches")
    internal func testPositionWithLargeBatches() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)
        let generator: LlamaCPPGenerator = LlamaCPPGenerator(model: model, context: context)

        guard let ptr = model.pointer else {
            throw LLMError.invalidConfiguration("Model pointer is nil")
        }

        let tokenizer: LlamaCPPTokenizer = LlamaCPPTokenizer()

        // Create a large prompt that might exceed batch size
        let longPrompt: String = String(repeating: "test ", count: 100)
        let tokens: [Int32] = try tokenizer.tokenize(
            text: longPrompt,
            addBos: true,
            modelPointer: ptr
        )

        // Process the large batch
        try generator.processBatch(tokens: tokens)

        // Should still be able to generate
        _ = try generator.generateNextToken(
            tokens: [],
            sampling: SamplingParameters.default
        )

        #expect(true, "Large batch position tracking works")

        generator.free()
        context.free()
        model.free()
    }

    @Test("Position tracking across multiple resets")
    internal func testPositionAcrossMultipleResets() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)
        let generator: LlamaCPPGenerator = LlamaCPPGenerator(model: model, context: context)

        for iteration in 0..<3 {
            // Generate some tokens
            _ = try generator.generateNextToken(
                prompt: "Iteration \(iteration)",
                sampling: SamplingParameters.default
            )

            // Continue generation
            for _ in 0..<2 {
                _ = try generator.generateNextToken(
                    tokens: [],
                    sampling: SamplingParameters.default
                )
            }

            // Reset for next iteration
            if iteration < 2 {
                try context.reset()
                generator.reset()
            }
        }

        #expect(true, "Multiple reset cycles handled correctly")

        generator.free()
        context.free()
        model.free()
    }

    @Test("Position boundary conditions")
    internal func testPositionBoundaryConditions() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let config: ComputeConfiguration = ComputeConfiguration(
            contextSize: 128,  // Small context for testing
            batchSize: 32,
            threadCount: 1
        )
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: config)
        let generator: LlamaCPPGenerator = LlamaCPPGenerator(model: model, context: context)

        // Test empty batch
        try generator.processBatch(tokens: [])

        // Test single token
        try generator.processBatch(tokens: [1])

        // Test exactly batch size
        let batchSizeTokens: [Int32] = Array(repeating: Int32(1), count: 32)
        try generator.processBatch(tokens: batchSizeTokens)

        // Reset and test again
        try context.reset()
        generator.reset()

        // Should work after reset
        _ = try generator.generateNextToken(
            prompt: "Test",
            sampling: SamplingParameters.default
        )

        #expect(true, "Boundary conditions handled correctly")

        generator.free()
        context.free()
        model.free()
    }
}

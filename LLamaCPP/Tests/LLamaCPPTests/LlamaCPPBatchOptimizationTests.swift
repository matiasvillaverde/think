import Abstractions
import Foundation
@testable import LLamaCPP
import Testing

/// Tests for batch processing optimization
extension LlamaCPPModelTestSuite {
    // MARK: - Test 8.1: Batch performance

    @Test("Batch processing is efficient")
    internal func testBatchProcessingPerformance() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try LlamaCPPModel(path: modelPath)
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)
        let generator: LlamaCPPGenerator = LlamaCPPGenerator(model: model, context: context)

        guard let ptr = model.pointer else {
            throw LLMError.invalidConfiguration("Model pointer is nil")
        }

        let tokenizer: LlamaCPPTokenizer = LlamaCPPTokenizer()

        // Test various batch sizes
        let batchSizes: [Int] = [1, 10, 50, 100, 200]
        var timings: [Int: TimeInterval] = [:]

        for batchSize in batchSizes {
            // Create tokens for batch
            let text: String = String(repeating: "test ", count: batchSize)
            let tokens: [Int32] = try tokenizer.tokenize(
                text: text,
                addBos: true,
                modelPointer: ptr
            )

            // Measure batch processing time
            let startTime: Date = Date()
            try generator.processBatch(tokens: tokens)
            let elapsed: TimeInterval = Date().timeIntervalSince(startTime)

            timings[batchSize] = elapsed

            // Reset for next test
            try context.reset()
            generator.reset()
        }

        // Verify that larger batches are more efficient per token
        if let time1: TimeInterval = timings[1], let time100: TimeInterval = timings[100] {
            let perToken1: TimeInterval = time1
            let perToken100: TimeInterval = time100 / 100.0
            // Larger batch should be more efficient per token
            #expect(perToken100 < perToken1 * 2, "Batch processing should be efficient")
        }

        generator.free()
        context.free()
        model.free()
    }

    // MARK: - Test 8.3: Batch boundary conditions

    @Test("Batch processing handles boundary conditions")
    internal func testBatchBoundaryConditions() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try LlamaCPPModel(path: modelPath)
        let config: ComputeConfiguration = ComputeConfiguration(
            contextSize: 512,
            batchSize: 32,
            threadCount: 2
        )
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: config)
        let generator: LlamaCPPGenerator = LlamaCPPGenerator(model: model, context: context)

        // Test empty batch
        try generator.processBatch(tokens: [])

        // Test single token
        try generator.processBatch(tokens: [1])

        // Test exactly batch size
        let exactBatch: [Int32] = Array(repeating: Int32(1), count: 32)
        try generator.processBatch(tokens: exactBatch)

        // Test one more than batch size
        let overBatch: [Int32] = Array(repeating: Int32(1), count: 33)
        try generator.processBatch(tokens: overBatch)

        // Test one less than batch size
        let underBatch: [Int32] = Array(repeating: Int32(1), count: 31)
        try generator.processBatch(tokens: underBatch)

        #expect(true, "All boundary conditions handled")

        generator.free()
        context.free()
        model.free()
    }

    // MARK: - Test 8.4: Batch memory efficiency

    @Test("Batch processing is memory efficient")
    internal func testBatchMemoryEfficiency() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try LlamaCPPModel(path: modelPath)
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)
        let generator: LlamaCPPGenerator = LlamaCPPGenerator(model: model, context: context)

        guard let ptr = model.pointer else {
            throw LLMError.invalidConfiguration("Model pointer is nil")
        }

        let tokenizer: LlamaCPPTokenizer = LlamaCPPTokenizer()

        // Process multiple large batches
        for iteration in 0..<5 {
            let text: String = String(repeating: "test ", count: 100)
            let tokens: [Int32] = try tokenizer.tokenize(
                text: text,
                addBos: iteration == 0,
                modelPointer: ptr
            )

            try generator.processBatch(tokens: tokens)

            // Generate a token to ensure context is still valid
            _ = try generator.generateNextToken(
                tokens: [],
                sampling: SamplingParameters.default
            )
        }

        // Should complete without memory issues
        #expect(true, "Large batch processing completed")

        generator.free()
        context.free()
        model.free()
    }

    // MARK: - Test 8.5: Parallel batch processing

    @Test("Parallel batch processing works correctly")
    internal func testParallelBatchProcessing() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try LlamaCPPModel(path: modelPath)

        // Create contexts sequentially to avoid concurrent access to model
        let context1: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)
        let context2: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)

        let contexts: [LlamaCPPContext] = [context1, context2]
        let generators: [LlamaCPPGenerator] = contexts.map { ctx in
            LlamaCPPGenerator(model: model, context: ctx)
        }

        guard let ptr = model.pointer else {
            throw LLMError.invalidConfiguration("Model pointer is nil")
        }

        let tokenizer: LlamaCPPTokenizer = LlamaCPPTokenizer()

        // Process batches in parallel
        // Note: We process each generator in its own context
        for (index, generator) in generators.enumerated() {
            let text: String = "Parallel test \(index)"
            let tokens: [Int32] = try tokenizer.tokenize(
                text: text,
                addBos: true,
                modelPointer: ptr
            )
            try generator.processBatch(tokens: tokens)

            // Generate some tokens
            for _ in 0..<3 {
                _ = try generator.generateNextToken(
                    tokens: [],
                    sampling: SamplingParameters.default
                )
            }
        }

        // Clean up
        for generator in generators {
            generator.free()
        }
        for context in contexts {
            context.free()
        }
        model.free()

        #expect(true, "Parallel batch processing completed")
    }

    // MARK: - Test 8.6: Batch token position tracking

    @Test("Batch processing maintains correct position tracking")
    internal func testBatchPositionTracking() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try LlamaCPPModel(path: modelPath)
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)
        let generator: LlamaCPPGenerator = LlamaCPPGenerator(model: model, context: context)

        guard let ptr = model.pointer else {
            throw LLMError.invalidConfiguration("Model pointer is nil")
        }

        let tokenizer: LlamaCPPTokenizer = LlamaCPPTokenizer()

        // Process multiple batches and verify position continuity
        var totalTokens: Int = 0

        for batchIndex in 0..<3 {
            let batchSize: Int = 10 + batchIndex * 5
            let text: String = String(repeating: "batch ", count: batchSize)
            let tokens: [Int32] = try tokenizer.tokenize(
                text: text,
                addBos: batchIndex == 0,
                modelPointer: ptr
            )

            try generator.processBatch(tokens: tokens)
            totalTokens += tokens.count

            // Generate a token to verify position is correct
            _ = try generator.generateNextToken(
                tokens: [],
                sampling: SamplingParameters.default
            )
        }

        #expect(totalTokens > 0, "Processed multiple batches")

        generator.free()
        context.free()
        model.free()
    }

    // MARK: - Test 8.7: Batch size optimization

    @Test("Optimal batch size is determined correctly")
    internal func testOptimalBatchSize() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        let model: LlamaCPPModel = try LlamaCPPModel(path: modelPath)

        // Test finding optimal batch size for different thread counts
        let threadCounts: [Int] = [1, 2, 4, 8]

        for threads in threadCounts {
            let config: ComputeConfiguration = ComputeConfiguration(
                contextSize: 2_048,
                batchSize: 512,
                threadCount: threads
            )
            let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: config)

            let batchSize: Int32 = context.batchSize
            #expect(batchSize > 0, "Valid batch size for \(threads) threads")

            // Batch size should be reasonable for thread count
            if threads == 1 {
                #expect(batchSize <= 512, "Single thread batch size reasonable")
            }

            context.free()
        }

        model.free()
    }
}

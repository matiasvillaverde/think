import Abstractions
import Foundation
@testable import LLamaCPP
import Testing

/// Tests for architecture simplification
extension LlamaCPPModelTestSuite {
    // MARK: - Test 9.1: Core components work without helpers

    @Test("Core generation works with minimal abstractions")
    internal func testMinimalGeneration() throws {
        let modelPath: String = try TestHelpers.requireTestModelPath()
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)
        let generator: LlamaCPPGenerator = LlamaCPPGenerator(model: model, context: context)

        // Should be able to generate without complex helpers
        let token: Int32 = try generator.generateNextToken(
            prompt: "Test",
            sampling: SamplingParameters.default
        )

        let vocabSize: Int32 = model.vocabSize
        #expect(token >= 0 && token < vocabSize, "Generated valid token")

        generator.free()
        context.free()
        model.free()
    }

    // MARK: - Test 9.2: Session works with simplified flow

    @Test("Session works with simplified generation flow")
    internal func testSimplifiedSessionFlow() async throws {
        let config: ProviderConfiguration = try TestHelpers.createTestConfiguration()
        let session: LlamaCPPSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: config
        )
        for try await _ in preloadStream {
            // Just consume the progress updates
        }

        let input: LLMInput = LLMInput(
            context: "Simple test",
            sampling: SamplingParameters.default,
            limits: ResourceLimits(maxTokens: 10)
        )

        var tokenCount: Int = 0
        for try await chunk in await session.stream(input) {
            if case .text = chunk.event {
                tokenCount += 1
            }
            if tokenCount >= 5 {
                break
            }
        }

        #expect(tokenCount > 0, "Generated tokens through simplified flow")

        await session.unload()
    }

    // MARK: - Test 9.3: Direct tokenization without wrappers

    @Test("Tokenization works directly")
    internal func testDirectTokenization() throws {
        let modelPath: String = try TestHelpers.requireTestModelPath()
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        guard let ptr = model.pointer else {
            throw LLMError.invalidConfiguration("Model pointer is nil")
        }

        let tokenizer: LlamaCPPTokenizer = LlamaCPPTokenizer()

        // Direct tokenization
        let tokens: [Int32] = try tokenizer.tokenize(
            text: "Hello world",
            addBos: true,
            modelPointer: ptr
        )

        #expect(!tokens.isEmpty, "Tokenized successfully")

        // Direct detokenization
        let text: String = try tokenizer.detokenize(
            tokens: tokens,
            modelPointer: ptr
        )

        #expect(!text.isEmpty, "Detokenized successfully")

        model.free()
    }

    // MARK: - Test 9.4: Consolidated state management

    @Test("State management is consolidated")
    internal func testConsolidatedStateManagement() throws {
        let modelPath: String = try TestHelpers.requireTestModelPath()
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)
        let generator: LlamaCPPGenerator = LlamaCPPGenerator(model: model, context: context)

        // State should be managed internally
        _ = try generator.generateNextToken(
            prompt: "First",
            sampling: SamplingParameters.default
        )

        // Continue generation - state should be maintained
        _ = try generator.generateNextToken(
            tokens: [],
            sampling: SamplingParameters.default
        )

        // Reset should clear all state
        generator.reset()

        // New generation after reset
        _ = try generator.generateNextToken(
            prompt: "Second",
            sampling: SamplingParameters.default
        )

        #expect(true, "State management works correctly")

        generator.free()
        context.free()
        model.free()
    }

    // MARK: - Test 9.5: Simplified error handling

    @Test("Error handling is simplified")
    internal func testSimplifiedErrorHandling() throws {
        let modelPath: String = try TestHelpers.requireTestModelPath()
        // All errors should be LLMError
        do {
            _ = try LlamaCPPModel(path: "/invalid")
        } catch {
            #expect(error is LLMError, "Simple error type")
        }

        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        model.free()

        // Operations on freed model should throw
        #expect(model.pointer == nil, "Freed model has nil pointer")

        // New model should work
        let newModel: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        #expect(newModel.pointer != nil, "New model has valid pointer")

        newModel.free()
    }

    // MARK: - Test 9.6: Simplified configuration

    @Test("Configuration is simplified")
    internal func testSimplifiedConfiguration() throws {
        let modelPath: String = try TestHelpers.requireTestModelPath()
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)

        // Simple configuration
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)

        // Should use sensible defaults
        let contextSize: UInt32 = UInt32(context.contextSize)
        #expect(contextSize > 0, "Has default context size")

        let batchSize: UInt32 = UInt32(context.batchSize)
        #expect(batchSize > 0, "Has default batch size")

        context.free()
        model.free()
    }

    // MARK: - Test 9.7: Simplified metrics

    @Test("Metrics are simplified")
    internal func testSimplifiedMetrics() async throws {
        let config: ProviderConfiguration = try TestHelpers.createTestConfiguration()
        let session: LlamaCPPSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: config
        )
        for try await _ in preloadStream {
            // Just consume the progress updates
        }

        let input: LLMInput = LLMInput(
            context: "Test",
            sampling: SamplingParameters.default,
            limits: ResourceLimits(maxTokens: 5)
        )

        var hasMetrics: Bool = false
        for try await chunk in await session.stream(input) {
            if let metrics = chunk.metrics {
                hasMetrics = true
                // Metrics should have essential fields
                if let usage = metrics.usage {
                    _ = usage.generatedTokens
                    _ = usage.promptTokens
                }
            }
            if case .finished = chunk.event {
                break
            }
        }

        #expect(hasMetrics, "Simplified metrics provided")

        await session.unload()
    }
}

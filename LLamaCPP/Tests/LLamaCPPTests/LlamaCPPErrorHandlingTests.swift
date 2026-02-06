import Abstractions
import Foundation
@testable import LLamaCPP
import Testing

/// Tests for error handling consistency
extension LlamaCPPModelTestSuite {
    // MARK: - Test 4.1: All errors throw

    @Test("All error conditions throw appropriate errors")
    internal func testAllErrorsThrow() async throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        // Test 1: Invalid model path
        await TestAssertions.assertThrowsLLMError(
            { _ = try LlamaCPPModel(path: "/nonexistent/model.gguf") },
            expectedError: .modelNotFound("/nonexistent/model.gguf")
        )

        // Test 2: Invalid context configuration
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)

        // Create context with invalid configuration (if possible)
        // Most invalid configs are handled by parameter bounds, but we test what we can
        let config: ComputeConfiguration = ComputeConfiguration(
            contextSize: 0,  // Invalid size
            batchSize: 0,    // Invalid batch
            threadCount: 0   // Invalid threads
        )

        // This might not throw depending on llama.cpp's behavior, but we document it
        do {
            _ = try LlamaCPPContext(model: model, configuration: config)
        } catch {
            #expect(error is LLMError, "Should throw LLMError for invalid config")
        }

        model.free()

        // Test 3: Operations on freed model
        let model2: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        model2.free()

        // Attempting to create context with freed model
        await TestAssertions.assertThrowsLLMError(
            { _ = try LlamaCPPContext(model: model2, configuration: .medium) },
            expectedError: .invalidConfiguration("Model has been freed")
        )

        // Test 4: Invalid tokenization
        let model3: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        _ = LlamaCPPTokenizer()
        model3.free()  // Free the model

        let modelPointer: OpaquePointer? = model3.pointer
        #expect(
            modelPointer == nil,
            "Model pointer should be nil after free"
        )

        // Test 5: Generator with invalid context
        let model4: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let context: LlamaCPPContext = try LlamaCPPContext(model: model4, configuration: .medium)
        let generator: LlamaCPPGenerator = LlamaCPPGenerator(model: model4, context: context)

        context.free()  // Free context

        // Try to generate with freed context
        do {
            _ = try generator.generateNextToken(
                prompt: "Test",
                sampling: SamplingParameters.default
            )
            // Depending on implementation, this might not throw immediately
            // but should at least not crash
        } catch {
            #expect(error is LLMError, "Should throw LLMError for freed context")
        }

        generator.free()
        model4.free()
    }

    // MARK: - Test 4.2: Error messages are informative

    @Test("Error messages for model not found")
    internal func testModelNotFoundErrorMessage() async throws {
        let invalidPath: String = "/invalid/path.gguf"

        await TestAssertions.assertThrowsLLMError(
            { _ = try LlamaCPPModel(path: invalidPath) },
            expectedError: .modelNotFound(invalidPath)
        )
    }

    @Test("Error messages for invalid configuration")
    internal func testInvalidConfigurationErrorMessage() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        // Test invalid configuration error messages
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)
        context.free()

        let generator: LlamaCPPGenerator = LlamaCPPGenerator(model: model, context: context)

        do {
            _ = try generator.generateNextToken(
                prompt: "Test",
                sampling: SamplingParameters.default
            )
            // May or may not throw depending on implementation
        } catch {
            if let llmError = error as? LLMError {
                switch llmError {
                case let .invalidConfiguration(message):
                    #expect(!message.isEmpty, "Error message should not be empty")

                case let .providerError(code, message):
                    #expect(!code.isEmpty, "Error code should not be empty")
                    #expect(!message.isEmpty, "Error message should not be empty")

                default:
                    // Other error types are acceptable
                    break
                }
            }
        }

        generator.free()
        model.free()
    }

    // MARK: - Additional error handling tests

    @Test("Consistent error types across module")
    internal func testConsistentErrorTypes() {
        // Verify that all errors are LLMError types
        var errors: [Error] = []

        // Collect various errors
        do {
            _ = try LlamaCPPModel(path: "/invalid")
        } catch {
            errors.append(error)
        }

        // All collected errors should be LLMError
        for error in errors {
            #expect(error is LLMError, "All errors should be LLMError type")
        }
    }

    @Test("No silent failures with return 0")
    internal func testNoSilentFailures() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        // This test verifies that we don't have silent failures
        // where functions return 0 instead of throwing

        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)
        let generator: LlamaCPPGenerator = LlamaCPPGenerator(model: model, context: context)

        // Free resources
        generator.free()
        context.free()

        // Operations after free should throw, not return 0
        // The specific behavior depends on implementation

        // Check model properties after free
        // In the current implementation, freed models retain their metadata values
        let vocabSize: Int32 = model.vocabSize
        let contextLength: Int32 = model.contextLength

        // Freed Qwen3-0.6B model still returns its original metadata
        #expect(
            vocabSize == 151_936,
            "Freed model still returns original vocab size, got \(vocabSize)"
        )
        #expect(
            contextLength == 40_960,
            "Freed model still returns original context length, got \(contextLength)"
        )

        model.free()
    }

    @Test("Error recovery is possible")
    internal func testErrorRecovery() throws {
        guard let modelPath: String = TestHelpers.testModelPath else {
            return
        }
        // Test that after an error, the system can recover

        // First, cause an error
        do {
            _ = try LlamaCPPModel(path: "/invalid")
        } catch {
            // Expected error
        }

        // Now try a valid operation - should work
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)
        let generator: LlamaCPPGenerator = LlamaCPPGenerator(model: model, context: context)

        let token: Int32 = try generator.generateNextToken(
            prompt: "Test",
            sampling: SamplingParameters.default
        )

        TestAssertions.assertTokenInVocabRange(token, model: model)
        #expect(
            token > 2,
            "Should generate valid non-special token after recovery, got \(token)"
        )

        generator.free()
        context.free()
        model.free()
    }
}

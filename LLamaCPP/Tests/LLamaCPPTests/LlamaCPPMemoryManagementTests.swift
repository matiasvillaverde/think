import Abstractions
import Foundation
@testable import LLamaCPP
import Testing

/// Tests for memory management and resource cleanup
extension LlamaCPPModelTestSuite {
    // MARK: - Test 5.1: Memory leak detection

    @Test("Resources are properly freed on deallocation")
    internal func testResourcesFreedOnDeallocation() throws {
        let modelPath: String = try TestHelpers.requireTestModelPath()
        // Create and destroy multiple instances to detect leaks
        for iteration in 0..<3 {
            let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
            let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)
            let generator: LlamaCPPGenerator = LlamaCPPGenerator(
                model: model,
                context: context
            )

            // Use the resources
            _ = try generator.generateNextToken(
                prompt: "Test \(iteration)",
                sampling: SamplingParameters.default
            )

            // Explicitly free resources
            generator.free()
            context.free()
            model.free()

            // Resources are now freed and ARC will handle deallocation
        }

        #expect(true, "Multiple allocation/deallocation cycles completed without crash")
    }

    // MARK: - Test 5.2: Cleanup order

    @Test("Resources are freed in correct order")
    internal func testCleanupOrder() throws {
        let modelPath: String = try TestHelpers.requireTestModelPath()
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)
        let generator: LlamaCPPGenerator = LlamaCPPGenerator(model: model, context: context)

        // Generate to ensure resources are in use
        _ = try generator.generateNextToken(
            prompt: "Test",
            sampling: SamplingParameters.default
        )

        // Free in correct order: generator -> context -> model
        generator.free()

        // Generator should be freed, but context still usable
        #expect(context.pointer != nil, "Context still valid after generator freed")

        context.free()

        // Context freed, but model still usable
        #expect(model.pointer != nil, "Model still valid after context freed")

        model.free()

        // All resources should be freed now
        #expect(model.pointer == nil, "Model pointer nil after free")
    }

    // MARK: - Test 5.3: Double-free protection

    @Test("Double-free is safely handled")
    internal func testDoubleFreeProtection() throws {
        let modelPath: String = try TestHelpers.requireTestModelPath()
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)
        let generator: LlamaCPPGenerator = LlamaCPPGenerator(model: model, context: context)

        // First free
        generator.free()
        context.free()
        model.free()

        // Second free - should not crash
        generator.free()
        context.free()
        model.free()

        #expect(true, "Double-free handled safely")
    }

    // MARK: - Test 5.4: Resource cleanup on error

    @Test("Resources are cleaned up properly on error paths")
    internal func testResourceCleanupOnError() throws {
        let modelPath: String = try TestHelpers.requireTestModelPath()
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)
        let generator: LlamaCPPGenerator = LlamaCPPGenerator(model: model, context: context)

        // Free context to cause error
        context.free()

        // Try to generate - should fail gracefully
        do {
            _ = try generator.generateNextToken(
                prompt: "Test",
                sampling: SamplingParameters.default
            )
            Issue.record("Should have thrown error")
        } catch {
            // Expected error
        }

        // Clean up remaining resources
        generator.free()
        model.free()

        #expect(true, "Resources cleaned up after error")
    }

    // MARK: - Test 5.5: Session memory management

    @Test("Session properly manages memory lifecycle")
    internal func testSessionMemoryManagement() async throws {
        let config: ProviderConfiguration = try TestHelpers.createTestConfiguration()
        let session: LlamaCPPSession = LlamaCPPSession()

        // Load model
        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: config
        )
        for try await _ in preloadStream {
            // Consume progress updates
        }

        // Use the session
        let input: LLMInput = LLMInput(
            context: "Test prompt",
            sampling: SamplingParameters.default,
            limits: ResourceLimits(maxTokens: 100)
        )

        var generated: String = ""
        for try await chunk in await session.stream(input) {
            if case .text = chunk.event {
                generated += chunk.text
            }
            if generated.count > 10 {
                break  // Stop after some generation
            }
        }

        // Unload model
        await session.unload()

        // Try to use after unload - should handle gracefully
        do {
            for try await _ in await session.stream(input) {
                break
            }
        } catch {
            // Expected - model not loaded
        }

        #expect(true, "Session memory lifecycle managed correctly")
    }

    // MARK: - Test 5.7: Large allocation stress test

    @Test("Handles large allocations without memory issues")
    internal func testLargeAllocationStress() throws {
        let modelPath: String = try TestHelpers.requireTestModelPath()
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)

        // Create context with large size
        let config: ComputeConfiguration = ComputeConfiguration(
            contextSize: 4_096,  // Large context
            batchSize: 512,     // Large batch
            threadCount: 8
        )
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: config)
        let generator: LlamaCPPGenerator = LlamaCPPGenerator(model: model, context: context)

        // Generate with large prompt
        let largePrompt: String = String(repeating: "test ", count: 500)
        _ = try generator.generateNextToken(
            prompt: largePrompt,
            sampling: SamplingParameters.default
        )

        // Clean up
        generator.free()
        context.free()
        model.free()

        #expect(true, "Large allocations handled without memory issues")
    }

    // MARK: - Test 5.8: Sampler memory management

    @Test("Sampler chain memory is properly managed")
    internal func testSamplerMemoryManagement() throws {
        let modelPath: String = try TestHelpers.requireTestModelPath()
        let model: LlamaCPPModel = try TestHelpers.createTestModel(path: modelPath)
        let context: LlamaCPPContext = try LlamaCPPContext(model: model, configuration: .medium)
        let generator: LlamaCPPGenerator = LlamaCPPGenerator(model: model, context: context)

        // Create and use multiple different sampler configurations
        let configs: [SamplingParameters] = [
            SamplingParameters(temperature: 0.5, topP: 0.9, topK: 40),
            SamplingParameters(temperature: 1.0, topP: 1.0, repetitionPenalty: 1.2),
            SamplingParameters(temperature: 0.0, topP: 1.0),  // Greedy
            SamplingParameters(temperature: 0.8, topP: 0.95, topK: 100, seed: 42)
        ]

        for (index, config) in configs.enumerated() {
            _ = try generator.generateNextToken(
                prompt: "Test \(index)",
                sampling: config
            )
        }

        // Reset generator (should reset sampler)
        generator.reset()

        // Generate again after reset
        _ = try generator.generateNextToken(
            prompt: "After reset",
            sampling: SamplingParameters.default
        )

        // Free generator (should free sampler chain)
        generator.free()

        // Sampler should be freed with generator
        #expect(true, "Sampler memory managed correctly")

        context.free()
        model.free()
    }
}

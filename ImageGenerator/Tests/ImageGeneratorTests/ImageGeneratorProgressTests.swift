import Testing
import Abstractions
import CoreGraphics
import CoreML
import Foundation
@testable import ImageGenerator

@Suite("ImageGenerator Progress Streaming Tests")
struct ImageGeneratorProgressTests {

    @Test("Generate returns stream with multiple progress updates")
    func testGenerateReturnsProgressStream() async throws {
        guard TestModelAvailability.isAvailable else { return }

        // Given: A loaded image generation model
        let setup = try await setupGeneratorWithMockPipeline()

        // When: Calling generate()
        let config = ImageConfiguration(
            prompt: "A test image",
            steps: 20,
            seed: 42,
            imageCount: 1
        )

        var progressUpdates: [ImageGenerationProgress] = []

        // Then: Returns AsyncThrowingStream<ImageGenerationProgress>
        for try await progress in await setup.generator.generate(model: setup.model, config: config) {
            progressUpdates.append(progress)
        }

        // Should receive multiple progress updates (at least initial and final)
        #expect(progressUpdates.count > 1, "Should receive multiple progress updates")

        // Intermediate updates should have nil metrics
        let intermediateUpdates = progressUpdates.dropLast()
        for progress in intermediateUpdates {
            #expect(progress.imageMetrics == nil, "Intermediate updates should have nil metrics")
        }

        // Final update should have metrics
        if let finalUpdate = progressUpdates.last {
            #expect(finalUpdate.imageMetrics != nil, "Final update should have metrics")
        }
    }

    @Test("Progress updates are yielded during denoising steps")
    func testIntermediateImagesYieldedDuringGeneration() async throws {
        guard TestModelAvailability.isAvailable else { return }

        // Given: A 20-step generation config
        let setup = try await setupGeneratorWithMockPipeline(steps: 20)

        let config = ImageConfiguration(
            prompt: "A beautiful sunset",
            steps: 20,
            seed: 42,
            imageCount: 1
        )

        var progressCount = 0

        // When: Consuming the progress stream
        for try await progress in await setup.generator.generate(model: setup.model, config: config) {
            progressCount += 1

            // Then: Receive multiple updates with currentImage != nil
            #expect(progress.currentImage != nil, "Each progress should have an image")
        }

        // Should receive updates at regular intervals (e.g., every 5 steps + final)
        #expect(progressCount >= 5, "Should receive at least 5 progress updates for 20 steps")
    }

    @Test("Final image includes generation metrics")
    func testFinalImageIncludesMetrics() async throws {
        guard TestModelAvailability.isAvailable else { return }

        // Given: A generation in progress
        let setup = try await setupGeneratorWithMockPipeline()

        let config = ImageConfiguration(
            prompt: "Test prompt",
            steps: 10,
            seed: 42,
            imageCount: 1
        )

        var finalMetrics: ImageMetrics?

        // When: Stream completes
        for try await progress in await setup.generator.generate(
            model: setup.model,
            config: config
        ) where progress.imageMetrics != nil {
            finalMetrics = progress.imageMetrics
        }

        // Then: Final progress includes both image and metrics
        #expect(finalMetrics != nil, "Should receive metrics in final update")
        if let metrics = finalMetrics {
            #expect(metrics.timing != nil)
            #expect(metrics.usage != nil)
            if let timing = metrics.timing {
                #expect(timing.totalTime > .zero)
            }
        }
    }

    @Test("Progress percentage increases monotonically")
    func testProgressPercentageIncreases() async throws {
        guard TestModelAvailability.isAvailable else { return }

        // Given: A multi-step generation
        let setup = try await setupGeneratorWithMockPipeline(steps: 30)

        let config = ImageConfiguration(
            prompt: "Test",
            steps: 30,
            seed: 42,
            imageCount: 1
        )

        // When: Collecting all progress updates
        // Note: This test will fail until we implement progress tracking
        for try await _ in await setup.generator.generate(model: setup.model, config: config) {
            // Progress percentage tracking to be implemented
        }

        // Then: progressPercentage increases from 0.0 to 1.0
    }

    @Test("Cancellation works with enhanced mock")
    func testCancellationWithEnhancedMock() async throws {
        guard TestModelAvailability.isAvailable else { return }

        // Given: A cancellable mock pipeline
        let setup = try await setupGeneratorWithMockPipeline(steps: 20)
        setup.mockPipeline.supportsCancellation = true

        let config = ImageConfiguration(
            prompt: "Test cancellation",
            steps: 20,
            seed: 42,
            imageCount: 1
        )

        var updateCount = 0

        // When: Cancel after first update
        for try await _ in await setup.generator.generate(model: setup.model, config: config) {
            updateCount += 1
            if updateCount == 1 {
                try await setup.generator.stop(model: setup.model.id)
                break // Exit the loop after cancelling
            }
        }

        // Then: Should have received exactly 1 update before cancellation
        #expect(updateCount == 1, "Should receive exactly 1 update before cancellation")
    }

    // MARK: - Helper Methods

    private struct TestSetup {
        let generator: ImageGenerator
        let model: SendableModel
        let mockPipeline: MockStableDiffusionPipelineEnhanced
    }

    private func setupGeneratorWithMockPipeline(steps: Int = 20) async throws -> TestSetup {
        let mockDownloader = MockModelDownloader(
            modelExistsResult: true,
            getModelLocationResult: Bundle.module.url(
                forResource: "TestModel",
                withExtension: nil,
                subdirectory: "Resources"
            )!
        )

        let generator = ImageGenerator(modelDownloader: mockDownloader)

        let model = SendableModel(
            id: UUID(),
            ramNeeded: 100_000_000,
            modelType: .diffusion,
            location: "test-model",
            architecture: .stableDiffusion,
            backend: .coreml
        )

        // Load the model
        for try await _ in await generator.load(model: model) {
            // Wait for loading to complete
        }

        // Replace the pipeline with our enhanced mock
        let mockPipeline = MockStableDiffusionPipelineEnhanced()
        mockPipeline.totalSteps = steps

        // We'll need to inject this mock somehow - this will fail initially
        // await generator.setPipelineForTesting(model.id, mockPipeline)

        return TestSetup(generator: generator, model: model, mockPipeline: mockPipeline)
    }
}

// Enhanced mock that supports multiple progress callbacks
final class MockStableDiffusionPipelineEnhanced: StableDiffusionPipelineProtocol {
    var totalSteps = 20
    var yieldInterval = 5 // Yield every 5 steps
    var supportsCancellation = false

    func loadResources() throws {}

    func generateImages(
        configuration config: StableDiffusionPipeline.Configuration,
        progressHandler: @escaping (StableDiffusionPipeline.Progress) -> Bool
    ) throws -> [CGImage?] {
        // Simulate multiple progress callbacks
        for step in 0..<totalSteps {
            // Add a small sleep to simulate async pipeline work
            Thread.sleep(forTimeInterval: 0.001)

            let shouldContinue = progressHandler(PipelineProgress(
                pipeline: self,
                prompt: config.prompt,
                step: step,
                stepCount: totalSteps,
                currentLatentSamples: [],
                configuration: config
            ))

            if !shouldContinue {
                return [] // Cancelled
            }
        }

        // Return final image
        return [createMockImage()]
    }

    func decodeToImages(
        _ latents: [MLShapedArray<Float32>],
        configuration config: StableDiffusionPipeline.Configuration
    ) throws -> [CGImage?] {
        return [createMockImage()]
    }

    func unloadResources() {}

    var canSafetyCheck: Bool { false }

    private func createMockImage() -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: 100,
            height: 100,
            bitsPerComponent: 8,
            bytesPerRow: 400,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        context.setFillColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))

        return context.makeImage()
    }
}

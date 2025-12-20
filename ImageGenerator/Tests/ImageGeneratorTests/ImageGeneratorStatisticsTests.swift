import Testing
@testable import ImageGenerator
import Abstractions
import CoreGraphics
import Foundation

// Tag extension for acceptance tests
private extension Testing.Tag {
    @Testing.Tag static var acceptance: Self
}

@Suite("ImageGenerator Statistics Tests")
struct ImageGeneratorStatisticsTests {
    // Note: These tests require real CoreML models to function properly.
    // The metrics infrastructure is tested using mock pipelines in ImageGeneratorMetricsTests.
    // When real models are available, these tests can be re-enabled to verify end-to-end functionality.

    @Test(.tags(.acceptance))
    func testEndToEndMetricsFlowWithRealModel() async throws {
        // This test requires a real CoreML model and is skipped in CI
        let (generator, model) = setupRealModelTest()

        // Skip if no real model is available
        guard isRealModelAvailable(model: model) else { return }

        let config = ImageConfiguration(
            prompt: "A beautiful sunset",
            steps: 20,
            seed: 42,
            imageCount: 1
        )

        // Generate and verify
        var receivedMetrics: ImageMetrics?
        for try await progress in await generator.generate(model: model, config: config) {
            receivedMetrics = progress.imageMetrics
        }

        verifyCompleteMetrics(receivedMetrics, config: config)
    }

    private func setupRealModelTest() -> (ImageGenerator, SendableModel) {
        let mockDownloader = MockModelDownloader(
            modelExistsResult: true,
            getModelLocationResult: Bundle.module.bundleURL
        )
        let generator = ImageGenerator(modelDownloader: mockDownloader)
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 6_000_000_000,
            modelType: .diffusion,
            location: "stable-diffusion/stable-diffusion-xl-base-1.0",
            architecture: .stableDiffusion,
            backend: .coreml
        )
        return (generator, model)
    }

    private func isRealModelAvailable(model: SendableModel) -> Bool {
        let mockDownloader = MockModelDownloader()
        let modelPath = mockDownloader.getModelLocation(for: model.location)
        return modelPath.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
    }

    private func verifyCompleteMetrics(_ metrics: ImageMetrics?, config: ImageConfiguration) {
        #expect(metrics != nil, "Should receive metrics")
        if let metrics {
            // Verify timing metrics
            if let timing = metrics.timing {
                #expect(timing.totalTime > .zero)
                if let modelLoadTime = timing.modelLoadTime {
                    #expect(modelLoadTime > .zero)
                }
                if let promptTime = timing.promptEncodingTime {
                    #expect(promptTime > .zero)
                }
            }

            // Verify usage metrics  
            if let usage = metrics.usage {
                #expect(usage.activeMemory > 0)
                #expect(usage.peakMemory >= usage.activeMemory)
                #expect(usage.modelParameters >= 0)
            }

            // Verify generation metrics
            if let generation = metrics.generation {
                #expect(generation.steps == config.steps)
                #expect(generation.width > 0)
                #expect(generation.height > 0)
            }
        }
    }
}

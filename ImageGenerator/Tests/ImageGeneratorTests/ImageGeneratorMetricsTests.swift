import Testing
@testable import ImageGenerator
import Abstractions
import CoreGraphics
import Foundation

@Suite("ImageGenerator Metrics Tests")
struct ImageGeneratorMetricsTests {
    @Test
    func testImageMetricsCollectorIntegration() async {
        // Given
        let collector = await setupCollector()

        // When
        let metrics = await collector.createMetrics()

        // Then
        verifyComprehensiveMetrics(metrics)
    }

    private func setupCollector() async -> ImageMetricsCollector {
        let collector = ImageMetricsCollector()

        await collector.startModelLoading()
        await collector.endModelLoading()

        await collector.setModelInfo(
            name: "stable-diffusion-v1-5",
            parameters: 860_000_000
        )

        await collector.startPromptEncoding()
        await collector.setTokenCounts(prompt: 77)
        await collector.endPromptEncoding()

        await collector.setGenerationConfig(
            width: 512,
            height: 512,
            steps: 20,
            guidanceScale: 7.5,
            scheduler: "DPMSolverMultistep",
            seed: 42,
            batchSize: 1
        )

        await collector.startDenoising()
        for _ in 0..<20 {
            await collector.recordDenoisingStep()
        }

        await collector.startVAEDecoding()
        await collector.endVAEDecoding()

        await collector.updateMemoryUsage(
            active: 1024 * 1024 * 512,
            peak: 1024 * 1024 * 768
        )

        return collector
    }

    private func verifyComprehensiveMetrics(_ metrics: ImageMetrics) {
        #expect(metrics.timing != nil)
        #expect(metrics.usage != nil)
        #expect(metrics.generation != nil)

        if let timing = metrics.timing {
            #expect(timing.totalTime > .zero)
            #expect(timing.denoisingStepTimes.count == 20)
        }

        if let usage = metrics.usage {
            #expect(usage.modelParameters == 860_000_000)
            #expect(usage.promptTokens == 77)
            #expect(usage.activeMemory == 1024 * 1024 * 512)
            #expect(usage.peakMemory == 1024 * 1024 * 768)
        }

        if let generation = metrics.generation {
            #expect(generation.width == 512)
            #expect(generation.height == 512)
            #expect(generation.steps == 20)
            #expect(generation.guidanceScale == 7.5)
            #expect(generation.scheduler == "DPMSolverMultistep")
            #expect(generation.seed == 42)
            #expect(generation.batchSize == 1)
        }
    }

    @Test
    func testGenerateSingleImageWithMockPipeline() async throws {
        // Given - Setup mock components
        let generator = await setupMockGenerator()
        let model = createTestModel(id: generator.modelId)
        let config = ImageConfiguration(prompt: "Test prompt", seed: 42, imageCount: 1)

        // When - Generate image
        var receivedMetrics: ImageMetrics?
        for try await progress in await generator.instance.generate(model: model, config: config) {
            receivedMetrics = progress.imageMetrics
        }

        // Then - Verify metrics
        verifyMetrics(receivedMetrics, expectedPrompt: "Test prompt")
    }

    // Helper methods to reduce function length
    private func setupMockGenerator() async -> (instance: ImageGenerator, modelId: UUID) {
        let mockDownloader = MockModelDownloader(
            modelExistsResult: true,
            getModelLocationResult: Bundle.module.bundleURL
        )
        let generator = ImageGenerator(modelDownloader: mockDownloader)
        let modelId = UUID()

        await generator.setPipeline(MockStableDiffusionPipeline(), for: modelId)

        let collector = ImageMetricsCollector()
        await collector.setModelInfo(name: "test-model", parameters: 500_000)
        await generator.setCollector(collector, for: modelId)

        return (generator, modelId)
    }

    private func createTestModel(id: UUID) -> SendableModel {
        SendableModel(
            id: id,
            ramNeeded: 4_000_000_000,
            modelType: .diffusion,
            location: "test/stable-diffusion",
            architecture: .stableDiffusion,
            backend: .coreml,
            locationKind: .huggingFace,
            locationLocal: nil,
            locationBookmark: nil
        )
    }

    private func verifyMetrics(_ metrics: ImageMetrics?, expectedPrompt: String) {
        #expect(metrics != nil)
        if let metrics {
            if let usage = metrics.usage {
                #expect(usage.modelParameters == 500_000)
                #expect(usage.activeMemory > 0)
            }

            if let timing = metrics.timing {
                #expect(timing.totalTime > .zero)
            }
        }
    }
}

// Helper extension to access internal properties for testing
extension ImageGenerator {
    func setPipeline(_ pipeline: any StableDiffusionPipelineProtocol, for modelId: UUID) {
        pipelines[modelId] = pipeline
    }

    func setCollector(_ collector: ImageMetricsCollector, for modelId: UUID) {
        metricsCollectors[modelId] = collector
    }
}

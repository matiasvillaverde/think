import Testing
import Foundation
@testable import Abstractions

@Suite("ImageMetrics Tests")
struct ImageMetricsTests {
    @Test("ImageMetrics initialization with all components")
    func testInitializationComplete() {
        let timing = ImageTimingMetrics(
            totalTime: .seconds(5),
            modelLoadTime: .seconds(2),
            promptEncodingTime: .milliseconds(500),
            denoisingStepTimes: [.milliseconds(100), .milliseconds(110)],
            vaeDecodingTime: .milliseconds(300)
        )

        let usage = ImageUsageMetrics(
            activeMemory: 1024 * 1024 * 512,
            peakMemory: 1024 * 1024 * 1024,
            modelParameters: 1_000_000_000,
            promptTokens: 77,
            negativePromptTokens: 50,
            gpuMemory: 1024 * 1024 * 2048,
            usedGPU: true
        )

        let generation = ImageGenerationMetrics(
            width: 512,
            height: 512,
            steps: 20,
            guidanceScale: 7.5,
            scheduler: "DPMSolverMultistep",
            modelName: "stable-diffusion-v1-5",
            seed: 42,
            safetyCheckPassed: true,
            batchSize: 1
        )

        let metrics = ImageMetrics(
            timing: timing,
            usage: usage,
            generation: generation
        )

        #expect(metrics.timing != nil)
        #expect(metrics.usage != nil)
        #expect(metrics.generation != nil)
    }

    @Test("ImageMetrics initialization with nil components")
    func testInitializationEmpty() {
        let metrics = ImageMetrics()

        #expect(metrics.timing == nil)
        #expect(metrics.usage == nil)
        #expect(metrics.generation == nil)
    }

    @Test("ImageMetrics Codable conformance")
    func testCodable() throws {
        let timing = ImageTimingMetrics(
            totalTime: .seconds(3),
            denoisingStepTimes: [.milliseconds(150)]
        )

        let usage = ImageUsageMetrics(
            activeMemory: 1024 * 1024 * 256,
            peakMemory: 1024 * 1024 * 512,
            modelParameters: 500_000_000
        )

        let original = ImageMetrics(timing: timing, usage: usage)

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ImageMetrics.self, from: data)

        #expect(decoded.timing?.totalTime == original.timing?.totalTime)
        #expect(decoded.usage?.activeMemory == original.usage?.activeMemory)
        #expect(decoded.generation == nil)
    }

    @Test("ImageTimingMetrics stores durations correctly")
    func testTimingMetrics() {
        let timing = ImageTimingMetrics(
            totalTime: .seconds(10),
            modelLoadTime: .seconds(3),
            promptEncodingTime: .milliseconds(200),
            denoisingStepTimes: [.milliseconds(100), .milliseconds(120), .milliseconds(130)],
            vaeDecodingTime: .milliseconds(500),
            postProcessingTime: .milliseconds(50)
        )

        #expect(timing.totalTime == .seconds(10))
        #expect(timing.modelLoadTime == .seconds(3))
        #expect(timing.promptEncodingTime == .milliseconds(200))
        #expect(timing.denoisingStepTimes.count == 3)
        #expect(timing.vaeDecodingTime == .milliseconds(500))
        #expect(timing.postProcessingTime == .milliseconds(50))
    }

    @Test("ImageUsageMetrics stores memory information")
    func testUsageMetrics() {
        let usage = ImageUsageMetrics(
            activeMemory: 1024 * 1024 * 1024,
            peakMemory: 1024 * 1024 * 2048,
            modelParameters: 1_500_000_000,
            promptTokens: 100,
            negativePromptTokens: 77,
            gpuMemory: 1024 * 1024 * 4096,
            usedGPU: true
        )

        #expect(usage.activeMemory == 1024 * 1024 * 1024)
        #expect(usage.peakMemory == 1024 * 1024 * 2048)
        #expect(usage.modelParameters == 1_500_000_000)
        #expect(usage.promptTokens == 100)
        #expect(usage.negativePromptTokens == 77)
        #expect(usage.gpuMemory == UInt64(1024 * 1024 * 4096))
        #expect(usage.usedGPU == true)
    }

    @Test("ImageGenerationMetrics stores generation parameters")
    func testGenerationMetrics() {
        let generation = ImageGenerationMetrics(
            width: 1024,
            height: 768,
            steps: 50,
            guidanceScale: 10.0,
            scheduler: "EulerAncestral",
            modelName: "sdxl-turbo",
            seed: 12345,
            safetyCheckPassed: false,
            batchSize: 4
        )

        #expect(generation.width == 1024)
        #expect(generation.height == 768)
        #expect(generation.steps == 50)
        #expect(generation.guidanceScale == 10.0)
        #expect(generation.scheduler == "EulerAncestral")
        #expect(generation.modelName == "sdxl-turbo")
        #expect(generation.seed == 12345)
        #expect(generation.safetyCheckPassed == false)
        #expect(generation.batchSize == 4)
    }

    @Test("ImageGenerationMetrics default values")
    func testGenerationMetricsDefaults() {
        let generation = ImageGenerationMetrics(
            width: 512,
            height: 512,
            steps: 20,
            guidanceScale: 7.5,
            scheduler: "DPMSolverMultistep",
            modelName: "stable-diffusion"
        )

        #expect(generation.seed == nil)
        #expect(generation.safetyCheckPassed == true)
        #expect(generation.batchSize == 1)
    }

    @Test("ImageGenerationProgress can include ImageMetrics")
    func testImageGenerationProgressWithMetrics() {
        let timing = ImageTimingMetrics(
            totalTime: .seconds(5),
            denoisingStepTimes: [.milliseconds(100)]
        )

        let metrics = ImageMetrics(timing: timing)

        let progress = ImageGenerationProgress(
            stage: .completed,
            currentImage: nil,
            lastStepTime: 5.0,
            description: "Completed",
            progressPercentage: 1.0,
            imageMetrics: metrics
        )

        #expect(progress.imageMetrics != nil)
        #expect(progress.imageMetrics?.timing?.totalTime == .seconds(5))
    }

    @Test("ImageGenerationProgress backward compatibility")
    func testImageGenerationProgressBackwardCompatibility() {
        // Test that old code continues to work without imageMetrics
        let progress = ImageGenerationProgress(
            stage: .generating(step: 10, totalSteps: 20),
            currentImage: nil,
            lastStepTime: 0.5,
            description: "Generating",
            progressPercentage: 0.5
        )

        #expect(progress.imageMetrics == nil)
        #expect(progress.stage == .generating(step: 10, totalSteps: 20))
    }
}

import Testing
import Foundation
@testable import ImageGenerator
@testable import Abstractions

@Suite("ImageMetricsCollector Tests")
struct ImageMetricsCollectorTests {
    @Test("Collector tracks timing correctly")
    func testTimingCollection() async {
        let collector = ImageMetricsCollector()

        // Simulate model loading
        await collector.startModelLoading()
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        await collector.endModelLoading()

        // Simulate prompt encoding
        await collector.startPromptEncoding()
        try? await Task.sleep(nanoseconds: 5_000_000) // 5ms
        await collector.endPromptEncoding()

        // Simulate denoising steps
        await collector.startDenoising()
        for _ in 0..<3 {
            try? await Task.sleep(nanoseconds: 2_000_000) // 2ms per step
            await collector.recordDenoisingStep()
        }

        // Simulate VAE decoding
        await collector.startVAEDecoding()
        try? await Task.sleep(nanoseconds: 8_000_000) // 8ms
        await collector.endVAEDecoding()

        let metrics = await collector.createMetrics()

        #expect(metrics.timing != nil)
        #expect(metrics.timing?.modelLoadTime != nil)
        #expect(metrics.timing?.promptEncodingTime != nil)
        #expect(metrics.timing?.denoisingStepTimes.count == 3)
        #expect(metrics.timing?.vaeDecodingTime != nil)
    }

    @Test("Collector tracks memory usage")
    func testMemoryCollection() async {
        let collector = ImageMetricsCollector()

        await collector.updateMemoryUsage(active: 512_000_000, peak: 768_000_000)
        await collector.updateGPUMemory(1024_000_000)

        let metrics = await collector.createMetrics()

        #expect(metrics.usage != nil)
        #expect(metrics.usage?.activeMemory == 512_000_000)
        #expect(metrics.usage?.peakMemory == 768_000_000)
        #expect(metrics.usage?.gpuMemory == 1024_000_000)
        #expect(metrics.usage?.usedGPU == true)
    }

    @Test("Collector tracks model information")
    func testModelInfoCollection() async {
        let collector = ImageMetricsCollector()

        await collector.setModelInfo(
            name: "stable-diffusion-xl",
            parameters: 2_600_000_000
        )

        let metrics = await collector.createMetrics()

        #expect(metrics.usage?.modelParameters == 2_600_000_000)
    }

    @Test("Collector tracks generation parameters")
    func testGenerationParametersCollection() async {
        let collector = ImageMetricsCollector()

        await collector.setModelInfo(
            name: "sd-turbo",
            parameters: 865_000_000
        )

        await collector.setGenerationConfig(
            width: 1024,
            height: 768,
            steps: 25,
            guidanceScale: 8.5,
            scheduler: "DPMSolverMultistep",
            seed: 42,
            batchSize: 2
        )

        await collector.setTokenCounts(prompt: 77, negativePrompt: 50)

        let metrics = await collector.createMetrics()

        #expect(metrics.generation != nil)
        #expect(metrics.generation?.width == 1024)
        #expect(metrics.generation?.height == 768)
        #expect(metrics.generation?.steps == 25)
        #expect(metrics.generation?.guidanceScale == 8.5)
        #expect(metrics.generation?.scheduler == "DPMSolverMultistep")
        #expect(metrics.generation?.seed == 42)
        #expect(metrics.generation?.batchSize == 2)
        #expect(metrics.generation?.modelName == "sd-turbo")

        #expect(metrics.usage?.promptTokens == 77)
        #expect(metrics.usage?.negativePromptTokens == 50)
    }

    @Test("Collector handles partial data gracefully")
    func testPartialDataCollection() async {
        let collector = ImageMetricsCollector()

        // Only set some timing data
        await collector.startPromptEncoding()
        await collector.endPromptEncoding()

        // Only set memory data
        await collector.updateMemoryUsage(active: 256_000_000, peak: 256_000_000)

        let metrics = await collector.createMetrics()

        // Timing should have total time and prompt encoding time
        #expect(metrics.timing != nil)
        #expect(metrics.timing?.totalTime != nil)
        #expect(metrics.timing?.promptEncodingTime != nil)
        #expect(metrics.timing?.modelLoadTime == nil)

        // Usage should have memory data
        #expect(metrics.usage != nil)
        #expect(metrics.usage?.activeMemory == 256_000_000)

        // Generation should be nil (missing required fields)
        #expect(metrics.generation == nil)
    }

    @Test("Collector tracks peak memory correctly")
    func testPeakMemoryTracking() async {
        let collector = ImageMetricsCollector()

        await collector.updateMemoryUsage(active: 100_000_000, peak: 150_000_000)
        await collector.updateMemoryUsage(active: 200_000_000, peak: 250_000_000)
        await collector.updateMemoryUsage(active: 150_000_000, peak: 200_000_000)

        let metrics = await collector.createMetrics()

        // Peak should be the maximum peak value seen
        #expect(metrics.usage?.peakMemory == 250_000_000)
        // Active should be the last value
        #expect(metrics.usage?.activeMemory == 150_000_000)
    }

    @Test("Collector creates complete metrics")
    func testCompleteMetricsCreation() async {
        let collector = ImageMetricsCollector()

        // Set all data
        await collector.setModelInfo(name: "sdxl-base", parameters: 2_600_000_000)
        await collector.setGenerationConfig(
            width: 512,
            height: 512,
            steps: 20,
            guidanceScale: 7.5,
            scheduler: "EulerAncestral"
        )
        await collector.setTokenCounts(prompt: 77)
        await collector.updateMemoryUsage(active: 1_000_000_000, peak: 1_500_000_000)

        // Perform timing operations
        await collector.startModelLoading()
        await collector.endModelLoading()
        await collector.startPromptEncoding()
        await collector.endPromptEncoding()
        await collector.startDenoising()
        await collector.recordDenoisingStep()
        await collector.startVAEDecoding()
        await collector.endVAEDecoding()

        let metrics = await collector.createMetrics()

        // All three components should be present
        #expect(metrics.timing != nil)
        #expect(metrics.usage != nil)
        #expect(metrics.generation != nil)
    }
}

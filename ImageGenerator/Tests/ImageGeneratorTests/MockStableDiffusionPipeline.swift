import CoreGraphics
import CoreML
@testable import ImageGenerator

/// Mock StableDiffusionPipeline for testing
final class MockStableDiffusionPipeline: StableDiffusionPipelineProtocol {
    var generateImagesCallCount = 0
    var lastConfiguration: StableDiffusionPipeline.Configuration?
    var shouldReturnImages = true

    func loadResources() throws {
        // No-op for mock
    }

    func generateImages(
        configuration config: StableDiffusionPipeline.Configuration,
        progressHandler: @escaping (StableDiffusionPipeline.Progress) -> Bool
    ) throws -> [CGImage?] {
        generateImagesCallCount += 1
        lastConfiguration = config

        // Simulate progress callbacks
        _ = progressHandler(PipelineProgress(
            pipeline: self,
            prompt: config.prompt,
            step: 0,
            stepCount: config.stepCount,
            currentLatentSamples: [],
            configuration: config
        ))

        // Return mock images if enabled
        if shouldReturnImages {
            // Create a simple 1x1 pixel image
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)

            guard let context = CGContext(
                data: nil,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            ) else {
                return []
            }

            // Fill with red color
            context.setFillColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))

            return [context.makeImage()]
        }

        return []
    }

    func decodeToImages(
        _ latents: [MLShapedArray<Float32>],
        configuration config: StableDiffusionPipeline.Configuration
    ) throws -> [CGImage?] {
        []
    }

    func unloadResources() {
        // No-op
    }

    var canSafetyCheck: Bool { false }
}

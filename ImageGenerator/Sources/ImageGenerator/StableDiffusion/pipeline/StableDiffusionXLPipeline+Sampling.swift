import CoreML
import Foundation

// MARK: - Sampling Operations

@available(iOS 17.0, macOS 14.0, *)
extension StableDiffusionXLPipeline {
    /// Creates schedulers for each image
    func createSchedulers(config: Configuration) -> [Scheduler] {
        (0..<config.imageCount).map { _ in
            switch config.schedulerType {
            case .pndmScheduler:
                return PNDMScheduler(stepCount: config.stepCount)
            case .dpmSolverMultistepScheduler:
                return DPMSolverMultistepScheduler(
                    stepCount: config.stepCount,
                    timeStepSpacing: config.schedulerTimestepSpacing
                )
            case .discreteFlowScheduler:
                return DiscreteFlowScheduler(
                    stepCount: config.stepCount,
                    timeStepShift: config.schedulerTimestepShift
                )
            }
        }
    }

    /// Generates initial latent samples
    func generateLatentSamples(
        configuration config: Configuration,
        scheduler: Scheduler
    ) throws -> [MLShapedArray<Float32>] {
        var sampleShape = try unet.latentSampleShape
        sampleShape[0] = 1

        let stdev = scheduler.initNoiseSigma
        var random = randomSource(from: config.rngType, seed: config.seed)
        let samples = (0..<config.imageCount).map { _ in
            MLShapedArray<Float32>(
                converting: random.normalShapedArray(sampleShape, mean: 0.0, stdev: Double(stdev)))
        }
        if let image = config.startingImage, config.mode == .imageToImage {
            guard let encoder else {
                throw ImageGeneratorError.startingImageProvidedWithoutEncoder
            }
            let latent = try encoder.encode(image, scaleFactor: config.encoderScaleFactor, random: &random)
            return scheduler.addNoise(originalSample: latent, noise: samples, strength: config.strength)
        }
        return samples
    }

    /// Decodes latent samples to images
    public func decodeToImages(
        _ latents: [MLShapedArray<Float32>],
        configuration config: Configuration
    ) throws -> [CGImage?] {
        defer {
            if reduceMemory {
                decoder.unloadResources()
            }
        }

        return try decoder.decode(latents, scaleFactor: config.decoderScaleFactor)
    }

    /// Cleans up resources after denoising
    func cleanupResources() {
        if reduceMemory {
            unet.unloadResources()
        }
        unetRefiner?.unloadResources()
    }
}

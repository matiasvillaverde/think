import CoreML
import CoreGraphics
import Foundation

// MARK: - Sampling Operations

@available(iOS 16.2, macOS 13.1, *)
extension StableDiffusionPipeline {
    /// Encodes the prompts and returns hidden states for the UNet
    func encodePrompts(config: Configuration) throws -> MLShapedArray<Float32> {
        var promptEmbedding = try textEncoder.encode(config.prompt)

        if config.guidanceScale >= 1.0 {
            // Concatenate negative and positive prompt embeddings
            let negativePromptEmbedding = try textEncoder.encode(config.negativePrompt)
            promptEmbedding = MLShapedArray<Float32>(
                concatenating: [negativePromptEmbedding, promptEmbedding],
                alongAxis: 0
            )
        }

        if reduceMemory {
            textEncoder.unloadResources()
        }

        return useMultilingualTextEncoder ? promptEmbedding : toHiddenStates(promptEmbedding)
    }

    /// Creates schedulers for each image to be generated
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

    /// Prepares initial latents and ControlNet conditions
    func prepareLatentsAndControlNet(
        config: Configuration,
        scheduler: Scheduler
    ) throws -> DenoisingState {
        // Generate random latent samples
        let latents = try generateLatentSamples(
            configuration: config,
            scheduler: scheduler
        )

        // Initialize denoised latents
        let denoisedLatents = latents.map { MLShapedArray<Float32>(converting: $0) }

        if reduceMemory {
            encoder?.unloadResources()
        }

        // Prepare ControlNet conditions
        let controlNetConds = try config.controlNetInputs.map { cgImage in
            let shapedArray = try cgImage.planarRGBShapedArray(minValue: 0.0, maxValue: 1.0)
            return MLShapedArray(
                concatenating: [shapedArray, shapedArray],
                alongAxis: 0
            )
        }

        return DenoisingState(
            latents: latents,
            denoisedLatents: denoisedLatents,
            controlNetConds: controlNetConds
        )
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

    /// Decodes latent samples to images with safety checking
    public func decodeToImages(
        _ latents: [MLShapedArray<Float32>],
        configuration config: Configuration
    ) throws -> [CGImage?] {
        let images = try decoder.decode(latents, scaleFactor: config.decoderScaleFactor)
        if reduceMemory {
            decoder.unloadResources()
        }

        // If safety is disabled return what was decoded
        if config.disableSafety {
            return images
        }

        // If there is no safety checker return what was decoded
        guard let safetyChecker else {
            return images
        }

        // Otherwise change images which are not safe to nil
        let safeImages = try images.map { image in
            try safetyChecker.isSafe(image) ? image : nil
        }

        if reduceMemory {
            safetyChecker.unloadResources()
        }

        return safeImages
    }
}

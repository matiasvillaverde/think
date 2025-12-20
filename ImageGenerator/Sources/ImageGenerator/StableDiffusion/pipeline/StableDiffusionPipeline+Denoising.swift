import CoreML
import Foundation

// MARK: - Denoising Types

/// Container for initial denoising state
@available(iOS 16.2, macOS 13.1, *)
struct DenoisingState {
    let latents: [MLShapedArray<Float32>]
    let denoisedLatents: [MLShapedArray<Float32>]
    let controlNetConds: [MLShapedArray<Float32>]
}

/// Parameters for a single denoising step
@available(iOS 16.2, macOS 13.1, *)
struct DenoisingStepParams {
    let config: PipelineConfiguration
    let scheduler: [Scheduler]
    let timeStep: Int
    let hiddenStates: MLShapedArray<Float32>
    let controlNetConds: [MLShapedArray<Float32>]
    let step: Int
    let stepCount: Int
}

/// Container for noise prediction parameters
@available(iOS 16.2, macOS 13.1, *)
struct NoisePredictionParams {
    let config: PipelineConfiguration
    let latentUnetInput: [MLShapedArray<Float32>]
    let latents: [MLShapedArray<Float32>]
    let timeStep: Int
    let hiddenStates: MLShapedArray<Float32>
    let additionalResiduals: [[String: MLShapedArray<Float32>]]?
}

/// Container for latent update parameters
@available(iOS 16.2, macOS 13.1, *)
struct SDLatentUpdateParams {
    let noise: [MLShapedArray<Float32>]
    let timeStep: Int
    let scheduler: [Scheduler]
    let config: PipelineConfiguration
}

/// Container for progress reporting parameters
@available(iOS 16.2, macOS 13.1, *)
struct ProgressReportParams {
    let latents: [MLShapedArray<Float32>]
    let denoisedLatents: [MLShapedArray<Float32>]
    let config: PipelineConfiguration
    let step: Int
    let stepCount: Int
}

// MARK: - Denoising Operations

@available(iOS 16.2, macOS 13.1, *)
extension StableDiffusionPipeline {
    /// Main denoising loop
    func performDenoisingLoop(
        config: Configuration,
        scheduler: [Scheduler],
        initialState: DenoisingState,
        hiddenStates: MLShapedArray<Float32>,
        progressHandler: @escaping (Progress) -> Bool
    ) throws -> [MLShapedArray<Float32>] {
        var latents = initialState.latents
        var denoisedLatents = initialState.denoisedLatents

        let timestepStrength: Float? = config.mode == .imageToImage ? config.strength : nil
        let timeSteps = scheduler[0].calculateTimesteps(strength: timestepStrength)

        for (step, t) in timeSteps.enumerated() {
            let stepParams = DenoisingStepParams(
                config: config,
                scheduler: scheduler,
                timeStep: t,
                hiddenStates: hiddenStates,
                controlNetConds: initialState.controlNetConds,
                step: step,
                stepCount: timeSteps.count
            )

            let shouldContinue = try performDenoisingStep(
                latents: &latents,
                denoisedLatents: &denoisedLatents,
                params: stepParams,
                progressHandler: progressHandler
            )

            if !shouldContinue {
                return [] // Cancelled
            }
        }

        return denoisedLatents
    }

    /// Performs a single denoising step
    private func performDenoisingStep(
        latents: inout [MLShapedArray<Float32>],
        denoisedLatents: inout [MLShapedArray<Float32>],
        params: DenoisingStepParams,
        progressHandler: @escaping (Progress) -> Bool
    ) throws -> Bool {
        let noise = try executeNoiseStep(latents: latents, params: params)
        updateLatentsWithNoise(
            latents: &latents,
            denoisedLatents: &denoisedLatents,
            noise: noise,
            params: params
        )
        return reportStepProgress(
            latents: latents,
            denoisedLatents: denoisedLatents,
            params: params,
            progressHandler: progressHandler
        )
    }

    /// Executes noise prediction step
    private func executeNoiseStep(
        latents: [MLShapedArray<Float32>],
        params: DenoisingStepParams
    ) throws -> [MLShapedArray<Float32>] {
        let latentUnetInput = prepareLatentInputs(latents: latents, config: params.config)

        let additionalResiduals = try controlNet?.execute(
            latents: latentUnetInput,
            timeStep: params.timeStep,
            hiddenStates: params.hiddenStates,
            images: params.controlNetConds
        )

        let noisePredParams = NoisePredictionParams(
            config: params.config,
            latentUnetInput: latentUnetInput,
            latents: latents,
            timeStep: params.timeStep,
            hiddenStates: params.hiddenStates,
            additionalResiduals: additionalResiduals
        )
        return try predictAndProcessNoise(params: noisePredParams)
    }

    /// Updates latents with noise
    private func updateLatentsWithNoise(
        latents: inout [MLShapedArray<Float32>],
        denoisedLatents: inout [MLShapedArray<Float32>],
        noise: [MLShapedArray<Float32>],
        params: DenoisingStepParams
    ) {
        let updateParams = SDLatentUpdateParams(
            noise: noise,
            timeStep: params.timeStep,
            scheduler: params.scheduler,
            config: params.config
        )
        updateLatentsWithParams(&latents, &denoisedLatents, updateParams)
    }

    /// Reports progress for the step
    private func reportStepProgress(
        latents: [MLShapedArray<Float32>],
        denoisedLatents: [MLShapedArray<Float32>],
        params: DenoisingStepParams,
        progressHandler: @escaping (Progress) -> Bool
    ) -> Bool {
        let progressParams = ProgressReportParams(
            latents: latents,
            denoisedLatents: denoisedLatents,
            config: params.config,
            step: params.step,
            stepCount: params.stepCount
        )
        return reportProgress(params: progressParams, progressHandler: progressHandler)
    }

    /// Predicts noise and applies guidance if needed
    private func predictAndProcessNoise(
        params: NoisePredictionParams
    ) throws -> [MLShapedArray<Float32>] {
        var noise = try predictNoiseWithParams(params)

        if params.config.guidanceScale >= 1.0 {
            noise = performGuidance(noise, params.config.guidanceScale)
        }

        return noise
    }

    /// Reports progress and returns whether to continue
    private func reportProgress(
        params: ProgressReportParams,
        progressHandler: @escaping (Progress) -> Bool
    ) -> Bool {
        let currentLatentSamples = params.config.useDenoisedIntermediates ? params.denoisedLatents : params.latents
        let progress = Progress(
            pipeline: self,
            prompt: params.config.prompt,
            step: params.step,
            stepCount: params.stepCount,
            currentLatentSamples: currentLatentSamples,
            configuration: params.config
        )
        return progressHandler(progress)
    }

    /// Prepares latent inputs for UNet based on guidance scale
    private func prepareLatentInputs(
        latents: [MLShapedArray<Float32>],
        config: Configuration
    ) -> [MLShapedArray<Float32>] {
        if config.guidanceScale >= 1.0 {
            // Duplicate latents for classifier-free guidance
            return latents.map {
                MLShapedArray<Float32>(concatenating: [$0, $0], alongAxis: 0)
            }
        } else {
            return latents
        }
    }

    /// Predicts noise using params structure
    private func predictNoiseWithParams(
        _ params: NoisePredictionParams
    ) throws -> [MLShapedArray<Float32>] {
        let latentSampleShape = try unet.latentSampleShape
        if latentSampleShape[0] >= 2 || params.config.guidanceScale < 1.0 {
            // Batched prediction
            return try unet.predictNoise(
                latents: params.latentUnetInput,
                timeStep: params.timeStep,
                hiddenStates: params.hiddenStates,
                additionalResiduals: params.additionalResiduals
            )
        } else {
            // Serial predictions for unconditioned and text-conditioned
            return try predictNoiseSerially(
                latents: params.latents,
                timeStep: params.timeStep,
                hiddenStates: params.hiddenStates,
                additionalResiduals: params.additionalResiduals
            )
        }
    }

    /// Performs serial noise predictions when batching is not available
    private func predictNoiseSerially(
        latents: [MLShapedArray<Float32>],
        timeStep: Int,
        hiddenStates: MLShapedArray<Float32>,
        additionalResiduals: [[String: MLShapedArray<Float32>]]?
    ) throws -> [MLShapedArray<Float32>] {
        // Unconditioned prediction
        var hidden0 = MLShapedArray<Float32>(converting: hiddenStates[0])
        hidden0 = MLShapedArray(scalars: hidden0.scalars, shape: [1] + hidden0.shape)
        let noisePredUncond = try unet.predictNoise(
            latents: latents,
            timeStep: timeStep,
            hiddenStates: hidden0,
            additionalResiduals: additionalResiduals
        )

        // Text-conditioned prediction
        var hidden1 = MLShapedArray<Float32>(converting: hiddenStates[1])
        hidden1 = MLShapedArray(scalars: hidden1.scalars, shape: [1] + hidden1.shape)
        let noisePredText = try unet.predictNoise(
            latents: latents,
            timeStep: timeStep,
            hiddenStates: hidden1,
            additionalResiduals: additionalResiduals
        )

        // Concatenate predictions
        let uncondPred: MLShapedArray<Float32> = noisePredUncond[0]
        let textPred: MLShapedArray<Float32> = noisePredText[0]
        return [MLShapedArray<Float32>(
            concatenating: [uncondPred, textPred],
            alongAxis: 0
        )]
    }

    /// Updates latents using params structure
    private func updateLatentsWithParams(
        _ latents: inout [MLShapedArray<Float32>],
        _ denoisedLatents: inout [MLShapedArray<Float32>],
        _ params: SDLatentUpdateParams
    ) {
        for i in 0..<params.config.imageCount {
            latents[i] = params.scheduler[i].step(
                output: params.noise[i],
                timeStep: params.timeStep,
                sample: latents[i]
            )

            denoisedLatents[i] = params.scheduler[i].modelOutputs.last ?? latents[i]
        }
    }
}

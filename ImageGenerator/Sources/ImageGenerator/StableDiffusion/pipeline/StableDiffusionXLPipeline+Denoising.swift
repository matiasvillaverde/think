import CoreML
import Foundation

// MARK: - Denoising Types

/// Container for denoising context
@available(iOS 17.0, macOS 14.0, *)
struct DenoisingContext {
    let baseInput: StableDiffusionXLPipeline.ModelInputs?
    let refinerInput: StableDiffusionXLPipeline.ModelInputs?
    let scheduler: [Scheduler]
    let timestepStrength: Float?
    let refinerStartRatio: Float
}

/// Parameters for denoising loop execution
@available(iOS 17.0, macOS 14.0, *)
struct DenoisingLoopParams {
    let context: DenoisingContext
    let config: PipelineConfiguration
    let timeSteps: [Int]
    let refinerStartStep: Int
    let progressHandler: (PipelineProgress) -> Bool
}

/// Parameters for a single denoising step
@available(iOS 17.0, macOS 14.0, *)
struct SingleStepParams {
    let step: Int
    let timeStep: Int
    let stepCount: Int
    let unetModel: Unet
    let currentInput: StableDiffusionXLPipeline.ModelInputs?
    let context: DenoisingContext
    let config: PipelineConfiguration
    let progressHandler: (PipelineProgress) -> Bool
}

/// Container for latent update parameters
@available(iOS 17.0, macOS 14.0, *)
struct XLLatentUpdateParams {
    let noise: [MLShapedArray<Float32>]
    let scheduler: [Scheduler]
    let timeStep: Int
    let imageCount: Int
}

// MARK: - Denoising Operations

@available(iOS 17.0, macOS 14.0, *)
extension StableDiffusionXLPipeline {
    /// Performs the main denoising loop
    func performDenoising(
        latents: inout [MLShapedArray<Float32>],
        denoisedLatents: inout [MLShapedArray<Float32>],
        context: DenoisingContext,
        config: Configuration,
        progressHandler: @escaping (Progress) -> Bool
    ) throws -> Bool {
        let (timeSteps, refinerStartStep) = prepareLoopParams(context: context)
        let loopParams = DenoisingLoopParams(
            context: context,
            config: config,
            timeSteps: timeSteps,
            refinerStartStep: refinerStartStep,
            progressHandler: progressHandler
        )
        return try executeDenoisingLoop(
            latents: &latents,
            denoisedLatents: &denoisedLatents,
            params: loopParams
        )
    }

    /// Prepares parameters for denoising loop
    private func prepareLoopParams(context: DenoisingContext) -> (timeSteps: [Int], refinerStartStep: Int) {
        let timeSteps = context.scheduler[0].calculateTimesteps(strength: context.timestepStrength)
        let refinerStartStep = Int(Float(timeSteps.count) * context.refinerStartRatio)
        return (timeSteps, refinerStartStep)
    }

    /// Executes the main denoising loop
    private func executeDenoisingLoop(
        latents: inout [MLShapedArray<Float32>],
        denoisedLatents: inout [MLShapedArray<Float32>],
        params: DenoisingLoopParams
    ) throws -> Bool {
        var unetModel = unet
        var currentInput = params.context.baseInput ?? params.context.refinerInput

        for (step, t) in params.timeSteps.enumerated() {
            if let refiner = unetRefiner, step == params.refinerStartStep {
                (unetModel, currentInput) = switchToRefiner(refiner, params.context.refinerInput)
            }

            let stepParams = SingleStepParams(
                step: step,
                timeStep: t,
                stepCount: params.timeSteps.count,
                unetModel: unetModel,
                currentInput: currentInput,
                context: params.context,
                config: params.config,
                progressHandler: params.progressHandler
            )
            let shouldContinue = try processSingleStep(
                latents: &latents,
                denoisedLatents: &denoisedLatents,
                params: stepParams
            )
            if !shouldContinue { return false }
        }
        return true
    }

    /// Processes a single denoising step
    private func processSingleStep(
        latents: inout [MLShapedArray<Float32>],
        denoisedLatents: inout [MLShapedArray<Float32>],
        params: SingleStepParams
    ) throws -> Bool {
        let noise = try denoisingStep(
            latents: latents,
            timeStep: params.timeStep,
            unetModel: params.unetModel,
            currentInput: params.currentInput,
            config: params.config
        )

        updateLatents(
            latents: &latents,
            denoisedLatents: &denoisedLatents,
            params: XLLatentUpdateParams(
                noise: noise,
                scheduler: params.context.scheduler,
                timeStep: params.timeStep,
                imageCount: params.config.imageCount
            )
        )

        let progress = createProgress(
            step: params.step,
            stepCount: params.stepCount,
            latents: latents,
            denoisedLatents: denoisedLatents,
            config: params.config
        )
        return params.progressHandler(progress)
    }

    /// Switches from base model to refiner
    private func switchToRefiner(_ refiner: Unet, _ refinerInput: ModelInputs?) -> (Unet, ModelInputs?) {
        unet.unloadResources()
        return (refiner, refinerInput)
    }

    /// Performs a single denoising step
    private func denoisingStep(
        latents: [MLShapedArray<Float32>],
        timeStep: Int,
        unetModel: Unet,
        currentInput: ModelInputs?,
        config: Configuration
    ) throws -> [MLShapedArray<Float32>] {
        let latentUnetInput = latents.map {
            MLShapedArray<Float32>(concatenating: [$0, $0], alongAxis: 0)
        }

        guard let hiddenStates = currentInput?.hiddenStates,
              let pooledStates = currentInput?.pooledStates,
              let geometryConditioning = currentInput?.geometryConditioning else {
            throw ImageGeneratorError.missingUnetInputs
        }

        let noise = try unetModel.predictNoise(
            latents: latentUnetInput,
            timeStep: timeStep,
            hiddenStates: hiddenStates,
            pooledStates: pooledStates,
            geometryConditioning: geometryConditioning
        )

        return performGuidance(noise, config.guidanceScale)
    }

    /// Updates latents after noise prediction
    private func updateLatents(
        latents: inout [MLShapedArray<Float32>],
        denoisedLatents: inout [MLShapedArray<Float32>],
        params: XLLatentUpdateParams
    ) {
        for i in 0..<params.imageCount {
            latents[i] = params.scheduler[i].step(
                output: params.noise[i],
                timeStep: params.timeStep,
                sample: latents[i]
            )
            denoisedLatents[i] = params.scheduler[i].modelOutputs.last ?? latents[i]
        }
    }

    /// Creates progress object for current step
    private func createProgress(
        step: Int,
        stepCount: Int,
        latents: [MLShapedArray<Float32>],
        denoisedLatents: [MLShapedArray<Float32>],
        config: Configuration
    ) -> Progress {
        let currentLatentSamples = config.useDenoisedIntermediates ? denoisedLatents : latents
        return Progress(
            pipeline: self,
            prompt: config.prompt,
            step: step,
            stepCount: stepCount,
            currentLatentSamples: currentLatentSamples,
            configuration: config
        )
    }
}

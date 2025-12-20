import Accelerate
import CoreGraphics
import CoreML
import Foundation
import NaturalLanguage

/// Schedulers compatible with StableDiffusionPipeline
public enum StableDiffusionScheduler {
    /// Scheduler that uses a pseudo-linear multi-step (PLMS) method
    case pndmScheduler
    /// Scheduler that uses a second order DPM-Solver++ algorithm
    case dpmSolverMultistepScheduler
    /// Scheduler for rectified flow based multimodal diffusion transformer models
    case discreteFlowScheduler
}

/// RNG compatible with StableDiffusionPipeline
public enum StableDiffusionRNG {
    /// RNG that matches numpy implementation
    case numpyRNG
    /// RNG that matches PyTorch CPU implementation.
    case torchRNG
    /// RNG that matches PyTorch CUDA implementation.
    case nvidiaRNG
}

@available(*, deprecated, message: "Use ImageGeneratorError instead")
public typealias PipelineError = ImageGeneratorError

@available(iOS 16.2, macOS 13.1, *)
public protocol StableDiffusionPipelineProtocol: ResourceManaging {
    var canSafetyCheck: Bool { get }

    func generateImages(
        configuration config: PipelineConfiguration,
        progressHandler: @escaping (PipelineProgress) -> Bool
    ) throws -> [CGImage?]

    func decodeToImages(
        _ latents: [MLShapedArray<Float32>],
        configuration config: PipelineConfiguration
    ) throws -> [CGImage?]
}

@available(iOS 16.2, macOS 13.1, *)
public extension StableDiffusionPipelineProtocol {
    var canSafetyCheck: Bool { false }
}

/// A pipeline used to generate image samples from text input using stable diffusion
///
/// This implementation matches:
/// [Hugging Face Diffusers Pipeline](
/// https://github.com/huggingface/diffusers/blob/main/src/diffusers/pipelines/
/// stable_diffusion/pipeline_stable_diffusion.py)
@available(iOS 16.2, macOS 13.1, *)
public struct StableDiffusionPipeline: StableDiffusionPipelineProtocol {
    /// Model to generate embeddings for tokenized input text
    var textEncoder: TextEncoderModel

    /// Model used to predict noise residuals given an input, diffusion time step, and conditional embedding
    var unet: Unet

    /// Model used to generate final image from latent diffusion process
    var decoder: Decoder

    /// Model used to latent space for image2image, and soon, in-painting
    var encoder: Encoder?

    /// Optional model for checking safety of generated image
    var safetyChecker: SafetyChecker?

    /// Optional model used before Unet to control generated images by additonal inputs
    var controlNet: ControlNet?

    /// Reports whether this pipeline can perform safety checks
    public var canSafetyCheck: Bool {
        safetyChecker != nil
    }

    /// Option to reduce memory during image generation
    ///
    /// If true, the pipeline will lazily load TextEncoder, Unet, Decoder, and SafetyChecker
    /// when needed and aggressively unload their resources after
    ///
    /// This will increase latency in favor of reducing memory
    var reduceMemory: Bool = false

    /// Option to use system multilingual NLContextualEmbedding as encoder
    var useMultilingualTextEncoder: Bool = false

    /// Optional natural language script to use for the text encoder.
    var script: Script?

    /// Creates a pipeline using the specified models and tokenizer
    ///
    /// - Parameters:
    ///   - textEncoder: Model for encoding tokenized text
    ///   - unet: Model for noise prediction on latent samples
    ///   - decoder: Model for decoding latent sample to image
    ///   - controlNet: Optional model to control generated images by additonal inputs
    ///   - safetyChecker: Optional model for checking safety of generated images
    ///   - reduceMemory: Option to enable reduced memory mode
    /// - Returns: Pipeline ready for image generation
    public init(
        textEncoder: TextEncoderModel,
        unet: Unet,
        decoder: Decoder,
        encoder: Encoder?,
        controlNet: ControlNet? = nil,
        safetyChecker: SafetyChecker? = nil,
        reduceMemory: Bool = false
    ) {
        self.textEncoder = textEncoder
        self.unet = unet
        self.decoder = decoder
        self.encoder = encoder
        self.controlNet = controlNet
        self.safetyChecker = safetyChecker
        self.reduceMemory = reduceMemory
    }

    /// Creates a pipeline using the specified models and tokenizer
    ///
    /// - Parameters:
    ///   - textEncoder: Model for encoding tokenized text
    ///   - unet: Model for noise prediction on latent samples
    ///   - decoder: Model for decoding latent sample to image
    ///   - controlNet: Optional model to control generated images by additonal inputs
    ///   - safetyChecker: Optional model for checking safety of generated images
    ///   - reduceMemory: Option to enable reduced memory mode
    ///   - useMultilingualTextEncoder: Option to use system multilingual NLContextualEmbedding as encoder
    ///   - script: Optional natural language script to use for the text encoder.
    /// - Returns: Pipeline ready for image generation
    @available(iOS 17.0, macOS 14.0, *)
    public init(
        textEncoder: TextEncoderModel,
        unet: Unet,
        decoder: Decoder,
        encoder: Encoder?,
        controlNet: ControlNet? = nil,
        safetyChecker: SafetyChecker? = nil,
        reduceMemory: Bool = false,
        useMultilingualTextEncoder: Bool = false,
        script: Script? = nil
    ) {
        self.textEncoder = textEncoder
        self.unet = unet
        self.decoder = decoder
        self.encoder = encoder
        self.controlNet = controlNet
        self.safetyChecker = safetyChecker
        self.reduceMemory = reduceMemory
        self.useMultilingualTextEncoder = useMultilingualTextEncoder
        self.script = script
    }

    /// Load required resources for this pipeline
    ///
    /// If reducedMemory is true this will instead call prewarmResources instead
    /// and let the pipeline lazily load resources as needed
    public func loadResources() throws {
        if reduceMemory {
            try prewarmResources()
        } else {
            try unet.loadResources()
            try textEncoder.loadResources()
            try decoder.loadResources()
            try encoder?.loadResources()
            try controlNet?.loadResources()
            try safetyChecker?.loadResources()
        }
    }

    /// Unload the underlying resources to free up memory
    public func unloadResources() {
        textEncoder.unloadResources()
        unet.unloadResources()
        decoder.unloadResources()
        encoder?.unloadResources()
        controlNet?.unloadResources()
        safetyChecker?.unloadResources()
    }

    // Prewarm resources one at a time
    public func prewarmResources() throws {
        try textEncoder.prewarmResources()
        try unet.prewarmResources()
        try decoder.prewarmResources()
        try encoder?.prewarmResources()
        try controlNet?.prewarmResources()
        try safetyChecker?.prewarmResources()
    }

    /// Image generation using stable diffusion
    /// - Parameters:
    ///   - configuration: Image generation configuration
    ///   - progressHandler: Callback to perform after each step, stops on receiving false response
    /// - Returns: An array of `imageCount` optional images.
    ///            The images will be nil if safety checks were performed and found the result to be un-safe
    public func generateImages(
        configuration config: Configuration,
        progressHandler: @escaping (Progress) -> Bool = { _ in true }
    ) throws -> [CGImage?] {
        // Encode prompts and prepare hidden states
        let hiddenStates = try encodePrompts(config: config)

        // Setup schedulers
        let scheduler = createSchedulers(config: config)

        // Generate initial latents and prepare for denoising
        let initialState = try prepareLatentsAndControlNet(
            config: config,
            scheduler: scheduler[0]
        )

        // Perform denoising iterations
        let finalDenoisedLatents = try performDenoisingLoop(
            config: config,
            scheduler: scheduler,
            initialState: initialState,
            hiddenStates: hiddenStates,
            progressHandler: progressHandler
        )

        // Return empty array if denoising was cancelled
        guard !finalDenoisedLatents.isEmpty else { return [] }

        // Clean up resources if needed
        if reduceMemory {
            controlNet?.unloadResources()
            unet.unloadResources()
        }

        // Decode the latent samples to images
        return try decodeToImages(finalDenoisedLatents, configuration: config)
    }

}

/// Sampling progress details
@available(iOS 16.2, macOS 13.1, *)
public struct PipelineProgress {
    public let pipeline: StableDiffusionPipelineProtocol
    public let prompt: String
    public let step: Int
    public let stepCount: Int
    public let currentLatentSamples: [MLShapedArray<Float32>]
    public let configuration: PipelineConfiguration
    public var isSafetyEnabled: Bool {
        pipeline.canSafetyCheck && !configuration.disableSafety
    }
    public var currentImages: [CGImage?] {
        do {
            return try pipeline.decodeToImages(currentLatentSamples, configuration: configuration)
        } catch {
            // Failed to decode current images - return empty array to maintain API contract
            return []
        }
    }
}

@available(iOS 16.2, macOS 13.1, *)
public extension StableDiffusionPipeline {
    /// Sampling progress details
    typealias Progress = PipelineProgress
}

import Accelerate
import CoreGraphics
import CoreML
import Foundation
import NaturalLanguage

/// A pipeline used to generate image samples from text input using stable diffusion XL
///
/// This implementation matches:
/// [Hugging Face Diffusers XL Pipeline](
/// https://github.com/huggingface/diffusers/blob/main/src/diffusers/pipelines/
/// stable_diffusion_xl/pipeline_stable_diffusion_xl.py)
@available(iOS 17.0, macOS 14.0, *)
public struct StableDiffusionXLPipeline: StableDiffusionPipelineProtocol {
    public typealias Configuration = PipelineConfiguration
    public typealias Progress = PipelineProgress

    /// Model to generate embeddings for tokenized input text
    var textEncoder: TextEncoderXLModel?
    var textEncoder2: TextEncoderXLModel

    /// Model used to predict noise residuals given an input, diffusion time step, and conditional embedding
    var unet: Unet

    /// Model used to refine the image, if present
    var unetRefiner: Unet?

    /// Model used to generate final image from latent diffusion process
    var decoder: Decoder

    /// Model used to latent space for image2image, and soon, in-painting
    var encoder: Encoder?

    /// Option to reduce memory during image generation
    ///
    /// If true, the pipeline will lazily load TextEncoder, Unet, Decoder, and SafetyChecker
    /// when needed and aggressively unload their resources after
    ///
    /// This will increase latency in favor of reducing memory
    var reduceMemory: Bool = false

    /// Creates a pipeline using the specified models and tokenizer
    ///
    /// - Parameters:
    ///   - textEncoder: Model for encoding tokenized text
    ///   - textEncoder2: Second text encoding model
    ///   - unet: Model for noise prediction on latent samples
    ///   - decoder: Model for decoding latent sample to image
    ///   - reduceMemory: Option to enable reduced memory mode
    /// - Returns: Pipeline ready for image generation
    public init(
        textEncoder: TextEncoderXLModel?,
        textEncoder2: TextEncoderXLModel,
        unet: Unet,
        unetRefiner: Unet?,
        decoder: Decoder,
        encoder: Encoder?,
        reduceMemory: Bool = false
    ) {
        self.textEncoder = textEncoder
        self.textEncoder2 = textEncoder2
        self.unet = unet
        self.unetRefiner = unetRefiner
        self.decoder = decoder
        self.encoder = encoder
        self.reduceMemory = reduceMemory
    }

    /// Load required resources for this pipeline
    ///
    /// If reducedMemory is true this will instead call prewarmResources instead
    /// and let the pipeline lazily load resources as needed
    public func loadResources() throws {
        if reduceMemory {
            try prewarmResources()
        } else {
            try textEncoder2.loadResources()
            try unet.loadResources()
            try decoder.loadResources()

            do {
                try textEncoder?.loadResources()
            } catch {
                // Failed to load text encoder resources - will be handled at generation time
            }

            // Only prewarm refiner unet on load so it's unloaded until needed
            do {
                try unetRefiner?.prewarmResources()
            } catch {
                // Failed to prewarm refiner unet - will be handled at generation time
            }

            do {
                try encoder?.loadResources()
            } catch {
                // Failed to load VAE encoder resources - will be handled at generation time
            }
        }
    }

    /// Unload the underlying resources to free up memory
    public func unloadResources() {
        textEncoder?.unloadResources()
        textEncoder2.unloadResources()
        unet.unloadResources()
        unetRefiner?.unloadResources()
        decoder.unloadResources()
        encoder?.unloadResources()
    }

    /// Prewarm resources one at a time
    public func prewarmResources() throws {
        try textEncoder2.prewarmResources()
        try unet.prewarmResources()
        try decoder.prewarmResources()

        do {
            try textEncoder?.prewarmResources()
        } catch {
            // Failed to prewarm text encoder - will retry at generation time
        }

        do {
            try unetRefiner?.prewarmResources()
        } catch {
            // Failed to prewarm refiner unet - will retry at generation time
        }

        do {
            try encoder?.prewarmResources()
        } catch {
            // Failed to prewarm VAE encoder - will retry at generation time
        }
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
        let (baseInput, refinerInput) = try setupConditioning(config: config)
        let scheduler = createSchedulers(config: config)
        var latents = try generateLatentSamples(configuration: config, scheduler: scheduler[0])
        var denoisedLatents = latents.map { MLShapedArray<Float32>(converting: $0) }

        if reduceMemory {
            encoder?.unloadResources()
        }

        let denoisingContext = DenoisingContext(
            baseInput: baseInput,
            refinerInput: refinerInput,
            scheduler: scheduler,
            timestepStrength: config.mode == .imageToImage ? config.strength : nil,
            refinerStartRatio: config.refinerStart
        )

        let result = try performDenoising(
            latents: &latents,
            denoisedLatents: &denoisedLatents,
            context: denoisingContext,
            config: config,
            progressHandler: progressHandler
        )

        if !result { return [] }

        cleanupResources()
        return try decodeToImages(denoisedLatents, configuration: config)
    }

}

import Foundation

/// Timing metrics specific to image generation pipeline.
///
/// Captures detailed timing information for each stage of the Stable Diffusion
/// generation process, enabling performance analysis and optimization.
public struct ImageTimingMetrics: Sendable, Codable {
    /// Total time for the entire generation process.
    public let totalTime: Duration

    /// Time taken to load the model into memory.
    public let modelLoadTime: Duration?

    /// Time to encode the text prompt into embeddings.
    public let promptEncodingTime: Duration?

    /// Individual timing for each denoising step.
    public let denoisingStepTimes: [Duration]

    /// Time to decode the latent representation into an image.
    public let vaeDecodingTime: Duration?

    /// Time for any post-processing operations.
    public let postProcessingTime: Duration?

    /// Creates new timing metrics for image generation.
    ///
    /// - Parameters:
    ///   - totalTime: Total generation time (required)
    ///   - modelLoadTime: Optional model loading duration
    ///   - promptEncodingTime: Optional prompt encoding duration
    ///   - denoisingStepTimes: Per-step denoising timings (defaults to empty)
    ///   - vaeDecodingTime: Optional VAE decoding duration
    ///   - postProcessingTime: Optional post-processing duration
    public init(
        totalTime: Duration,
        modelLoadTime: Duration? = nil,
        promptEncodingTime: Duration? = nil,
        denoisingStepTimes: [Duration] = [],
        vaeDecodingTime: Duration? = nil,
        postProcessingTime: Duration? = nil
    ) {
        self.totalTime = totalTime
        self.modelLoadTime = modelLoadTime
        self.promptEncodingTime = promptEncodingTime
        self.denoisingStepTimes = denoisingStepTimes
        self.vaeDecodingTime = vaeDecodingTime
        self.postProcessingTime = postProcessingTime
    }
}

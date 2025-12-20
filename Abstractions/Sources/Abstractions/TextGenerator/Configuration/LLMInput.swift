import Foundation
import CoreGraphics

/// Complete configuration for an LLM generation request.
///
/// This structure encapsulates all parameters needed to generate text from an LLM.
/// It follows a "data over behavior" principle - all configuration is explicit
/// and immutable, making requests reproducible and debuggable.
///
/// The configuration is designed to be a superset of common LLM parameters while
/// remaining provider-agnostic. Provider-specific features can be passed through
/// the `extensions` dictionary.
public struct LLMInput: Sendable {
    /// The complete input text for generation.
    ///
    /// This can be a simple prompt, a formatted conversation with special tokens,
    /// a document with instructions, or any other text input the model accepts.
    /// The format is entirely up to the consumer - the provider simply passes
    /// this text to the underlying model.
    ///
    /// For chat models, consumers typically format messages into this prompt
    /// using the model's expected template (e.g., "<user>...</user>").
    /// For tool use, consumers include tool definitions in the prompt.
    public let context: String

    public let images: [CGImage]

    public let videoURLs: [URL]

    /// Parameters controlling the randomness and creativity of generation.
    public let sampling: SamplingParameters

    /// Hard limits on resource consumption.
    public let limits: ResourceLimits

    public init(
        context: String,
        images: [CGImage] = [],
        videoURLs: [URL] = [],
        sampling: SamplingParameters = .default,
        limits: ResourceLimits = .default
    ) {
        self.context = context
        self.images = images
        self.videoURLs = videoURLs
        self.sampling = sampling
        self.limits = limits
    }
}

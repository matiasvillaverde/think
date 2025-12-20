import Foundation

/// Resource usage metrics for image generation.
///
/// Tracks memory consumption and computational resources used during
/// the Stable Diffusion generation process.
public struct ImageUsageMetrics: Sendable, Codable {
    /// Number of tokens in the text prompt.
    public let promptTokens: Int?

    /// Number of tokens in the negative prompt (if used).
    public let negativePromptTokens: Int?

    /// Active memory usage in bytes during generation.
    public let activeMemory: UInt64

    /// Peak memory usage in bytes during generation.
    public let peakMemory: UInt64

    /// Total number of model parameters.
    public let modelParameters: Int

    /// GPU memory usage in bytes (if available).
    public let gpuMemory: UInt64?

    /// Whether the generation used GPU acceleration.
    public let usedGPU: Bool

    /// Creates new usage metrics for image generation.
    ///
    /// - Parameters:
    ///   - promptTokens: Optional token count for main prompt
    ///   - negativePromptTokens: Optional token count for negative prompt
    ///   - activeMemory: Active memory usage in bytes (required)
    ///   - peakMemory: Peak memory usage in bytes (required)
    ///   - modelParameters: Total model parameter count (required)
    ///   - gpuMemory: Optional GPU memory usage
    ///   - usedGPU: Whether GPU acceleration was used (defaults to false)
    public init(
        activeMemory: UInt64,
        peakMemory: UInt64,
        modelParameters: Int,
        promptTokens: Int? = nil,
        negativePromptTokens: Int? = nil,
        gpuMemory: UInt64? = nil,
        usedGPU: Bool = false
    ) {
        self.promptTokens = promptTokens
        self.negativePromptTokens = negativePromptTokens
        self.activeMemory = activeMemory
        self.peakMemory = peakMemory
        self.modelParameters = modelParameters
        self.gpuMemory = gpuMemory
        self.usedGPU = usedGPU
    }
}

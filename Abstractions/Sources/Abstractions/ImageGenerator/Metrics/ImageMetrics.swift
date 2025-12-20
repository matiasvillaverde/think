/// Performance and usage metrics for image generation.
///
/// ImageMetrics provides comprehensive visibility into the image generation process,
/// following the same pattern as ChunkMetrics for consistency across the codebase.
/// This enables:
/// - Performance monitoring of Stable Diffusion pipelines
/// - Memory usage tracking for Core ML models
/// - Quality assurance through generation parameters tracking
/// - Capacity planning based on model requirements
public struct ImageMetrics: Sendable, Codable {
    /// Timing information for generation pipeline analysis.
    public let timing: ImageTimingMetrics?

    /// Resource usage for memory and capacity tracking.
    public let usage: ImageUsageMetrics?

    /// Detailed generation parameters and quality metrics.
    public let generation: ImageGenerationMetrics?

    /// Creates new image metrics with comprehensive information.
    ///
    /// All parameters are optional, allowing image generators to report only
    /// the metrics they have available. This maintains backward compatibility
    /// while enabling richer metrics for advanced pipelines.
    ///
    /// - Parameters:
    ///   - timing: Optional timing metrics for latency analysis
    ///   - usage: Optional usage metrics for resource tracking
    ///   - generation: Optional generation metrics for quality analysis
    public init(
        timing: ImageTimingMetrics? = nil,
        usage: ImageUsageMetrics? = nil,
        generation: ImageGenerationMetrics? = nil
    ) {
        self.timing = timing
        self.usage = usage
        self.generation = generation
    }
}

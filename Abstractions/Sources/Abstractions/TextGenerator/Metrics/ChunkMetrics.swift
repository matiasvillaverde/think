/// Performance and usage metrics for a stream chunk.
///
/// Metrics provide visibility into the generation process, enabling:
/// - Performance monitoring and optimization
/// - Cost tracking and budgeting  
/// - Quality assurance and debugging
/// - Capacity planning
public struct ChunkMetrics: Sendable, Codable {
    /// Timing information for latency analysis.
    public let timing: TimingMetrics?

    /// Token usage for cost tracking.
    public let usage: UsageMetrics?

    /// Detailed generation quality and performance metrics.
    public let generation: GenerationMetrics?

    /// Creates new chunk metrics with comprehensive information.
    ///
    /// All parameters are optional, allowing providers to report only
    /// the metrics they have available. This maintains backward compatibility
    /// while enabling richer metrics for providers that support them.
    ///
    /// - Parameters:
    ///   - timing: Optional timing metrics for latency analysis
    ///   - usage: Optional usage metrics for cost tracking
    ///   - generation: Optional generation metrics for quality analysis
    public init(
        timing: TimingMetrics? = nil,
        usage: UsageMetrics? = nil,
        generation: GenerationMetrics? = nil
    ) {
        self.timing = timing
        self.usage = usage
        self.generation = generation
    }
}

import Foundation

/// Hard limits on resource consumption for a generation request.
///
/// These limits help prevent runaway costs and ensure predictable behavior.
/// Providers should respect these limits and stop generation when reached.
public struct ResourceLimits: Sendable {
    /// Maximum number of tokens to generate.
    ///
    /// This is a hard limit - generation stops when this many tokens are produced,
    /// even if the model hasn't reached a natural stopping point. This includes
    /// both visible text tokens and special tokens.
    public let maxTokens: Int

    /// Maximum time allowed for the complete generation.
    ///
    /// If set, the provider should cancel generation if this timeout is exceeded.
    /// This helps prevent hanging requests and ensures responsive applications.
    /// Note that this includes queue time for remote APIs.
    public let maxTime: Duration?

    /// Whether to collect detailed per-token metrics during generation.
    ///
    /// When true, the provider collects timing information for each token generated,
    /// enabling detailed performance analysis and percentile calculations.
    /// Setting this to false reduces memory usage and overhead during generation,
    /// which can be important for long-running generations or performance-critical paths.
    public let collectDetailedMetrics: Bool

    /// Default resource limits providing reasonable defaults.
    public static let `default` = ResourceLimits(
        maxTokens: 2048,
        maxTime: nil,
        collectDetailedMetrics: false
    )

    /// Creates resource limits for controlling generation bounds.
    ///
    /// - Parameters:
    ///   - maxTokens: Maximum number of tokens to generate (hard limit)
    ///   - maxTime: Maximum time allowed for complete generation (nil for unlimited)
    ///   - collectDetailedMetrics: Whether to collect per-token timing metrics (default: false)
    public init(
        maxTokens: Int,
        maxTime: Duration? = nil,
        collectDetailedMetrics: Bool = false
    ) {
        self.maxTokens = maxTokens
        self.maxTime = maxTime
        self.collectDetailedMetrics = collectDetailedMetrics
    }
}

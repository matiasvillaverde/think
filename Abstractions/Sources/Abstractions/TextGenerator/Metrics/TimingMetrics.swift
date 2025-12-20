import Foundation

/// Detailed timing information for performance analysis.
///
/// These metrics help identify bottlenecks and optimize the user experience.
/// All times are in seconds from the start of the request.
public struct TimingMetrics: Sendable, Codable {
    /// Time from request start to first token generation.
    ///
    /// This is often the most important metric for user experience in
    /// interactive applications. High TTFT usually indicates:
    /// - Long queue times (server overload)
    /// - Slow prompt processing (long prompts)
    /// - Model loading overhead (cold starts)
    public let timeToFirstToken: Duration?

    /// Time since the previous chunk was received.
    ///
    /// Helps identify streaming irregularities. Consistent inter-token
    /// times indicate smooth generation, while high variance suggests
    /// processing bottlenecks or network issues.
    public let timeSinceLastToken: Duration?

    /// Total elapsed time since request started.
    ///
    /// Useful for monitoring overall request duration and enforcing timeouts.
    public let totalTime: Duration

    /// Raw timing data for each generated token.
    ///
    /// Stores individual token generation durations for detailed analysis.
    /// This allows calculation of percentiles, variance, and other statistics
    /// on-demand without pre-computing them.
    public let tokenTimings: [Duration]

    /// Time spent processing the initial prompt.
    ///
    /// This is the time from request start to when prompt processing is complete,
    /// before token generation begins. High values indicate long prompts or
    /// slow prompt processing.
    public let promptProcessingTime: Duration?

    /// Creates new timing metrics for performance analysis.
    ///
    /// The only required parameter is `totalTime`, as this is always
    /// available. The other metrics are optional and depend on what
    /// the provider can measure.
    ///
    /// - Parameters:
    ///   - totalTime: Total elapsed time since request started (required)
    ///   - timeToFirstToken: Optional time from request start to first token
    ///   - timeSinceLastToken: Optional time since the previous chunk
    ///   - tokenTimings: Optional array of individual token generation durations
    ///   - promptProcessingTime: Optional time spent processing the prompt
    public init(
        totalTime: Duration,
        timeToFirstToken: Duration? = nil,
        timeSinceLastToken: Duration? = nil,
        tokenTimings: [Duration] = [],
        promptProcessingTime: Duration? = nil
    ) {
        self.timeToFirstToken = timeToFirstToken
        self.timeSinceLastToken = timeSinceLastToken
        self.totalTime = totalTime
        self.tokenTimings = tokenTimings
        self.promptProcessingTime = promptProcessingTime
    }
}

// MARK: - Computed Properties

extension TimingMetrics {
    /// Tokens generated per second throughout the entire generation.
    ///
    /// Calculated from token timings if available.
    /// Returns nil if no tokens were generated or timing data is unavailable.
    public var tokensPerSecond: Double? {
        // Need token count to calculate TPS
        guard !tokenTimings.isEmpty else {
            return nil
        }
        let totalSeconds = Double(totalTime.components.seconds) + Double(totalTime.components.attoseconds) / 1e18
        return totalSeconds > 0 ? Double(tokenTimings.count) / totalSeconds : nil
    }

    /// Calculate tokens per second given an external token count.
    ///
    /// Use this when tokenTimings isn't collected but you know the token count.
    public func tokensPerSecond(tokenCount: Int) -> Double? {
        guard tokenCount > 0 else {
            return nil
        }
        let totalSeconds = Double(totalTime.components.seconds) + Double(totalTime.components.attoseconds) / 1e18
        return totalSeconds > 0 ? Double(tokenCount) / totalSeconds : nil
    }

    /// Average time taken to generate each token.
    ///
    /// Calculated from the raw token timings data.
    public var averageTimePerToken: Duration? {
        guard !tokenTimings.isEmpty else {
            return nil
        }

        let totalAttoseconds = tokenTimings.reduce(Int64(0)) { sum, duration in
            let seconds = Int64(duration.components.seconds) * 1_000_000_000_000_000_000
            return sum + seconds + duration.components.attoseconds
        }

        let averageAttoseconds = totalAttoseconds / Int64(tokenTimings.count)
        return Duration(
            secondsComponent: averageAttoseconds / 1_000_000_000_000_000_000,
            attosecondsComponent: averageAttoseconds % 1_000_000_000_000_000_000
        )
    }

    /// Calculate percentile values from token timings.
    ///
    /// - Parameter percentile: The percentile to calculate (0.0 to 1.0)
    /// - Returns: The duration at the specified percentile, or nil if no timings available
    public func percentile(_ percentile: Double) -> Duration? {
        guard !tokenTimings.isEmpty else {
            return nil
        }
        guard percentile >= 0.0, percentile <= 1.0 else {
            return nil
        }

        let sorted = tokenTimings.sorted()
        let index = Int(Double(sorted.count - 1) * percentile)
        return sorted[index]
    }

    /// Median token generation time (50th percentile).
    public var medianTimePerToken: Duration? {
        percentile(0.5)
    }

    /// 95th percentile token generation time.
    ///
    /// Useful for understanding tail latency.
    public var p95TimePerToken: Duration? {
        percentile(0.95)
    }

    /// 99th percentile token generation time.
    ///
    /// Useful for identifying worst-case performance.
    public var p99TimePerToken: Duration? {
        percentile(0.99)
    }
}

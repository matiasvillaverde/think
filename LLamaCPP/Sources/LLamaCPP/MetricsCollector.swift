import Abstractions
import Foundation

/// High-performance metrics collector with minimal overhead.
///
/// This collector is designed for zero-allocation during hot paths and
/// efficient data collection during LLM generation.
internal struct MetricsCollector {
    // MARK: - Properties

    /// Monotonic clock for accurate timing
    private let clock: ContinuousClock = ContinuousClock()

    /// Generation start time
    private let startInstant: ContinuousClock.Instant

    /// Prompt processing start time
    private var promptStartInstant: ContinuousClock.Instant?

    /// Prompt processing end time
    private var promptEndInstant: ContinuousClock.Instant?

    /// First token generation time
    private var firstTokenInstant: ContinuousClock.Instant?

    /// Last token generation time
    private var lastTokenInstant: ContinuousClock.Instant?

    /// Individual token generation timings
    private var tokenTimings: [Duration]

    /// Detailed token information (if enabled)
    private var tokenInfos: [GenerationMetrics.TokenInfo]

    /// Stop reason for generation
    private var stopReason: GenerationMetrics.StopReason?

    /// Prompt token count
    private let promptTokenCount: Int

    /// Generated token count
    private var generatedTokenCount: Int = 0

    /// Context window size
    private var contextWindowSize: Int?

    /// KV cache metrics
    private var kvCacheBytes: Int64?
    private var kvCacheEntries: Int?

    /// Sampling parameters
    private var temperature: Float32?
    private var topP: Float32?
    private var topK: Int32?

    /// Whether to collect detailed token info
    private let collectDetailedMetrics: Bool

    // MARK: - Initialization

    /// Initialize a new metrics collector.
    ///
    /// - Parameters:
    ///   - promptTokenCount: Number of tokens in the prompt
    ///   - expectedTokens: Expected number of tokens to generate (for pre-allocation)
    ///   - collectDetailedMetrics: Whether to collect detailed per-token metrics
    internal init(
        promptTokenCount: Int,
        expectedTokens: Int = 512,
        collectDetailedMetrics: Bool = false
    ) {
        self.startInstant = clock.now
        self.promptTokenCount = promptTokenCount
        self.collectDetailedMetrics = collectDetailedMetrics

        // Only pre-allocate arrays if collecting detailed metrics
        self.tokenTimings = []
        if collectDetailedMetrics {
            self.tokenTimings.reserveCapacity(expectedTokens)
        }

        self.tokenInfos = []
        if collectDetailedMetrics {
            self.tokenInfos.reserveCapacity(expectedTokens)
        }
    }

    // MARK: - Recording Methods

    /// Record that prompt processing has started.
    @inlinable
    internal mutating func recordPromptProcessingStart() {
        promptStartInstant = clock.now
    }

    /// Record that prompt processing has completed.
    @inlinable
    internal mutating func recordPromptProcessingComplete() {
        promptEndInstant = clock.now
    }

    /// Record generation of a new token.
    ///
    /// - Parameters:
    ///   - tokenId: The token ID in the vocabulary
    ///   - text: The decoded text of the token
    ///   - logProb: The log probability of the token
    /// - Returns: The duration since the last token (or start)
    @inlinable
    internal mutating func recordTokenGenerated(
        tokenId: Int32,
        text: String,
        logProb: Float32
    ) -> Duration {
        let now: ContinuousClock.Instant = clock.now
        let duration: Duration = recordTokenTiming(now: now)

        // Store detailed info if enabled
        if collectDetailedMetrics {
            storeTokenInfo(
                tokenId: tokenId,
                text: text,
                logProb: logProb,
                duration: duration
            )
        }

        return duration
    }

    private mutating func recordTokenTiming(now: ContinuousClock.Instant) -> Duration {
        // Record first token time
        if firstTokenInstant == nil {
            firstTokenInstant = now
        }

        // Calculate duration since last token or start
        let duration: Duration
        if let lastToken = lastTokenInstant {
            duration = lastToken.duration(to: now)
        } else {
            duration = startInstant.duration(to: now)
        }

        // Update state
        lastTokenInstant = now
        generatedTokenCount += 1

        // Only store timing if collecting detailed metrics
        if collectDetailedMetrics {
            tokenTimings.append(duration)
        }

        return duration
    }

    private mutating func storeTokenInfo(
        tokenId: Int32,
        text: String,
        logProb: Float32,
        duration: Duration
    ) {
        let tokenInfo: GenerationMetrics.TokenInfo = GenerationMetrics.TokenInfo(
            tokenId: tokenId,
            text: text,
            logProb: logProb,
            duration: duration
        )
        tokenInfos.append(tokenInfo)
    }

    /// Record simplified token generation (without details).
    ///
    /// Use this for maximum performance when detailed metrics aren't needed.
    @inlinable
    internal mutating func recordToken() -> Duration {
        let now: ContinuousClock.Instant = clock.now

        // Record first token time
        if firstTokenInstant == nil {
            firstTokenInstant = now
        }

        // Calculate duration
        let duration: Duration
        if let lastToken = lastTokenInstant {
            duration = lastToken.duration(to: now)
        } else {
            duration = startInstant.duration(to: now)
        }

        // Update state
        lastTokenInstant = now
        generatedTokenCount += 1

        // Only store timing if collecting detailed metrics
        if collectDetailedMetrics {
            tokenTimings.append(duration)
        }

        return duration
    }

    /// Record why generation stopped.
    @inlinable
    internal mutating func recordStopReason(_ reason: GenerationMetrics.StopReason) {
        self.stopReason = reason
    }

    /// Record context window information.
    @inlinable
    internal mutating func recordContextInfo(
        windowSize: Int,
        tokensUsed _: Int
    ) {
        self.contextWindowSize = windowSize
    }

    /// Record KV cache metrics.
    @inlinable
    internal mutating func recordKVCacheMetrics(
        bytes: Int64,
        entries: Int
    ) {
        self.kvCacheBytes = bytes
        self.kvCacheEntries = entries
    }

    /// Record sampling parameters.
    @inlinable
    internal mutating func recordSamplingParameters(
        temperature: Float32?,
        topP: Float32?,
        topK: Int32?
    ) {
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
    }

    // MARK: - Metrics Building

    /// Build timing metrics from collected data.
    internal func buildTimingMetrics() -> TimingMetrics {
        let now: ContinuousClock.Instant = clock.now
        let totalTime: Duration = startInstant.duration(to: now)

        return TimingMetrics(
            totalTime: totalTime,
            timeToFirstToken: calculateTimeToFirstToken(),
            timeSinceLastToken: calculateTimeSinceLastToken(now: now),
            tokenTimings: tokenTimings,
            promptProcessingTime: calculatePromptProcessingTime()
        )
    }

    private func calculateTimeToFirstToken() -> Duration? {
        firstTokenInstant.map { instant in
            startInstant.duration(to: instant)
        }
    }

    private func calculateTimeSinceLastToken(now: ContinuousClock.Instant) -> Duration? {
        lastTokenInstant.map { instant in
            instant.duration(to: now)
        }
    }

    private func calculatePromptProcessingTime() -> Duration? {
        guard let start = promptStartInstant, let end = promptEndInstant else {
            return nil
        }
        return start.duration(to: end)
    }

    /// Build usage metrics from collected data.
    internal func buildUsageMetrics() -> UsageMetrics {
        let totalTokens: Int = promptTokenCount + generatedTokenCount

        // Calculate context tokens used
        let contextTokensUsed: Int? = contextWindowSize.map { _ in
            promptTokenCount + generatedTokenCount
        }

        return UsageMetrics(
            generatedTokens: generatedTokenCount,
            totalTokens: totalTokens,
            promptTokens: promptTokenCount,
            contextWindowSize: contextWindowSize,
            contextTokensUsed: contextTokensUsed,
            kvCacheBytes: kvCacheBytes,
            kvCacheEntries: kvCacheEntries
        )
    }

    /// Build generation metrics from collected data.
    internal func buildGenerationMetrics() -> GenerationMetrics? {
        // Only return generation metrics if we have meaningful data
        guard collectDetailedMetrics || stopReason != nil else {
            return nil
        }

        return GenerationMetrics(
            tokens: tokenInfos,
            stopReason: stopReason,
            temperature: temperature,
            topP: topP,
            topK: topK
        )
    }

    /// Build complete chunk metrics.
    internal func buildChunkMetrics() -> ChunkMetrics {
        ChunkMetrics(
            timing: buildTimingMetrics(),
            usage: buildUsageMetrics(),
            generation: buildGenerationMetrics()
        )
    }

    /// Build minimal metrics for intermediate chunks.
    ///
    /// This is optimized for streaming scenarios where we need
    /// to send metrics with each chunk but want minimal overhead.
    internal func buildIntermediateMetrics(at now: ContinuousClock.Instant) -> ChunkMetrics {
        // Calculate current total time
        let totalTime: Duration = startInstant.duration(to: now)

        // Time to first token (if available)
        let timeToFirstToken: Duration? = firstTokenInstant.map { instant in
            startInstant.duration(to: instant)
        }

        // Time since last token
        let timeSinceLastToken: Duration? = lastTokenInstant.map { instant in
            instant.duration(to: now)
        }

        let timing: TimingMetrics = TimingMetrics(
            totalTime: totalTime,
            timeToFirstToken: timeToFirstToken,
            timeSinceLastToken: timeSinceLastToken,
            tokenTimings: tokenTimings,
            promptProcessingTime: calculatePromptProcessingTime()
        )

        let usage: UsageMetrics = UsageMetrics(
            generatedTokens: generatedTokenCount,
            totalTokens: promptTokenCount + generatedTokenCount,
            promptTokens: promptTokenCount
        )

        return ChunkMetrics(timing: timing, usage: usage)
    }
}

// MARK: - ContinuousClock Extension

extension ContinuousClock.Instant {
    /// Calculate duration to another instant.
    @inlinable
    internal func duration(to other: ContinuousClock.Instant) -> Duration {
        other - self
    }
}

import Abstractions
import Foundation

/// Generation state with integrated metrics collection
internal struct GenerationState {
    /// High-performance metrics collector
    private var metricsCollector: MetricsCollector

    /// Cached prompt token count for efficient access
    private let cachedPromptTokenCount: Int

    /// Cached generated token count for O(1) hot path access
    private var cachedGeneratedTokenCount: Int = 0

    internal init(promptTokenCount: Int, collectDetailedMetrics: Bool = false) {
        // Initialize metrics collector with sensible defaults
        let defaultExpectedTokens: Int = 512
        self.cachedPromptTokenCount = promptTokenCount
        self.metricsCollector = MetricsCollector(
            promptTokenCount: promptTokenCount,
            expectedTokens: defaultExpectedTokens,
            collectDetailedMetrics: collectDetailedMetrics
        )
    }

    /// Record that prompt processing has started
    internal mutating func recordPromptProcessingStart() {
        metricsCollector.recordPromptProcessingStart()
    }

    /// Record that prompt processing has completed
    internal mutating func recordPromptProcessingComplete() {
        metricsCollector.recordPromptProcessingComplete()
    }

    /// Record that a token was generated (simplified version)
    @inline(__always)
    internal mutating func recordTokenGenerated() {
        cachedGeneratedTokenCount += 1
        _ = metricsCollector.recordToken()
    }

    /// Record token with detailed information
    internal mutating func recordTokenGenerated(
        tokenId: Int32,
        text: String,
        logProb: Float32
    ) {
        cachedGeneratedTokenCount += 1
        _ = metricsCollector.recordTokenGenerated(
            tokenId: tokenId,
            text: text,
            logProb: logProb
        )
    }

    /// Record stop reason
    internal mutating func recordStopReason(_ reason: GenerationMetrics.StopReason) {
        metricsCollector.recordStopReason(reason)
    }

    /// Record context information
    internal mutating func recordContextInfo(windowSize: Int, tokensUsed: Int) {
        metricsCollector.recordContextInfo(
            windowSize: windowSize,
            tokensUsed: tokensUsed
        )
    }

    /// Record KV cache metrics
    internal mutating func recordKVCacheMetrics(bytes: Int64, entries: Int) {
        metricsCollector.recordKVCacheMetrics(bytes: bytes, entries: entries)
    }

    /// Record sampling parameters
    internal mutating func recordSamplingParameters(
        temperature: Float32?,
        topP: Float32?,
        topK: Int32?
    ) {
        metricsCollector.recordSamplingParameters(
            temperature: temperature,
            topP: topP,
            topK: topK
        )
    }

    /// Build metrics from current state
    internal func buildMetrics() -> ChunkMetrics {
        metricsCollector.buildChunkMetrics()
    }

    /// Get current generated token count (O(1) access)
    internal var generatedTokenCount: Int {
        cachedGeneratedTokenCount
    }

    /// Get prompt token count
    internal var promptTokenCount: Int {
        cachedPromptTokenCount
    }
}

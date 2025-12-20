/// Token usage information for cost tracking and optimization.
///
/// Understanding token usage is crucial for:
/// - Calculating costs (most APIs charge per token)
/// - Optimizing prompts (reducing unnecessary tokens)
/// - Capacity planning (tokens directly impact latency)
public struct UsageMetrics: Sendable, Codable {
    /// Number of tokens in the input prompt.
    ///
    /// This is typically calculated once at the start of generation.
    /// High prompt token counts increase:
    /// - Cost (for token-based pricing)
    /// - Time to first token (prompt processing time)
    /// - Memory usage (KV cache size)
    public let promptTokens: Int?

    /// Number of tokens generated so far.
    ///
    /// This increases throughout the stream as more tokens are generated.
    public let generatedTokens: Int

    /// Total tokens processed (prompt + generated).
    ///
    /// This is the primary metric for cost calculation on most platforms.
    public let totalTokens: Int

    /// Maximum context window size supported by the model.
    ///
    /// This is the absolute maximum number of tokens the model can process
    /// in a single context. Exceeding this limit will result in errors.
    public let contextWindowSize: Int?

    /// Number of context tokens currently being used.
    ///
    /// This includes both prompt and generated tokens that are currently
    /// in the model's context. Useful for understanding how close to the
    /// context limit the generation is.
    public let contextTokensUsed: Int?

    /// Size of the KV cache in bytes.
    ///
    /// The key-value cache stores attention states and directly impacts
    /// memory usage. Large caches improve performance but consume more memory.
    public let kvCacheBytes: Int64?

    /// Number of entries in the KV cache.
    ///
    /// Each token typically creates entries in the cache. This helps
    /// understand cache utilization and efficiency.
    public let kvCacheEntries: Int?

    /// Creates new usage metrics for cost tracking and optimization.
    ///
    /// The `generatedTokens` and `totalTokens` are required as they
    /// represent the actual work performed. All other metrics are optional
    /// and depend on what the provider can measure.
    ///
    /// - Parameters:
    ///   - generatedTokens: Number of tokens generated so far (required)
    ///   - totalTokens: Total tokens processed, including prompt and generated (required)
    ///   - promptTokens: Optional number of tokens in the input prompt
    ///   - contextWindowSize: Optional maximum context window size
    ///   - contextTokensUsed: Optional number of context tokens currently used
    ///   - kvCacheBytes: Optional KV cache size in bytes
    ///   - kvCacheEntries: Optional number of KV cache entries
    ///
    /// - Note: If `promptTokens` is provided, it should equal `totalTokens - generatedTokens`.
    ///   Providers are responsible for maintaining this consistency.
    public init(
        generatedTokens: Int,
        totalTokens: Int,
        promptTokens: Int? = nil,
        contextWindowSize: Int? = nil,
        contextTokensUsed: Int? = nil,
        kvCacheBytes: Int64? = nil,
        kvCacheEntries: Int? = nil
    ) {
        self.promptTokens = promptTokens
        self.generatedTokens = generatedTokens
        self.totalTokens = totalTokens
        self.contextWindowSize = contextWindowSize
        self.contextTokensUsed = contextTokensUsed
        self.kvCacheBytes = kvCacheBytes
        self.kvCacheEntries = kvCacheEntries
    }
}

// MARK: - Computed Properties

extension UsageMetrics {
    /// Percentage of context window currently in use.
    ///
    /// Returns nil if either contextTokensUsed or contextWindowSize is unavailable.
    public var contextUtilization: Double? {
        guard let used = contextTokensUsed,
              let window = contextWindowSize,
              window > 0 else { return nil }
        return Double(used) / Double(window)
    }

    /// Average bytes per cache entry.
    ///
    /// Useful for understanding memory efficiency of the cache implementation.
    public var averageBytesPerCacheEntry: Double? {
        guard let bytes = kvCacheBytes,
              let entries = kvCacheEntries,
              entries > 0 else { return nil }
        return Double(bytes) / Double(entries)
    }

    /// Remaining tokens available in the context window.
    ///
    /// Returns nil if either contextTokensUsed or contextWindowSize is unavailable.
    public var remainingContextTokens: Int? {
        guard let used = contextTokensUsed,
              let window = contextWindowSize else { return nil }
        return max(0, window - used)
    }
}

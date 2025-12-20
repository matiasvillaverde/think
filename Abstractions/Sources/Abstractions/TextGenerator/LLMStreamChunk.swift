/// A chunk of generated text with optional performance metrics.
///
/// Each chunk represents an incremental piece of the model's output.
/// Chunks are designed to be small enough for responsive streaming but
/// large enough to be efficient. The exact chunking strategy depends on
/// the provider and network conditions.
public struct LLMStreamChunk: Sendable {
    /// The text content generated in this chunk.
    ///
    /// This may be:
    /// - A single token (common for local models)
    /// - Multiple tokens (common for remote APIs to reduce overhead)
    /// - A partial UTF-8 sequence (be prepared to buffer incomplete characters)
    ///
    /// For tool calls or structured output, this text will contain the
    /// serialized format (e.g., JSON) that consumers need to parse.
    public let text: String

    /// Optional performance and usage metrics for this chunk.
    ///
    /// Metrics may be provided:
    /// - With every chunk (for real-time monitoring)
    /// - Only with the first/last chunk (for efficiency)
    /// - Never (for simple providers)
    ///
    /// Consumers should handle nil metrics gracefully.
    public let metrics: ChunkMetrics?

    /// Lifecycle events for the stream.
    ///
    /// Events provide additional context about the streaming process,
    /// allowing consumers to handle different phases appropriately.
    public let event: StreamEvent

    /// Creates a new LLM stream chunk with text, metrics, and event information.
    ///
    /// - Parameters:
    ///   - text: The text content generated in this chunk
    ///   - metrics: Optional performance and usage metrics for this chunk
    ///   - event: The lifecycle event associated with this chunk
    public init(text: String, event: StreamEvent, metrics: ChunkMetrics? = nil) {
        self.text = text
        self.metrics = metrics
        self.event = event
    }
}

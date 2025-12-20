/// Events that occur during the streaming lifecycle.
public enum StreamEvent: Sendable {
    /// Normal text generation chunk.
    /// This is the most common event during streaming.
    case text

    /// Metrics-only update with no new text.
    /// Useful for providing periodic performance updates during long generations.
    case metrics

    /// Stream completed successfully.
    /// No more chunks will be sent after this event.
    case finished

    /// Stream encountered an error.
    /// This is the last event in the stream. The error may be recoverable
    /// (e.g., rate limit) or permanent (e.g., invalid model).
    case error(Error)
}

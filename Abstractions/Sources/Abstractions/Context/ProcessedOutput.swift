/// Represents the fully processed output from an LLM response.
///
/// This struct contains the final state after processing an LLM output
/// using channel messages (Harmony format). Tool requests are now stored
/// as channels with type .tool for unified chronological ordering.
public struct ProcessedOutput: Sendable {
    /// Channel messages extracted from the output (including tool channels)
    public let channels: [ChannelMessage]

    /// Initialize with channels only
    public init(channels: [ChannelMessage]) {
        self.channels = channels
    }

    /// Computed property for extracting tool requests from channels with tool requests
    public var toolRequests: [ToolRequest] {
        channels.compactMap(\.toolRequest)
    }
}

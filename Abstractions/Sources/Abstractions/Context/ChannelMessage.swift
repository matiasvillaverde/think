import Foundation

/// Represents a message within a Harmony channel
///
/// Harmony uses channels to organize different types of output:
/// - `analysis`: Internal reasoning and thinking
/// - `commentary`: Tool-related communication
/// - `final`: User-facing responses
public struct ChannelMessage: Sendable, Equatable {
    /// The type of channel this message belongs to
    public enum ChannelType: String, Sendable, Equatable, CaseIterable {
        /// Analysis channel for internal reasoning
        case analysis = "analysis"
        /// Commentary channel for tool-related communication
        case commentary = "commentary"
        /// Final channel for user-facing responses
        case final = "final"
        /// Tool channel for tool call execution
        case tool = "tool"
    }

    /// Unique identifier for this channel message
    public let id: UUID

    /// The channel type
    public let type: ChannelType

    /// The content of the message
    public let content: String

    /// The order of this message in the sequence
    public let order: Int

    /// Optional recipient (e.g., "to=functions.toolname" or "to=user")
    public let recipient: String?

    /// Optional tool request for tool channels
    public let toolRequest: ToolRequest?

    /// Initialize a channel message
    /// - Parameters:
    ///   - id: Unique identifier for the channel message
    ///   - type: The channel type
    ///   - content: The message content
    ///   - order: The sequence order
    ///   - recipient: Optional recipient specification
    ///   - toolRequest: Optional tool request for tool channels
    public init(
        id: UUID,
        type: ChannelType,
        content: String,
        order: Int,
        recipient: String? = nil,
        toolRequest: ToolRequest? = nil
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.order = order
        self.recipient = recipient
        self.toolRequest = toolRequest
    }
}

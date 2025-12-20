import Foundation

/// Represents a channel within a message for structured content organization
public struct MessageChannel: Sendable, Equatable {
    /// The type of channel content
    public enum ChannelType: String, Sendable, Equatable, CaseIterable {
        case commentary
        case final
    }

    /// The type of this channel
    public let type: ChannelType
    /// The content of the channel
    public let content: String
    /// The order of this channel in the sequence
    public let order: Int
    /// Optional tool ID this channel is associated with
    public let associatedToolId: UUID?

    /// Initialize a new MessageChannel
    public init(
        type: ChannelType,
        content: String,
        order: Int = 0,
        associatedToolId: UUID? = nil
    ) {
        self.type = type
        self.content = content
        self.order = order
        self.associatedToolId = associatedToolId
    }
}

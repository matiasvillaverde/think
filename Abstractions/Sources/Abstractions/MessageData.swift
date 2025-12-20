import Foundation

/// Represents a message in the conversation history
public struct MessageData: Sendable, Equatable {
    /// Unique identifier for the message
    public let id: UUID
    /// When the message was created
    public let createdAt: Date
    /// The user's input message
    public let userInput: String?
    /// Structured channels containing the message content
    public let channels: [MessageChannel]
    /// Tool calls made by the assistant as part of this message
    public let toolCalls: [ToolCall]

    /// Initialize a new message data
    public init(
        id: UUID,
        createdAt: Date,
        userInput: String?,
        channels: [MessageChannel] = [],
        toolCalls: [ToolCall] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.userInput = userInput
        self.channels = channels
        self.toolCalls = toolCalls
    }
}

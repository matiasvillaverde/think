import Foundation

/// Immutable tool request from LLM (Value Object pattern)
public struct ToolRequest: Sendable, Equatable, Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let arguments: String // JSON string
    public let displayName: String?
    /// Context metadata for the tool request
    public let context: ToolRequestContext?

    // Streaming support
    public let isComplete: Bool

    // Harmony-specific metadata
    public let recipient: String?
    public let constraint: String?
    public let commentary: String?

    public init(
        name: String,
        arguments: String,
        isComplete: Bool = true,
        displayName: String? = nil,
        recipient: String? = nil,
        constraint: String? = nil,
        commentary: String? = nil,
        context: ToolRequestContext? = nil,
        id: UUID = UUID()
    ) {
        self.id = id
        self.name = name
        self.arguments = arguments
        self.isComplete = isComplete
        self.displayName = displayName
        self.recipient = recipient
        self.constraint = constraint
        self.commentary = commentary
        self.context = context
    }
}

/// Metadata for tool requests passed from orchestrator context.
public struct ToolRequestContext: Sendable, Equatable, Codable {
    /// Chat identifier associated with the tool request.
    public let chatId: UUID?
    /// Message identifier associated with the tool request.
    public let messageId: UUID?
    /// Whether tool policy should be enforced for this request.
    public let hasToolPolicy: Bool
    /// Tool names explicitly allowed for this request.
    public let allowedToolNames: [String]

    public init(
        chatId: UUID?,
        messageId: UUID?,
        hasToolPolicy: Bool = false,
        allowedToolNames: [String] = []
    ) {
        self.chatId = chatId
        self.messageId = messageId
        self.hasToolPolicy = hasToolPolicy
        self.allowedToolNames = allowedToolNames
    }
}

extension ToolRequest {
    /// Returns a new ToolRequest with attached context metadata.
    public func withContext(
        chatId: UUID?,
        messageId: UUID?,
        hasToolPolicy: Bool = false,
        allowedToolNames: [String] = []
    ) -> ToolRequest {
        ToolRequest(
            name: name,
            arguments: arguments,
            isComplete: isComplete,
            displayName: displayName,
            recipient: recipient,
            constraint: constraint,
            commentary: commentary,
            context: ToolRequestContext(
                chatId: chatId,
                messageId: messageId,
                hasToolPolicy: hasToolPolicy,
                allowedToolNames: allowedToolNames
            ),
            id: id
        )
    }
}

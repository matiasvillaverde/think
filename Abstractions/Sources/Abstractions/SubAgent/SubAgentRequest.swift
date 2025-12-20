import Foundation

/// Request to spawn a sub-agent
public struct SubAgentRequest: Sendable, Equatable, Identifiable {
    /// Unique identifier for this request
    public let id: UUID
    /// The parent message ID that spawned this request
    public let parentMessageId: UUID
    /// The parent chat ID
    public let parentChatId: UUID
    /// The task/prompt for the sub-agent
    public let prompt: String
    /// Tools available to the sub-agent
    public let tools: Set<ToolIdentifier>
    /// Execution mode
    public let mode: SubAgentMode
    /// Maximum duration before timeout
    public let timeout: Duration
    /// Optional custom system instruction
    public let systemInstruction: String?
    /// When the request was created
    public let createdAt: Date

    /// Initialize a new sub-agent request
    public init(
        parentMessageId: UUID,
        parentChatId: UUID,
        prompt: String,
        id: UUID = UUID(),
        tools: Set<ToolIdentifier> = [],
        mode: SubAgentMode = .background,
        timeout: Duration = .seconds(300),
        systemInstruction: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.parentMessageId = parentMessageId
        self.parentChatId = parentChatId
        self.prompt = prompt
        self.tools = tools
        self.mode = mode
        self.timeout = timeout
        self.systemInstruction = systemInstruction
        self.createdAt = createdAt
    }
}

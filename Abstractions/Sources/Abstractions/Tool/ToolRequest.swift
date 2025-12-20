import Foundation

/// Immutable tool request from LLM (Value Object pattern)
public struct ToolRequest: Sendable, Equatable, Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let arguments: String // JSON string
    public let displayName: String?

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
    }
}

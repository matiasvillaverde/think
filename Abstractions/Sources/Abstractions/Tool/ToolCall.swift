import Foundation

/// Represents a tool call made by the assistant
public struct ToolCall: Sendable, Equatable, Codable {
    /// The name of the tool being called
    public let name: String

    /// The arguments for the tool call as a JSON string
    /// Example: {"city": "Berlin"}
    public let arguments: String

    /// Optional identifier for the tool call (used by some models)
    public let id: String?

    /// Initialize a new tool call
    public init(
        name: String,
        arguments: String,
        id: String? = nil
    ) {
        self.name = name
        self.arguments = arguments
        self.id = id
    }
}

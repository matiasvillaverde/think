import Foundation

/// Cached tool definition (Flyweight Pattern)
public struct ToolDefinition: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let name: String
    public let description: String
    public let schema: String  // JSON Schema string
    public let metadata: EnhancedToolMetadata?

    public init(
        name: String,
        description: String,
        schema: String,
        metadata: EnhancedToolMetadata? = nil,
        id: UUID = UUID()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.schema = schema
        self.metadata = metadata
    }
}

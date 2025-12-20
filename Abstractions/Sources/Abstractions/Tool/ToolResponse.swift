import Foundation

/// Tool execution result (Value Object)
public struct ToolResponse: Sendable, Equatable, Identifiable, Codable {
    public let id: UUID
    public let requestId: UUID // Links to ToolRequest
    public let toolName: String // Name of the tool that was executed
    public let result: String // JSON string
    public let metadata: ResponseMetadata?
    public let error: String? // Error message

    public struct ResponseMetadata: Sendable, Equatable, Codable {
        public let sources: [URL]
        public let duration: TimeInterval?
        public let tokens: Int?

        public init(
            sources: [URL] = [],
            duration: TimeInterval? = nil,
            tokens: Int? = nil
        ) {
            self.sources = sources
            self.duration = duration
            self.tokens = tokens
        }
    }

    public init(
        requestId: UUID,
        toolName: String,
        result: String,
        metadata: ResponseMetadata? = nil,
        error: String? = nil,
        id: UUID = UUID()
    ) {
        self.id = id
        self.requestId = requestId
        self.toolName = toolName
        self.result = result
        self.metadata = metadata
        self.error = error
    }

    /// Check if this response represents an error
    public var isError: Bool {
        error != nil
    }
}

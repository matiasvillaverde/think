import Abstractions
import Foundation
import OSLog

/// Strategy for memory management tool - allows the agent to write important information to persistent memory
public struct MemoryStrategy: ToolStrategy {
    /// Logger for memory tool operations
    private static let logger: Logger = Logger(subsystem: "Tools", category: "MemoryStrategy")

    /// The tool definition
    public let definition: ToolDefinition = ToolDefinition(
        name: "memory",
        description: """
            Write important information to persistent memory. Use this tool to remember facts, \
            preferences, and observations that should persist across conversations. Types: \
            'longTerm' for curated facts, 'daily' for contextual observations.
            """,
        schema: """
        {
            "type": "object",
            "properties": {
                "type": {
                    "type": "string",
                    "description": "The type of memory to write",
                    "enum": ["longTerm", "daily"]
                },
                "content": {
                    "type": "string",
                    "description": "The fact, observation, or information to remember"
                },
                "keywords": {
                    "type": "array",
                    "items": { "type": "string" },
                    "description": "Keywords for categorizing and searching this memory",
                    "default": []
                }
            },
            "required": ["type", "content"]
        }
        """
    )

    /// Callback to write memory to the database
    private let writeCallback: @Sendable (MemoryWriteRequest) async -> Result<UUID, Error>

    /// Initialize a new MemoryStrategy
    /// - Parameter writeCallback: Callback to persist the memory entry
    @preconcurrency
    public init(writeCallback: @escaping @Sendable (MemoryWriteRequest) async -> Result<UUID, Error>) {
        self.writeCallback = writeCallback
    }

    /// Execute the memory write request
    /// - Parameter request: The tool request
    /// - Returns: The tool response with success or error
    public func execute(request: ToolRequest) async -> ToolResponse {
        Self.logger.debug("Processing memory request for request ID: \(request.id)")

        // Parse arguments
        switch BaseToolStrategy.parseArguments(request) {
        case .failure(let error):
            return BaseToolStrategy.errorResponse(request: request, error: error.message)

        case .success(let json):
            // Validate required type parameter
            guard let typeString = json["type"] as? String else {
                Self.logger.warning("Memory request missing type parameter")
                return BaseToolStrategy.errorResponse(
                    request: request,
                    error: "Missing required parameter: type"
                )
            }

            guard let memoryType = parseMemoryType(typeString) else {
                Self.logger.warning("Invalid memory type: \(typeString)")
                return BaseToolStrategy.errorResponse(
                    request: request,
                    error: "Invalid memory type: \(typeString). Use 'longTerm' or 'daily'."
                )
            }

            // Validate required content parameter
            guard let content = json["content"] as? String, !content.isEmpty else {
                Self.logger.warning("Memory request missing content parameter")
                return BaseToolStrategy.errorResponse(
                    request: request,
                    error: "Missing required parameter: content"
                )
            }

            // Extract optional keywords
            let keywords: [String] = json["keywords"] as? [String] ?? []

            Self.logger.info("Writing \(memoryType.rawValue) memory with \(keywords.count) keywords")

            // Create write request and execute callback
            let writeRequest: MemoryWriteRequest = MemoryWriteRequest(
                type: memoryType,
                content: content,
                keywords: keywords
            )

            let result: Result<UUID, Error> = await writeCallback(writeRequest)

            switch result {
            case .success(let memoryId):
                Self.logger.notice("Memory written successfully: \(memoryId)")
                return BaseToolStrategy.successResponse(
                    request: request,
                    result: "Memory saved successfully (id: \(memoryId.uuidString))"
                )

            case .failure(let error):
                Self.logger.error("Failed to write memory: \(error.localizedDescription)")
                return BaseToolStrategy.errorResponse(
                    request: request,
                    error: "Failed to save memory: \(error.localizedDescription)"
                )
            }
        }
    }

    /// Parse memory type string to enum
    private func parseMemoryType(_ string: String) -> MemoryType? {
        switch string.lowercased() {
        case "longterm", "long_term", "long-term":
            return .longTerm

        case "daily":
            return .daily

        default:
            return nil
        }
    }
}

/// Request to write a memory entry
public struct MemoryWriteRequest: Sendable {
    /// The type of memory
    public let type: MemoryType
    /// The content to store
    public let content: String
    /// Keywords for searching
    public let keywords: [String]

    /// Initialize a new memory write request
    public init(type: MemoryType, content: String, keywords: [String] = []) {
        self.type = type
        self.content = content
        self.keywords = keywords
    }
}

import Foundation

/// Facade protocol for all tool-related operations
/// Provides a clean interface between Context and Tools modules
public protocol Tooling: Actor {
    // MARK: - Tool Configuration

    /// Configure which tools should be available based on identifiers
    /// - Parameter identifiers: Set of tool identifiers to enable
    func configureTool(identifiers: Set<ToolIdentifier>) async

    /// Clear all configured tools
    func clearTools() async

    // MARK: - Tool Metadata Access

    /// Get tool definitions for specified identifiers
    /// - Parameter identifiers: Tool identifiers to get definitions for
    /// - Returns: Array of tool definitions with metadata
    func getToolDefinitions(for identifiers: Set<ToolIdentifier>) async -> [ToolDefinition]

    /// Get all currently configured tool definitions
    /// - Returns: Array of all active tool definitions
    func getAllToolDefinitions() async -> [ToolDefinition]

    // MARK: - Tool Execution

    /// Execute tool requests
    /// - Parameter toolRequests: Array of tool requests to execute
    /// - Returns: Array of tool responses
    func executeTools(
        toolRequests: [ToolRequest]
    ) async -> [ToolResponse]

    // MARK: - Semantic Search (Special Case)

    /// Configure semantic search with database context
    /// - Parameters:
    ///   - database: Database instance for performing searches
    ///   - chatId: Chat identifier for context
    ///   - fileTitles: Titles of files to search within
    func configureSemanticSearch(
        database: DatabaseProtocol,
        chatId: UUID,
        fileTitles: [String]
    ) async
}

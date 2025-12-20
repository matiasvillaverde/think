import Abstractions
import Foundation
import OSLog

/// Executes tool requests and returns responses
public actor ToolExecutor {
    /// Logger for tool execution operations
    private let logger: Logger = Logger(subsystem: "Tools", category: "ToolExecutor")
    // Store tool strategies
    private var strategies: [String: ToolStrategy] = [:]

    /// Initialize a new ToolExecutor
    public init() {
        // Initialize with empty strategies dictionary
    }

    /// Clear all registered tools
    public func clearTools() {
        let toolCount: Int = strategies.count
        strategies.removeAll()
        logger.debug("Cleared \(toolCount) registered tools")
    }

    /// Register a tool strategy
    public func registerStrategy(_ strategy: ToolStrategy) {
        strategies[strategy.definition.name] = strategy
        logger.debug("Registered strategy: \(strategy.definition.name)")
    }

    /// Get all registered tool definitions
    public func getDefinitions() -> [ToolDefinition] {
        strategies.values.map(\.definition)
    }

    /// Execute a single tool request
    public func execute(request: ToolRequest) async throws -> ToolResponse {
        logger.debug("Executing tool request: \(request.name) (ID: \(request.id))")

        // Check if strategy exists
        guard let strategy = strategies[request.name] else {
            logger.warning("Tool not found: \(request.name)")
            return ToolResponse(
                requestId: request.id,
                toolName: request.name,
                result: "",
                error: "Tool not found: \(request.name)"
            )
        }

        // Execute using the strategy
        let response: ToolResponse = await strategy.execute(request: request)

        if response.error != nil {
            logger.error("Tool execution failed: \(request.name) - \(response.error ?? "unknown error")")
        } else {
            logger.debug("Tool execution completed: \(request.name)")
        }

        return response
    }

    /// Execute multiple requests in parallel
    public func executeBatch(requests: [ToolRequest]) async throws -> [ToolResponse] {
        logger.info("Executing batch of \(requests.count) tool requests")

        // Execute all requests concurrently
        return await withTaskGroup(of: ToolResponse.self) { group in
            for request in requests {
                group.addTask {
                    (try? await self.execute(request: request)) ?? ToolResponse(
                        requestId: request.id,
                        toolName: request.name,
                        result: "",
                        error: "Execution failed"
                    )
                }
            }

            var responses: [ToolResponse] = []
            for await response in group {
                responses.append(response)
            }
            return responses
        }
    }
}

import Abstractions
import Foundation
import OSLog

/// Manages tool execution and registration
public actor ToolManager: Tooling {
    /// Logger for tool management operations
    private let logger: Logger = Logger(subsystem: "Tools", category: "ToolManager")
    private var configuredIdentifiers: Set<ToolIdentifier> = []
    private let executor: ToolExecutor = ToolExecutor()

    /// Initialize a new ToolManager
    public init() {
        // Initialize with empty executor
    }

    /// Register a tool strategy
    public func registerStrategy(_ strategy: ToolStrategy) async {
        logger.debug("Registering tool strategy: \(strategy.definition.name)")
        await executor.registerStrategy(strategy)
        logger.info("Successfully registered tool: \(strategy.definition.name, privacy: .public)")
    }

    // MARK: - Tool Configuration

    public func configureTool(identifiers: Set<ToolIdentifier>) async {
        logger.info("Configuring tools with \(identifiers.count) identifiers")
        logger.debug("Tool identifiers: \(identifiers.map(\.rawValue).joined(separator: ", "))")

        // Store configured identifiers
        configuredIdentifiers = identifiers

        // Clear existing tools in executor
        await executor.clearTools()

        // Register strategies for each identifier
        for identifier in identifiers {
            switch identifier {
            case .browser:
                await executor.registerStrategy(BrowserSearchStrategy())

            case .python:
                await executor.registerStrategy(PythonStrategy())

            case .functions:
                await executor.registerStrategy(FunctionsStrategy())

            case .healthKit:
                await executor.registerStrategy(HealthKitStrategy())

            case .weather:
                await executor.registerStrategy(WeatherStrategy())

            case .duckduckgo:
                await executor.registerStrategy(DuckDuckGoSearchStrategy())

            case .braveSearch:
                await executor.registerStrategy(BraveSearchStrategy())

            case .reasoning:
                // Reasoning is handled by the LLM itself, no tool needed
                break

            case .imageGeneration:
                // Image generation is handled by separate module
                break
            }
        }

        logger.notice("Tool configuration completed successfully with \(identifiers.count) tools")
    }

    public func clearTools() async {
        logger.info("Clearing all configured tools")
        configuredIdentifiers.removeAll()
        await executor.clearTools()
        logger.notice("Tools cleared successfully")
    }

    // MARK: - Tool Metadata Access

    public func getToolDefinitions(for identifiers: Set<ToolIdentifier>) async -> [ToolDefinition] {
        let allDefinitions: [ToolDefinition] = await executor.getDefinitions()
        let requestedToolNames: Set<String> = Set(identifiers.map(\.toolName))
        return allDefinitions.filter { definition in
            requestedToolNames.contains(definition.name)
        }
    }

    public func getAllToolDefinitions() async -> [ToolDefinition] {
        await executor.getDefinitions()
    }

    // MARK: - Tool Execution

    public func executeTools(
        toolRequests: [ToolRequest]
    ) async -> [ToolResponse] {
        logger.info("Executing \(toolRequests.count) tool request(s)")
        logger.debug("Tool requests: \(toolRequests.map(\.name).joined(separator: ", "))")

        // Delegate to executor for batch execution
        let responses: [ToolResponse] = await executor.executeBatch(requests: toolRequests)

        let errorCount: Int = responses.count { $0.error != nil }
        let successCount: Int = responses.count - errorCount
        logger.notice("Tool execution completed: \(successCount) successful, \(errorCount) failed")

        return responses
    }

    // MARK: - Semantic Search (Special Case)

    public func configureSemanticSearch(
        database: DatabaseProtocol,
        chatId: UUID,
        fileTitles: [String]
    ) async {
        logger.info("Configuring semantic search for chat: \(chatId)")
        logger.debug("Semantic search files: \(fileTitles.count) file(s)")

        // Register the semantic search strategy with the required dependencies
        let semanticSearchStrategy: SemanticSearchStrategy = SemanticSearchStrategy(
            database: database,
            chatId: chatId,
            fileTitles: fileTitles
        )
        await executor.registerStrategy(semanticSearchStrategy)

        logger.notice("Semantic search configured successfully")
    }
}

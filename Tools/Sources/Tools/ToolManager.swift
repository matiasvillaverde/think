import Abstractions
import Database
import Foundation
import OSLog

/// Manages tool execution and registration
public actor ToolManager: Tooling {
    /// Logger for tool management operations
    private let logger: Logger = Logger(subsystem: "Tools", category: "ToolManager")
    private var configuredIdentifiers: Set<ToolIdentifier> = []
    private let executor: ToolExecutor = ToolExecutor()
    private let subAgentOrchestrator: SubAgentOrchestrating?
    private let workspaceRoot: URL?
    private let database: DatabaseProtocol?

    /// Initialize a new ToolManager
    public init(
        subAgentOrchestrator: SubAgentOrchestrating? = nil,
        workspaceRoot: URL? = nil,
        database: DatabaseProtocol? = nil
    ) {
        self.subAgentOrchestrator = subAgentOrchestrator
        self.workspaceRoot = workspaceRoot
        self.database = database
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
            await registerStrategy(for: identifier)
        }

        logger.notice("Tool configuration completed successfully with \(identifiers.count) tools")
    }

    private func registerStrategy(for identifier: ToolIdentifier) async {
        if let strategy = basicStrategy(for: identifier) {
            await executor.registerStrategy(strategy)
            return
        }

        if let strategy = databaseStrategy(for: identifier) {
            await executor.registerStrategy(strategy)
            return
        }

        switch identifier {
        case .subAgent:
            if let orchestrator = subAgentOrchestrator {
                await executor.registerStrategy(SubAgentStrategy(orchestrator: orchestrator))
            } else {
                logger.warning("Sub-agent tool requested but orchestrator not configured")
            }

        case .workspace:
            if let workspaceRoot {
                await executor.registerStrategy(
                    WorkspaceFileStrategy(rootURL: workspaceRoot)
                )
            } else {
                logger.warning("Workspace tool requested but root not configured")
            }

        case .memory:
            await registerMemoryStrategy()

        case .reasoning, .imageGeneration, .cron, .canvas, .nodes:
            break

        case .browser, .python, .functions, .healthKit, .weather, .duckduckgo, .braveSearch:
            break
        }
    }

    private func basicStrategy(for identifier: ToolIdentifier) -> ToolStrategy? {
        switch identifier {
        case .browser:
            return BrowserSearchStrategy()

        case .python:
            return PythonStrategy()

        case .functions:
            return FunctionsStrategy()

        case .healthKit:
            return HealthKitStrategy()

        case .weather:
            return WeatherStrategy()

        case .duckduckgo:
            return DuckDuckGoSearchStrategy()

        case .braveSearch:
            return BraveSearchStrategy()

        case .subAgent, .workspace, .reasoning, .imageGeneration, .memory:
            return nil

        case .cron, .canvas, .nodes:
            return nil
        }
    }

    private func databaseStrategy(for identifier: ToolIdentifier) -> ToolStrategy? {
        guard let database else {
            logger.warning("Tool \(identifier.rawValue) requires database but none configured")
            return nil
        }

        switch identifier {
        case .cron:
            return CronStrategy(database: database)

        case .canvas:
            return CanvasStrategy(database: database)

        case .nodes:
            return NodesStrategy(database: database)

        case .browser, .python, .functions, .healthKit, .weather, .duckduckgo, .braveSearch,
            .subAgent, .workspace, .reasoning, .imageGeneration, .memory:
            return nil
        }
    }

    private func registerMemoryStrategy() async {
        guard let database else {
            logger.warning("Memory tool requested but database not configured")
            return
        }

        await configureMemory { request in
            await self.persistMemory(request, using: database)
        }
    }

    private func persistMemory(
        _ request: MemoryWriteRequest,
        using database: DatabaseProtocol
    ) async -> Result<UUID, Error> {
        do {
            switch request.type {
            case .longTerm:
                let memoryId: UUID = try await database.write(
                    MemoryCommands.Create(
                        type: .longTerm,
                        content: request.content,
                        keywords: request.keywords,
                        chatId: request.chatId
                    )
                )
                return .success(memoryId)

            case .daily:
                let memoryId: UUID = try await database.write(
                    MemoryCommands.AppendToDaily(
                        content: request.content,
                        chatId: request.chatId
                    )
                )

                if !request.keywords.isEmpty {
                    _ = try await database.write(
                        MemoryCommands.AddKeywords(
                            memoryId: memoryId,
                            keywords: request.keywords
                        )
                    )
                }

                return .success(memoryId)

            case .soul:
                let memoryId: UUID = try await database.write(
                    MemoryCommands.UpsertSoul(content: request.content)
                )
                return .success(memoryId)
            }
        } catch {
            return .failure(error)
        }
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

        var allowedRequests: [ToolRequest] = []
        var blockedResponses: [UUID: ToolResponse] = [:]
        for request in toolRequests {
            if isAllowed(request) {
                allowedRequests.append(request)
            } else {
                let response: ToolResponse = ToolResponse(
                    requestId: request.id,
                    toolName: request.name,
                    result: "",
                    error: "Tool blocked by policy: \(request.name)"
                )
                blockedResponses[request.id] = response
            }
        }

        if !blockedResponses.isEmpty {
            logger.notice("Blocked \(blockedResponses.count) tool(s) due to policy")
        }

        // Delegate to executor for batch execution
        let allowedResponses: [ToolResponse] = await executor.executeBatch(
            requests: allowedRequests
        )
        var allowedById: [UUID: ToolResponse] = [:]
        for response in allowedResponses {
            allowedById[response.requestId] = response
        }

        var responses: [ToolResponse] = []
        responses.reserveCapacity(toolRequests.count)
        for request in toolRequests {
            if let response = allowedById[request.id] {
                responses.append(response)
            } else if let blocked = blockedResponses[request.id] {
                responses.append(blocked)
            }
        }

        let errorCount: Int = responses.count { $0.error != nil }
        let successCount: Int = responses.count - errorCount
        logger.notice("Tool execution completed: \(successCount) successful, \(errorCount) failed")

        return responses
    }

    private func isAllowed(_ request: ToolRequest) -> Bool {
        guard let context = request.context, context.hasToolPolicy else {
            return true
        }
        if context.allowedToolNames.contains(request.name) {
            return true
        }
        return ToolIdentifier.from(toolName: request.name) == nil
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

    // MARK: - Memory (Special Case)

    /// Configures the memory tool with a write callback
    /// - Parameter writeCallback: Callback to persist memory entries to the database
    @preconcurrency
    public func configureMemory(
        writeCallback: @escaping @Sendable (MemoryWriteRequest) async -> Result<UUID, Error>
    ) async {
        logger.info("Configuring memory tool")

        let memoryStrategy: MemoryStrategy = MemoryStrategy(writeCallback: writeCallback)
        await executor.registerStrategy(memoryStrategy)

        logger.notice("Memory tool configured successfully")
    }
}

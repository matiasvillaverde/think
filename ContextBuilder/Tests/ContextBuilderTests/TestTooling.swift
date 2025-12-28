import Abstractions
import Foundation

internal actor TestTooling: Tooling {
    private let definitions: [ToolDefinition]

    init(definitions: [ToolDefinition]) {
        self.definitions = definitions
    }

    func configureTool(identifiers _: Set<ToolIdentifier>) async {
        await Task.yield()
    }

    func clearTools() async {
        await Task.yield()
    }

    func getToolDefinitions(for identifiers: Set<ToolIdentifier>) async -> [ToolDefinition] {
        await Task.yield()
        let requested = Set(identifiers.map(\.toolName))
        return definitions.filter { requested.contains($0.name) }
    }

    func getAllToolDefinitions() async -> [ToolDefinition] {
        await Task.yield()
        return definitions
    }

    func executeTools(toolRequests _: [ToolRequest]) async -> [ToolResponse] {
        await Task.yield()
        return []
    }

    func configureSemanticSearch(
        database _: DatabaseProtocol,
        chatId _: UUID,
        fileTitles _: [String]
    ) async {
        await Task.yield()
    }
}

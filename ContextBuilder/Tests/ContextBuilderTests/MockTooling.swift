import Abstractions
import Foundation

internal actor MockTooling: Tooling {
    func configureTool(identifiers _: Set<ToolIdentifier>) async {
        await Task.yield()
    }

    func clearTools() async {
        await Task.yield()
    }

    func getToolDefinitions(for _: Set<ToolIdentifier>) async -> [ToolDefinition] {
        await Task.yield()
        return []
    }

    func getAllToolDefinitions() async -> [ToolDefinition] {
        await Task.yield()
        return []
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

import Abstractions
import Foundation

/// Mock tooling that provides a browser tool for testing
internal actor MockBrowserTooling: Tooling {
    func configureTool(identifiers _: Set<ToolIdentifier>) async {
        await Task.yield()
    }

    func clearTools() async {
        await Task.yield()
    }

    func getToolDefinitions(for identifiers: Set<ToolIdentifier>) async -> [ToolDefinition] {
        await Task.yield()
        guard identifiers.contains(.browser) else {
            return []
        }

        return [
            ToolDefinition(
                name: "browser.search",
                description: "Search the web for information",
                schema: """
                {
                    "type": "object",
                    "properties": {
                        "query": {
                            "type": "string"
                        },
                        "max_results": {
                            "type": "number"
                        }
                    },
                    "required": ["query"]
                }
                """
            )
        ]
    }

    func getAllToolDefinitions() async -> [ToolDefinition] {
        await Task.yield()
        return await getToolDefinitions(for: [.browser])
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

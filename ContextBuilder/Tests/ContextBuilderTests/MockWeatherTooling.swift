import Abstractions
import Foundation

/// Mock tooling that provides a weather tool for testing
internal actor MockWeatherTooling: Tooling {
    func configureTool(identifiers _: Set<ToolIdentifier>) async {
        await Task.yield()
    }

    func clearTools() async {
        await Task.yield()
    }

    func getToolDefinitions(for identifiers: Set<ToolIdentifier>) async -> [ToolDefinition] {
        await Task.yield()
        guard identifiers.contains(.weather) else {
            return []
        }

        return [
            ToolDefinition(
                name: "weather",
                description: "Get weather for a city",
                schema: """
                {
                    "type": "object",
                    "properties": {
                        "city": {
                            "type": "string"
                        }
                    },
                    "required": ["city"]
                }
                """
            )
        ]
    }

    func getAllToolDefinitions() async -> [ToolDefinition] {
        await Task.yield()
        return await getToolDefinitions(for: [.weather])
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

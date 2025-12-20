import Abstractions
import Foundation

/// Mock tooling that provides both weather and reasoning tools for testing
internal actor MockWeatherAndReasoningTooling: Tooling {
    func configureTool(identifiers _: Set<ToolIdentifier>) async throws {
        await Task.yield()
    }

    func clearTools() async {
        await Task.yield()
    }

    func getToolDefinitions(for identifiers: Set<ToolIdentifier>) async -> [ToolDefinition] {
        await Task.yield()
        var tools: [ToolDefinition] = []

        if identifiers.contains(.weather) {
            tools.append(
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
            )
        }

        if identifiers.contains(.reasoning) {
            tools.append(
                ToolDefinition(
                    name: "reasoning",
                    description: "Enable reasoning capabilities",
                    schema: "{}"
                )
            )
        }

        return tools
    }

    func getAllToolDefinitions() async -> [ToolDefinition] {
        await Task.yield()
        return await getToolDefinitions(for: [.weather, .reasoning])
    }

    func executeTools(toolRequests _: [ToolRequest]) async throws -> [ToolResponse] {
        await Task.yield()
        return []
    }

    func configureSemanticSearch(
        database _: DatabaseProtocol,
        chatId _: UUID,
        fileTitles _: [String]
    ) async throws {
        await Task.yield()
    }
}

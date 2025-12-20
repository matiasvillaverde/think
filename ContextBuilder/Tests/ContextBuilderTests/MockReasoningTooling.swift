import Abstractions
import Foundation

internal actor MockReasoningTooling: Tooling {
    func configureTool(identifiers _: Set<ToolIdentifier>) async throws {
        await Task.yield()
    }

    func clearTools() async {
        await Task.yield()
    }

    func getToolDefinitions(for identifiers: Set<ToolIdentifier>) async -> [ToolDefinition] {
        await Task.yield()
        guard identifiers.contains(.reasoning) else {
            return []
        }

        return [
            ToolDefinition(
                name: "reasoning",
                description: "Enable reasoning capabilities",
                schema: "{}"
            )
        ]
    }

    func getAllToolDefinitions() async -> [ToolDefinition] {
        await Task.yield()
        return [
            ToolDefinition(
                name: "reasoning",
                description: "Enable reasoning capabilities",
                schema: "{}"
            )
        ]
    }

    func executeTools(toolRequests _: [ToolRequest]) async throws -> [ToolResponse] {
        await Task.yield()
        return []
    }

    func cleanupResources() async throws {
        await Task.yield()
    }

    func configureSemanticSearch(
        database _: DatabaseProtocol,
        chatId _: UUID,
        fileTitles _: [String]
    ) async throws {
        await Task.yield()
    }
}

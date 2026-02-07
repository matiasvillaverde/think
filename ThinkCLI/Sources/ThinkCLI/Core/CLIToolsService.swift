import Abstractions
import Foundation

enum CLIToolsService {
    static func list(runtime: CLIRuntime) async throws {
        await runtime.tooling.configureTool(identifiers: Set(ToolIdentifier.allCases))
        let tools = await runtime.tooling.getAllToolDefinitions()
        let summaries = tools.map(ToolDefinitionSummary.init(definition:))
        let fallback = summaries.isEmpty
            ? "No tools."
            : summaries.map { "\($0.name)  \($0.description)" }.joined(separator: "\n")
        runtime.output.emit(summaries, fallback: fallback)
    }

    static func run(
        runtime: CLIRuntime,
        name: String,
        arguments: String
    ) async throws {
        try CLIToolAccessGuard.requireAccess(runtime: runtime, action: "tools run")
        await runtime.tooling.configureTool(identifiers: Set(ToolIdentifier.allCases))
        let request = ToolRequest(name: name, arguments: arguments)
        let responses = await runtime.tooling.executeTools(toolRequests: [request])
        guard let response = responses.first else {
            runtime.output.emit("No response from tool.")
            return
        }
        let fallback: String
        if let error = response.error {
            fallback = "Error: \(error)"
        } else {
            fallback = response.result
        }
        runtime.output.emit(response, fallback: fallback)
    }
}

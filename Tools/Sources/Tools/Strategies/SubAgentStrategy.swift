import Abstractions
import Foundation
import OSLog

/// Strategy for spawning sub-agents
public struct SubAgentStrategy: ToolStrategy {
    private static let logger: Logger = Logger(
        subsystem: "Tools",
        category: "SubAgentStrategy"
    )
    private static let defaultTimeoutSeconds: Int = 300
    private static let maxTimeoutSeconds: Int = 3_600

    private let orchestrator: SubAgentOrchestrating

    /// The tool definition
    public let definition: ToolDefinition = ToolDefinition(
        name: "sub_agent",
        description: "Spawn a sub-agent to perform a focused task",
        schema: """
        {
            "type": "object",
            "properties": {
                "prompt": {
                    "type": "string",
                    "description": "Task for the sub-agent"
                },
                "mode": {
                    "type": "string",
                    "description": "Execution mode for the sub-agent",
                    "enum": ["background", "parallel", "sequential"],
                    "default": "background"
                },
                "timeoutSeconds": {
                    "type": "integer",
                    "description": "Timeout in seconds before cancelling",
                    "minimum": 1,
                    "maximum": 3600,
                    "default": 300
                },
                "tools": {
                    "type": "array",
                    "description": "Tool names available to the sub-agent",
                    "items": { "type": "string" }
                }
            },
            "required": ["prompt"]
        }
        """
    )

    public init(orchestrator: SubAgentOrchestrating) {
        self.orchestrator = orchestrator
    }

    public func execute(request: ToolRequest) async -> ToolResponse {
        Self.logger.debug("Processing sub-agent request: \(request.id)")

        switch BaseToolStrategy.parseArguments(request) {
        case .failure(let error):
            return BaseToolStrategy.errorResponse(request: request, error: error.message)

        case .success(let json):
            return await executeSubAgent(request: request, json: json)
        }
    }

    private func executeSubAgent(request: ToolRequest, json: [String: Any]) async -> ToolResponse {
        guard let prompt = json["prompt"] as? String, !prompt.isEmpty else {
            return BaseToolStrategy.errorResponse(
                request: request,
                error: "Missing required parameter: prompt"
            )
        }

        let mode: SubAgentMode = parseMode(from: json["mode"] as? String)
        let timeoutSeconds: Int = clampTimeout(json["timeoutSeconds"] as? Int)
        let tools: Set<ToolIdentifier> = parseTools(from: json["tools"])

        let subRequest: SubAgentRequest = SubAgentRequest(
            parentMessageId: request.context?.messageId ?? request.id,
            parentChatId: request.context?.chatId ?? UUID(),
            prompt: prompt,
            tools: tools,
            mode: mode,
            timeout: .seconds(timeoutSeconds)
        )

        let requestId: UUID = await orchestrator.spawn(request: subRequest)

        if mode == .sequential {
            do {
                let result: SubAgentResult = try await orchestrator.waitForCompletion(
                    requestId: requestId
                )
                return BaseToolStrategy.successResponse(
                    request: request,
                    result: formatResult(result)
                )
            } catch {
                return BaseToolStrategy.errorResponse(
                    request: request,
                    error: error.localizedDescription
                )
            }
        }

        return BaseToolStrategy.successResponse(
            request: request,
            result: "{\"id\":\"\(requestId.uuidString)\",\"status\":\"spawned\"}"
        )
    }

    private func parseMode(from rawValue: String?) -> SubAgentMode {
        guard let rawValue else {
            return .background
        }
        return SubAgentMode(rawValue: rawValue) ?? .background
    }

    private func clampTimeout(_ timeout: Int?) -> Int {
        let rawValue: Int = timeout ?? Self.defaultTimeoutSeconds
        return min(max(rawValue, 1), Self.maxTimeoutSeconds)
    }

    private func parseTools(from value: Any?) -> Set<ToolIdentifier> {
        guard let rawTools = value as? [String] else {
            return []
        }

        let identifiers: [ToolIdentifier] = rawTools.compactMap { tool in
            ToolIdentifier.from(toolName: tool)
        }
        return Set(identifiers)
    }

    private func formatResult(_ result: SubAgentResult) -> String {
        let payload: [String: Any] = [
            "id": result.id.uuidString,
            "status": result.status.rawValue,
            "output": result.output,
            "toolsUsed": result.toolsUsed,
            "durationMs": result.durationMs
        ]

        if let data = try? JSONSerialization.data(withJSONObject: payload),
            let json = String(data: data, encoding: .utf8) {
            return json
        }

        return result.output
    }
}

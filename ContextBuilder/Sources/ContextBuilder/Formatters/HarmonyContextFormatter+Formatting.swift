import Abstractions
import Foundation

extension HarmonyContextFormatter {
    internal func formatSystemMessage(
        _ content: String,
        date: Date,
        action: Action,
        toolDefinitions: [ToolDefinition],
        allToolDefinitions: [ToolDefinition],
        hasToolResponses: Bool = false,
        knowledgeCutoff: String? = nil,
        reasoningLevel: String? = nil,
        includeDate: Bool = true,
        hasConversationHistory: Bool = false
    ) -> String {
        var components: [String] = []
        components.reserveCapacity(Self.sysMsgParts)

        components.append("<|start|>system<|message|>")
        components.append(cleanSystemContent(content))
        components.append(formatKnowledgeCutoff(content: content, cutoff: knowledgeCutoff))

        if includeDate {
            components.append("\nCurrent date: \(formatDate(date))")
        }

        components.append("\n")
        components.append(formatReasoningSection(action: action, reasoningLevel: reasoningLevel))
        components.append(formatToolsSection(toolDefinitions))

        components.append(
            formatChannelInstructions(
                toolDefinitions: allToolDefinitions,
                action: action,
                reasoningLevel: reasoningLevel,
                hasDeveloperSection: content.contains("DEVELOPER:"),
                hasConversationHistory: hasConversationHistory
            )
        )
        components.append("<|end|>")

        if hasToolResponses {
            components.append("\\")
        }

        return components.joined()
    }

    internal func formatDeveloperMessage(
        _ content: String,
        toolDefinitions: [ToolDefinition] = []
    ) -> String {
        var components: [String] = []
        components.reserveCapacity(Self.devComps)
        components.append("<|start|>developer<|message|>\(content)")

        if !toolDefinitions.isEmpty {
            if !content.isEmpty {
                components.append("\n")
            }
            components.append(formatToolsSection(toolDefinitions))
        }

        components.append("<|end|>")
        return components.joined()
    }

    internal func formatUserMessage(_ content: String) -> String {
        "<|start|>user<|message|>\(content)<|end|>"
    }

    private func cleanSystemContent(_ content: String) -> String {
        if content.contains("DEVELOPER:") {
            let parts: [String] = content.components(separatedBy: "DEVELOPER:")
            return parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return content
    }

    private func formatKnowledgeCutoff(content: String, cutoff: String?) -> String {
        if let cutoff, !content.lowercased().contains("knowledge cutoff") {
            return "\nKnowledge cutoff: \(cutoff)"
        }
        if !content.lowercased().contains("knowledge cutoff") {
            return "\nKnowledge cutoff: 2024-06"
        }
        return ""
    }

    private func formatReasoningSection(action: Action, reasoningLevel: String?) -> String {
        if let level = reasoningLevel {
            return "\nReasoning: \(level)\n"
        }
        if action.isReasoning {
            return "\nReasoning: medium\n"
        }
        return ""
    }

    private func formatToolsSection(_ toolDefinitions: [ToolDefinition]) -> String {
        let nonReasoningTools: [ToolDefinition] = toolDefinitions.filter { $0.name != "reasoning" }
        guard !nonReasoningTools.isEmpty else {
            return ""
        }

        var components: [String] = []
        components.reserveCapacity(nonReasoningTools.count * Self.toolMult + 1)
        components.append("# Tools\n\n")

        for tool in nonReasoningTools {
            let toolDefinition: String = formatToolDefinition(tool)
            let displayName: String = getToolDisplayName(tool.name)
            components.append("## \(displayName)\n\n")
            components.append(toolDefinition)
            components.append("\n\n")
        }

        return components.joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func formatChannelInstructions(
        toolDefinitions: [ToolDefinition],
        action _: Action,
        reasoningLevel _: String?,
        hasDeveloperSection _: Bool,
        hasConversationHistory _: Bool
    ) -> String {
        let nonReasoningTools: [ToolDefinition] = toolDefinitions.filter { $0.name != "reasoning" }
        let channels: String = "analysis, commentary, final"

        var components: [String] = []
        components.reserveCapacity(Self.chanComps)
        components.append(
            "\n# Valid channels: \(channels). Channel must be included for every message."
        )

        if nonReasoningTools.contains(where: { $0.name == "functions" }) {
            components.append(
                "\nCalls to these tools must go to the commentary channel: 'functions'."
            )
        }

        return components.joined()
    }

    private func formatToolDefinition(_ tool: ToolDefinition) -> String {
        switch tool.name {
        case "reasoning":
            return formatReasoningToolDefinition()

        case "browser_search", "browser", "functions", "python_execution", "python":
            if !tool.description.isEmpty {
                return tool.description
            }
            switch tool.name {
            case "browser_search", "browser":
                return formatBrowserToolDefinition()

            case "functions":
                return formatFunctionsToolDefinition()

            case "python_execution", "python":
                return formatPythonToolDefinition()

            default:
                return formatDefaultToolDefinition(tool)
            }

        default:
            return formatDefaultToolDefinition(tool)
        }
    }
}

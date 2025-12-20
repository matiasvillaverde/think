import Abstractions
import Foundation

/// Formatter for Harmony/GPT architectures with channel-based formatting
internal struct HarmonyContextFormatter: ContextFormatter, DateFormatting {
    internal let labels: HarmonyLabels

    // Pre-allocation constants to avoid magic numbers
    private static let buildComps: Int = 4
    private static let sysComps: Int = 2
    private static let convMult: Int = 2
    private static let sysMsgParts: Int = 10
    private static let toolMult: Int = 3
    private static let devComps: Int = 4
    internal static let respMult: Int = 4  // Made internal for use in extensions
    private static let chanComps: Int = 2

    // MARK: - ContextFormatter

    internal func build(context: BuildContext) -> String {
        var components: [String] = []
        // Pre-allocate for typical components
        components.reserveCapacity(Self.buildComps)
        let currentDate: Date = determineDateToUse(context: context)

        // Build system section
        components.append(buildSystemSection(context: context, currentDate: currentDate))

        // Build conversation section
        components.append(buildConversationSection(context: context))

        // Add tool responses if any
        if !context.toolResponses.isEmpty {
            components.append("\n")
            components.append(formatToolResponses(context.toolResponses))
        }

        // Start assistant response if needed
        if shouldStartAssistantResponse(context: context) {
            components.append(formatAssistantStart(context: context))
        }

        return components.joined()
    }

    private func determineDateToUse(context: BuildContext) -> Date {
        if let override = context.contextConfiguration.currentDateOverride {
            // Try different date formats
            let formatter: DateFormatter = DateFormatter()
            formatter.timeZone = TimeZone(identifier: "UTC")

            // Try YYYY-MM-DD format first
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: override) {
                return date
            }
            // Fallback to ISO8601 format
            return ISO8601DateFormatter().date(from: override) ?? Date()
        }
        return Date()
    }

    private func buildSystemSection(context: BuildContext, currentDate: Date) -> String {
        let includeDate: Bool = context.contextConfiguration.includeCurrentDate
        let hasConversationHistory: Bool = !context.contextConfiguration.contextMessages.isEmpty
        let hasDeveloperSection: Bool = context.contextConfiguration.systemInstruction
            .contains("DEVELOPER:")

        // Split tools between system and developer sections
        let toolSplit: (system: [ToolDefinition], developer: [ToolDefinition]) =
            splitToolsForSections(
                tools: context.toolDefinitions,
                hasDeveloperSection: hasDeveloperSection
            )
        let systemTools: [ToolDefinition] = toolSplit.system
        let developerTools: [ToolDefinition] = toolSplit.developer

        var components: [String] = []
        components.reserveCapacity(Self.sysComps)

        components.append(formatSystemMessage(
            context.contextConfiguration.systemInstruction,
            date: currentDate,
            action: context.action,
            toolDefinitions: systemTools,
            allToolDefinitions: context.toolDefinitions,  // Pass all tools for channel instructions
            hasToolResponses: !context.toolResponses.isEmpty,
            knowledgeCutoff: context.contextConfiguration.knowledgeCutoffDate,
            reasoningLevel: context.contextConfiguration.reasoningLevel,
            includeDate: includeDate,
            hasConversationHistory: hasConversationHistory
        ))

        if hasDeveloperSection {
            components.append(buildDeveloperSection(
                systemInstruction: context.contextConfiguration.systemInstruction,
                toolDefinitions: developerTools
            ))
        }

        return components.joined()
    }

    private func buildConversationSection(context: BuildContext) -> String {
        var components: [String] = []
        let messages: [MessageData] = context.contextConfiguration.contextMessages
        // Pre-allocate for user and assistant messages
        components.reserveCapacity(messages.count * Self.convMult)

        for (index, message) in messages.enumerated() {
            let isLastMessage: Bool = index == messages.count - 1

            if let userInput = message.userInput {
                components.append(formatUserMessage(userInput))
            }

            // Use channels if available, otherwise fall back to assistant field
            if !message.channels.isEmpty {
                let isLastCompleteMessage: Bool = isLastMessage && message.userInput != nil
                let formatted: String = formatAssistantMessageFromChannels(
                    message,
                    isLast: isLastCompleteMessage
                )
                components.append(formatted)
            }
            // No channels - skip
        }

        return components.joined()
    }

    private func shouldStartAssistantResponse(context: BuildContext) -> Bool {
        let contextMessages: [MessageData] = context.contextConfiguration.contextMessages
        if let lastMessage = contextMessages.last {
            return lastMessage.userInput != nil && lastMessage.channels.isEmpty
        }
        // If no messages, start assistant response
        return true
    }

    private func formatAssistantStart(context: BuildContext) -> String {
        // Add newline only if we have actual tool definitions (not just reasoning)
        let hasNonReasoningTools: Bool = context.toolDefinitions.contains { $0.name != "reasoning" }
        if hasNonReasoningTools {
            return "<|start|>assistant\n"
        }
        return "<|start|>assistant"
    }

    // MARK: - Private Formatting Methods

    private func formatSystemMessage(
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
        // Pre-allocate for typical message parts
        components.reserveCapacity(Self.sysMsgParts)

        components.append("<|start|>system<|message|>")
        components.append(cleanSystemContent(content))
        components.append(formatKnowledgeCutoff(content: content, cutoff: knowledgeCutoff))

        if includeDate {
            components.append("\nCurrent date: \(formatDate(date))")
        }

        components.append("\n")
        components.append(formatReasoningSection(action: action, reasoningLevel: reasoningLevel))

        // Always add tools to system message (they've been pre-filtered)
        components.append(formatToolsSection(toolDefinitions))

        components.append(formatChannelInstructions(
            toolDefinitions: allToolDefinitions,  // Use all tools for channel instructions
            action: action,
            reasoningLevel: reasoningLevel,
            hasDeveloperSection: content.contains("DEVELOPER:"),
            hasConversationHistory: hasConversationHistory
        ))
        components.append("<|end|>")

        if hasToolResponses {
            components.append("\\")
        }

        return components.joined()
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
        // Pre-allocate for tool sections
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

        // Per OpenAI Harmony documentation: always include all three channels
        let channels: String = "analysis, commentary, final"

        var components: [String] = []
        components.reserveCapacity(Self.chanComps)
        components.append(
            "\n# Valid channels: \(channels). Channel must be included for every message."
        )

        // Add tool channel constraints if we have functions
        if nonReasoningTools.contains(where: { $0.name == "functions" }) {
            components.append(
                "\nCalls to these tools must go to the commentary channel: 'functions'."
            )
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

        // Add tools section if there are tool definitions
        if !toolDefinitions.isEmpty {
            // Only add newline if content is not empty
            if !content.isEmpty {
                components.append("\n")
            }
            components.append(formatToolsSection(toolDefinitions))
        }

        components.append("<|end|>")
        return components.joined()
    }

    private func formatUserMessage(_ content: String) -> String {
        "<|start|>user<|message|>\(content)<|end|>"
    }

    private func formatToolDefinition(_ tool: ToolDefinition) -> String {
        // For special tools that have specific formatting in description
        switch tool.name {
        case "reasoning":
            return formatReasoningToolDefinition()

        case "browser_search", "browser", "functions", "python_execution", "python":
            // Use the description field which contains the formatted definition
            if !tool.description.isEmpty {
                return tool.description
            }
            // Fallback to hardcoded if description is empty
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

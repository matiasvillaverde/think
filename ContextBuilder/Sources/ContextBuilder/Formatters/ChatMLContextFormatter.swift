import Abstractions
import Foundation

/// Formatter for ChatML-based architectures using protocol composition
internal struct ChatMLContextFormatter: ContextFormatter, DateFormatting, ToolFormatting,
    MessageFormatting, MemoryFormatting, SkillFormatting, WorkspaceFormatting {
    internal let labels: ChatMLLabels
    private static let (buildComps, convMult): (Int, Int) = (4, 3) // Pre-allocation constants

    // MARK: - ContextFormatter

    internal func build(context: BuildContext) -> String {
        var components: [String] = []
        components.reserveCapacity(Self.buildComps)

        // Build system section
        components.append(buildSystemSection(context: context))

        // Build conversation section
        components.append(buildConversationSection(context: context))

        // Add tool responses if any
        if !context.toolResponses.isEmpty {
            components.append(formatToolResponses(context.toolResponses))
        }

        // Start assistant response if needed
        if shouldStartAssistantResponse(context: context) {
            components.append(labels.assistantLabel)
        }

        return components.joined()
    }

    private func buildSystemSection(context: BuildContext) -> String {
        // Determine date to use
        let currentDate: Date = determineDateToUse(context: context)

        // Build system instruction with memory context if available
        var systemContent: String = context.contextConfiguration.systemInstruction
        if let workspaceContext: WorkspaceContext = context.contextConfiguration.workspaceContext {
            let workspaceSection: String = formatWorkspaceContext(workspaceContext)
            if !workspaceSection.isEmpty {
                systemContent += workspaceSection
            }
        }
        if let memoryContext: MemoryContext = context.contextConfiguration.memoryContext {
            let memorySection: String = formatMemoryContext(memoryContext)
            if !memorySection.isEmpty {
                systemContent += memorySection
            }
        }
        if let skillContext: SkillContext = context.contextConfiguration.skillContext {
            let skillSection: String = formatSkillContext(
                skillContext,
                actionTools: context.action.tools
            )
            if !skillSection.isEmpty {
                systemContent += skillSection
            }
        }

        // Add system message with date and knowledge cutoff
        let includeDate: Bool = context.contextConfiguration.includeCurrentDate
        var result: String = formatSystemMessage(
            systemContent,
            date: currentDate,
            knowledgeCutoff: context.contextConfiguration.knowledgeCutoffDate,
            includeDate: includeDate
        )

        // Add tool definitions if present (excluding reasoning - not used by ChatML)
        let nonReasoningTools: [ToolDefinition] = context.toolDefinitions
            .filter { $0.name != "reasoning" }
        let toolDefs: String = formatTools(nonReasoningTools)
        if !toolDefs.isEmpty {
            // Append to system message before closing, with blank line before tools
            if let range = result.range(of: labels.endLabel, options: .backwards) {
                result.insert(contentsOf: toolDefs, at: range.lowerBound)
            } else {
                result += toolDefs
            }
        }

        return result
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

    private func buildConversationSection(context: BuildContext) -> String {
        var components: [String] = []
        let messages: [MessageData] = context.contextConfiguration.contextMessages
        components.reserveCapacity(messages.count * Self.convMult)

        for message in messages {
            if let userInput = message.userInput {
                components.append(formatUserMessage(userInput))
            }

            // Use channels if available, otherwise fall back to assistant field
            if !message.channels.isEmpty {
                let formatted: String = formatAssistantMessageFromChannels(message)
                if !formatted.isEmpty {
                    components.append(labels.assistantLabel)
                    components.append(formatted)
                    components.append(labels.endLabel)
                    components.append("\n")
                }
            }
            // No channels and no assistant field - skip
        }

        return components.joined()
    }

    private func shouldStartAssistantResponse(context: BuildContext) -> Bool {
        if let lastMessage = context.contextConfiguration.contextMessages.last {
            // Start assistant response if:
            // 1. There's a user input but no assistant response, OR
            // 2. The assistant made tool calls and we have tool responses (need to continue)
            let hasToolCallsAndResponses: Bool = !lastMessage.toolCalls.isEmpty &&
                !context.toolResponses.isEmpty
            return (lastMessage.userInput != nil && lastMessage.channels.isEmpty) ||
                hasToolCallsAndResponses
        }
        // If no messages, start assistant response
        return true
    }
}

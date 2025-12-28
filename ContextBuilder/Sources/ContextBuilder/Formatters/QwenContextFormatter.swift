import Abstractions
import Foundation

/// Formatter for Qwen architecture with thinking command support
internal struct QwenContextFormatter:
    ContextFormatter,
    DateFormatting,
    ToolFormatting,
    MessageFormatting,
    MemoryFormatting,
    SkillFormatting,
    WorkspaceFormatting {
    internal let labels: QwenLabels

    // MARK: - ContextFormatter

    internal func build(context: BuildContext) -> String {
        var result: String = ""

        let currentDate: Date = determineDateToUse(context: context)
        let systemContent: String = buildSystemContent(context: context)

        let includeDate: Bool = context.contextConfiguration.includeCurrentDate
        result += formatSystemMessageWithThinking(
            systemContent,
            date: currentDate,
            action: context.action,
            toolDefinitions: context.toolDefinitions,
            knowledgeCutoff: context.contextConfiguration.knowledgeCutoffDate,
            includeDate: includeDate
        )

        result += buildConversationHistory(
            context: context,
            isReasoning: context.action.isReasoning,
            hasToolResponses: !context.toolResponses.isEmpty
        )

        if !context.toolResponses.isEmpty {
            result += formatToolResponses(context.toolResponses)
            result += labels.assistantLabel
        } else if shouldStartAssistantResponse(context: context) {
            result += labels.assistantLabel.trimmingCharacters(in: .newlines)
        }

        return result
    }

    private func buildSystemContent(context: BuildContext) -> String {
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
        return systemContent
    }

    private func buildConversationHistory(
        context: BuildContext,
        isReasoning: Bool,
        hasToolResponses: Bool
    ) -> String {
        var result: String = ""
        let messages: [MessageData] = context.contextConfiguration.contextMessages

        for (index, message) in messages.enumerated() {
            let isLastMessage: Bool = index == messages.count - 1

            if let userInput = message.userInput {
                let modifiedUserInput: String = addThinkingCommandIfNeeded(
                    to: userInput,
                    isLastMessage: isLastMessage,
                    isReasoning: isReasoning
                )
                result += formatUserMessage(modifiedUserInput)
            }

            if !message.channels.isEmpty {
                let isLastCompleteMessage: Bool = isLastMessage &&
                    message.userInput != nil &&
                    !hasToolResponses
                let formatted: String = formatAssistantMessageFromChannels(message)
                if !formatted.isEmpty {
                    result += formatAssistantMessage(formatted, isLast: isLastCompleteMessage)
                }
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

    private func shouldStartAssistantResponse(context: BuildContext) -> Bool {
        if let lastMessage = context.contextConfiguration.contextMessages.last {
            return lastMessage.userInput != nil && lastMessage.channels.isEmpty
        }
        // If no messages, start assistant response
        return true
    }

    private func addThinkingCommandIfNeeded(
        to userInput: String,
        isLastMessage: Bool,
        isReasoning: Bool
    ) -> String {
        guard isLastMessage else {
            return userInput
        }

        if isReasoning {
            // Add /think command if reasoning is enabled
            if let thinkCommand = labels.thinkCommand,
                !userInput.contains(thinkCommand) {
                return userInput + " " + thinkCommand
            }
        } else {
            // Add /no_think command if reasoning is NOT enabled
            if let noThinkCommand = labels.noThinkCommand,
                !userInput.contains(noThinkCommand) {
                return userInput + " " + noThinkCommand
            }
        }

        return userInput
    }

    // MARK: - MessageFormatting

    internal func formatSystemMessage(_ content: String, date: Date) -> String {
        formatSystemMessage(content, date: date, knowledgeCutoff: nil, includeDate: true)
    }

    internal func formatSystemMessage(
        _ content: String,
        date: Date,
        knowledgeCutoff: String?,
        includeDate: Bool = true
    ) -> String {
        var message: String = labels.systemLabel
        message += content

        // Only add knowledge cutoff if it's provided and not already in the content
        if let knowledgeCutoff,
            !content.contains("Knowledge cutoff:") {
            message += "\nKnowledge cutoff: \(knowledgeCutoff)"
        }

        if includeDate {
            message += "\n\nToday's date: \(formatDate(date))"
            message += "\n"
        }
        message += labels.endLabel
        message += "\n"
        return message
    }

    private func formatSystemMessageWithThinking(
        _ content: String,
        date: Date,
        action _: Action,
        toolDefinitions: [ToolDefinition],
        knowledgeCutoff: String? = nil,
        includeDate: Bool = true
    ) -> String {
        var message: String = labels.systemLabel
        message += content

        // Only add knowledge cutoff if it's provided and not already in the content
        if let knowledgeCutoff,
            !content.contains("Knowledge cutoff:") {
            message += "\nKnowledge cutoff: \(knowledgeCutoff)"
        }

        if includeDate {
            message += "\n\nToday's date: \(formatDate(date))"
            message += "\n"
        }

        // Add tool definitions if present (excluding reasoning which is handled via /think command)
        let nonReasoningTools: [ToolDefinition] = toolDefinitions.filter { $0.name != "reasoning" }
        if !nonReasoningTools.isEmpty {
            let toolDefs: String = formatTools(nonReasoningTools)
            if !toolDefs.isEmpty {
                message += "\n\n"
                message += toolDefs
            }
        }

        // Don't add thinking command to system message - it's added to user messages

        message += labels.endLabel
        message += "\n"
        return message
    }

    internal func formatUserMessage(_ content: String) -> String {
        var message: String = labels.userLabel
        message += content
        message += labels.endLabel
        message += "\n"
        return message
    }

    internal func formatAssistantMessage(_ content: String) -> String {
        formatAssistantMessage(content, isLast: false)
    }

    internal func formatAssistantMessage(_ content: String, isLast: Bool) -> String {
        var message: String = labels.assistantLabel
        message += content
        message += labels.endLabel
        if !isLast {
            message += "\n"
        }
        return message
    }

    /// Formats assistant message from channels
    internal func formatAssistantMessageFromChannels(_ messageData: MessageData) -> String {
        guard !messageData.channels.isEmpty || !messageData.toolCalls.isEmpty else {
            return ""
        }

        // Use complex ordering when tool calls are present
        if !messageData.toolCalls.isEmpty {
            return formatWithOrderedItems(messageData)
        }

        // Simple channel-only formatting
        var result: String = ""
        let sortedChannels: [MessageChannel] = messageData.channels.sorted { $0.order < $1.order }

        for channel in sortedChannels {
            switch channel.type {
            case .commentary:
                result += labels.commentaryStartLabel
                result += "\n"
                result += channel.content
                result += "\n"
                result += labels.commentaryEndLabel
                result += "\n"

            case .final:
                result += channel.content
            }
        }

        return result
    }
}

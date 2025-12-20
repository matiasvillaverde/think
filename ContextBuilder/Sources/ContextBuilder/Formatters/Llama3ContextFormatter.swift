import Abstractions
import Foundation

/// Formatter for Llama3 architecture with Python environment support
internal struct Llama3ContextFormatter: ContextFormatter, DateFormatting {
    internal let labels: Llama3Labels

    // MARK: - ContextFormatter

    internal func build(context: BuildContext) -> String {
        var result: String = "<|begin_of_text|>"

        // Determine date to use
        let currentDate: Date = determineDateToUse(context: context)

        // Add system message
        let includeDate: Bool = context.contextConfiguration.includeCurrentDate
        result += formatSystemMessage(
            context.contextConfiguration.systemInstruction,
            date: currentDate,
            toolDefinitions: context.toolDefinitions,
            knowledgeCutoff: context.contextConfiguration.knowledgeCutoffDate,
            includeDate: includeDate
        )

        // Add conversation history
        let messages: [MessageData] = context.contextConfiguration.contextMessages
        for (index, message) in messages.enumerated() {
            let isLastMessage: Bool = index == messages.count - 1

            if let userInput = message.userInput {
                result += formatUserMessage(userInput)
            }

            // Use channels if available, otherwise fall back to assistant field
            if !message.channels.isEmpty {
                let isLastCompleteMessage: Bool = isLastMessage && message.userInput != nil
                let formatted: String = formatAssistantMessageFromChannels(
                    message,
                    isLast: isLastCompleteMessage
                )
                result += formatted
            }
            // No channels - skip
        }

        // Add tool responses if any
        if !context.toolResponses.isEmpty {
            result += formatToolResponses(context.toolResponses)
        }

        // Start assistant response only if the last message is incomplete
        if shouldStartAssistantResponse(context: context) {
            result += labels.assistantLabel.trimmingCharacters(in: .newlines)
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
        // Only start assistant response if the last message is incomplete
        if let lastMessage = context.contextConfiguration.contextMessages.last {
            return lastMessage.userInput != nil && lastMessage.channels.isEmpty
        }
        // If no messages, start assistant response
        return true
    }

    // MARK: - Private Formatting Methods

    private func formatSystemMessage(
        _ content: String,
        date: Date,
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

        // Add tool definitions if present (excluding reasoning - not used by Llama3)
        let nonReasoningTools: [ToolDefinition] = toolDefinitions
            .filter { $0.name != "reasoning" }
        if !nonReasoningTools.isEmpty {
            message += "\n\nAvailable tools:\n"
            for tool in nonReasoningTools {
                message += "- \(tool.name): \(tool.description)\n"
            }
        }

        if includeDate {
            message += "\n\nToday's date: \(formatDate(date))"
        }
        message += labels.endLabel
        return message
    }

    private func formatUserMessage(_ content: String) -> String {
        var message: String = labels.userLabel
        message += content
        message += labels.endLabel
        return message
    }

    private func formatAssistantMessage(_ content: String) -> String {
        formatAssistantMessage(content, isLast: false)
    }

    private func formatAssistantMessage(_ content: String, isLast: Bool) -> String {
        var message: String = labels.assistantLabel
        message += content
        message += labels.endLabel
        if !isLast {
            message += "\n"
        }
        return message
    }

    /// Formats assistant message from channels
    private func formatAssistantMessageFromChannels(
        _ messageData: MessageData,
        isLast: Bool
    ) -> String {
        guard !messageData.channels.isEmpty else {
            return ""
        }

        var result: String = labels.assistantLabel
        let sortedChannels: [MessageChannel] = messageData.channels.sorted { $0.order < $1.order }

        for channel in sortedChannels {
            switch channel.type {
            case .commentary:
                // Llama3 doesn't have specific commentary labels, include as plain text
                result += channel.content
                result += "\n\n"

            case .final:
                result += channel.content
            }
        }

        result += labels.endLabel
        if !isLast {
            result += "\n"
        }

        return result
    }

    private func formatToolResponses(_ responses: [ToolResponse]) -> String {
        var formatted: String = ""
        for response in responses {
            if let ipythonLabel = labels.ipythonLabel {
                formatted += labels.toolLabel
                formatted += ipythonLabel
                formatted += response.result
                formatted += labels.toolEndLabel
            } else {
                // Fallback to user message format
                formatted += labels.userLabel
                formatted += labels.toolResponseLabel
                formatted += "\n"
                formatted += response.result
                formatted += "\n"
                formatted += labels.toolResponseEndLabel
                formatted += labels.endLabel
            }
        }
        return formatted
    }
}

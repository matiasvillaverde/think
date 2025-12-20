import Abstractions
import Foundation

/// Formatter for Mistral architecture with [INST] format
internal struct MistralContextFormatter: ContextFormatter, DateFormatting {
    internal let labels: MistralLabels

    // MARK: - ContextFormatter

    internal func build(context: BuildContext) -> String {
        var result: String = "<s>"

        // Determine date to use
        let currentDate: Date = determineDateToUse(context: context)
        let includeDate: Bool = context.contextConfiguration.includeCurrentDate
        let knowledgeCutoff: String? = context.contextConfiguration.knowledgeCutoffDate

        // Mistral uses a different format - system is part of first instruction
        var isFirstMessage: Bool = true
        let messages: [MessageData] = context.contextConfiguration.contextMessages

        // Build instruction blocks
        for (index, message) in messages.enumerated() {
            let isLastMessage: Bool = index == messages.count - 1

            if isFirstMessage, let userInput = message.userInput {
                // Include system prompt with first user message
                result += formatFirstInstruction(
                    systemPrompt: context.contextConfiguration.systemInstruction,
                    userMessage: userInput,
                    date: currentDate,
                    toolDefinitions: context.toolDefinitions,
                    knowledgeCutoff: knowledgeCutoff,
                    includeDate: includeDate
                )
                isFirstMessage = false
            } else if let userInput = message.userInput {
                result += formatInstruction(userInput)
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

        // If no history, just add system and wait for user
        if context.contextConfiguration.contextMessages.isEmpty {
            result += formatFirstInstruction(
                systemPrompt: context.contextConfiguration.systemInstruction,
                userMessage: "",
                date: currentDate,
                toolDefinitions: context.toolDefinitions,
                knowledgeCutoff: knowledgeCutoff,
                includeDate: includeDate
            )
        }

        // Add tool responses if any
        if !context.toolResponses.isEmpty {
            result += formatToolResponses(context.toolResponses)
        }

        // Mistral format doesn't need anything added - [/INST] already indicates assistant start

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

    // MARK: - Private Formatting Methods

    private func formatFirstInstruction(
        systemPrompt: String,
        userMessage: String,
        date: Date,
        toolDefinitions: [ToolDefinition],
        knowledgeCutoff: String? = nil,
        includeDate: Bool = true
    ) -> String {
        var instruction: String = labels.userLabel
        instruction += systemPrompt

        // Only add knowledge cutoff if it's provided and not already in the content
        if let knowledgeCutoff,
            !systemPrompt.contains("Knowledge cutoff:") {
            instruction += "\nKnowledge cutoff: \(knowledgeCutoff)"
        }

        // Add tool definitions if present (excluding reasoning - not used by Mistral)
        let nonReasoningTools: [ToolDefinition] = toolDefinitions
            .filter { $0.name != "reasoning" }
        if !nonReasoningTools.isEmpty {
            instruction += "\nAvailable tools:\n"
            for tool in nonReasoningTools {
                instruction += "- \(tool.name): \(tool.description)\n"
            }
        }

        if includeDate {
            instruction += "\n\nToday's date: \(formatDate(date))"
        }

        if !userMessage.isEmpty {
            if !systemPrompt.isEmpty {
                instruction += "\n\n"
            }
            instruction += userMessage
        }

        instruction += labels.endLabel
        return instruction
    }

    private func formatInstruction(_ content: String) -> String {
        "\(labels.userLabel)\(content)\(labels.endLabel)"
    }

    private func formatResponse(_ content: String) -> String {
        formatResponse(content, isLast: false)
    }

    private func formatResponse(_ content: String, isLast _: Bool) -> String {
        // Add </s> after all complete assistant responses
        content + "</s>"
    }

    private func formatToolResponses(_ responses: [ToolResponse]) -> String {
        var formatted: String = ""
        for response in responses {
            // Mistral treats tool responses as part of conversation
            formatted += labels.userLabel
            formatted += " "
            formatted += labels.toolResponseLabel
            formatted += "\n"
            formatted += response.result
            formatted += "\n"
            formatted += labels.toolResponseEndLabel
            formatted += " "
            formatted += labels.assistantLabel
        }
        return formatted
    }

    /// Formats assistant message from channels  
    private func formatAssistantMessageFromChannels(
        _ messageData: MessageData,
        isLast: Bool
    ) -> String {
        guard !messageData.channels.isEmpty else {
            return ""
        }

        var result: String = " "
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

        if !isLast {
            result += "</s>"
        } else {
            result += " "
            result += labels.assistantLabel
        }

        return result
    }
}

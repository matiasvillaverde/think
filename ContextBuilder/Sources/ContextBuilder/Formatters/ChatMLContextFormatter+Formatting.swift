import Abstractions
import Foundation

extension ChatMLContextFormatter {
    // MARK: - MessageFormatting

    internal func formatSystemMessage(_ content: String, date: Date) -> String {
        formatSystemMessage(content, date: date, knowledgeCutoff: nil)
    }

    internal func formatSystemMessage(
        _ content: String,
        date: Date,
        knowledgeCutoff: String?,
        includeDate: Bool = true
    ) -> String {
        var message: String = labels.systemLabel
        message += content

        // Only add knowledge cutoff if it's not already in the content
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

    internal func formatToolResponses(_ responses: [ToolResponse]) -> String {
        var formatted: String = ""
        for response in responses {
            formatted += labels.toolLabel  // Use tool label instead of user label
            formatted += labels.toolResponseLabel
            formatted += "\n"
            let contentString: String = formatToolResponseContent(response.result)
            formatted += "{\"name\": \"\(response.toolName)\", \"content\": \(contentString)}"
            formatted += "\n"
            formatted += labels.toolResponseEndLabel
            formatted += labels.endLabel
            formatted += "\n"
        }
        return formatted
    }

    // MARK: - ToolFormatting Override

    internal func formatTools(_ definitions: [ToolDefinition]) -> String {
        guard !definitions.isEmpty else {
            return ""
        }

        let nonReasoningTools: [ToolDefinition] = definitions.filter { $0.name != "reasoning" }
        guard !nonReasoningTools.isEmpty else {
            return ""
        }

        var result: String = ""

        // Section title
        result += "\n\(labels.toolSectionTitle)\n"

        // Introduction
        result += "\(labels.toolIntroduction)\n\n"

        // Tools definitions
        result += "<tools>\n"

        let toolsJSON: [String] = nonReasoningTools.map { tool in
            // Compact the JSON schema by parsing and re-serializing without spaces
            let compactSchema: String
            if let data = tool.schema.data(using: .utf8),
                let jsonObject = try? JSONSerialization.jsonObject(with: data),
                let compactData = try? JSONSerialization.data(
                    withJSONObject: jsonObject,
                    options: []
                ),
                let compact = String(data: compactData, encoding: .utf8) {
                compactSchema = compact
            } else {
                // Fallback: remove all whitespace
                compactSchema = tool.schema
                    .replacingOccurrences(
                        of: "\\s+",
                        with: "",
                        options: .regularExpression
                    )
            }

            let functionDef: String = "{\"name\":\"\(tool.name)\"," +
                "\"description\":\"\(tool.description)\",\"parameters\":\(compactSchema)}"
            return "{\"type\":\"function\",\"function\":\(functionDef)}"
        }

        if labels.useArrayFormat {
            result += "[\(toolsJSON.joined(separator: ","))]"
        } else {
            result += toolsJSON.joined(separator: "\n")
        }

        result += "\n</tools>\n\n"

        // Call instructions
        result += "\(labels.toolCallInstructions)\n\n"

        // Important instructions
        result += "# Important Instructions\n"
        for (index, instruction) in labels.toolImportantInstructions.enumerated() {
            result += "- \(instruction)"
            if index < labels.toolImportantInstructions.count - 1 {
                result += "\n"
            }
        }

        return result
    }

    /// Formats assistant message with optional tool calls
    private func formatAssistantMessageWithToolCalls(
        content: String,
        toolCalls: [ToolCall]
    ) -> String {
        var message: String = labels.assistantLabel
        message += content

        // Add tool calls if present
        if !toolCalls.isEmpty {
            for toolCall in toolCalls {
                message += "\n<tool_call>\n"
                message += "{\"name\": \"\(toolCall.name)\", \"arguments\": \(toolCall.arguments)}"
                message += "\n</tool_call>"
            }
        }

        message += labels.endLabel
        message += "\n"
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

    /// Safely parses JSON string, returning parsed object or original string on failure
    private func parseJSONSafely(_ jsonString: String) -> Any {
        if let data = jsonString.data(using: .utf8),
            let parsed = try? JSONSerialization.jsonObject(with: data) {
            return parsed
        }
        return jsonString  // Return as string if parsing fails
    }
}

import Abstractions
import Foundation

/// Formatter for ChatML-based architectures using protocol composition
internal struct ChatMLContextFormatter: ContextFormatter, DateFormatting, ToolFormatting,
    MessageFormatting {
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

        // Add system message with date and knowledge cutoff
        let includeDate: Bool = context.contextConfiguration.includeCurrentDate
        var result: String = formatSystemMessage(
            context.contextConfiguration.systemInstruction,
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
                do {
                    let formatted: String = try formatAssistantMessageFromChannels(message)
                    if !formatted.isEmpty {
                        components.append(labels.assistantLabel)
                        components.append(formatted)
                        components.append(labels.endLabel)
                        components.append("\n")
                    }
                } catch {
                    // Channel formatting failed, skip this message
                    // Silently skip - channels are empty
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

            // Preserve original JSON string formatting to maintain field order
            let contentString: String
            if response.result.isEmpty {
                // Empty result - use empty string to ensure valid JSON
                contentString = "\"\""
            } else if let data = response.result.data(using: .utf8),
                (try? JSONSerialization.jsonObject(with: data)) != nil {
                // Valid JSON - preserve original format but fix URL escaping only
                contentString = response.result
                    .replacingOccurrences(of: "\\/", with: "/")  // Fix URL escaping
            } else {
                // Invalid JSON - wrap as string
                let escaped: String = response.result
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                    .replacingOccurrences(of: "\n", with: "\\n")
                    .replacingOccurrences(of: "\r", with: "\\r")
                    .replacingOccurrences(of: "\t", with: "\\t")
                contentString = "\"\(escaped)\""
            }

            // Manually construct to ensure key order and spacing
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
    internal func formatAssistantMessageFromChannels(_ messageData: MessageData) throws -> String {
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

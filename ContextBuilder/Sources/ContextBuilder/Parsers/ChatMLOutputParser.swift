import Abstractions
import Foundation
import OSLog

/// Parser for ChatML-based outputs with safe streaming support
internal struct ChatMLOutputParser: OutputParser {
    private static let logger: Logger = Logger(
        subsystem: "ContextBuilder",
        category: "ChatMLParser"
    )
    private static let contentPrefixLength: Int = 50

    internal let labels: any ChatMLBaseLabels
    private let cache: ProcessingCache

    internal init(labels: any ChatMLBaseLabels, cache: ProcessingCache) {
        self.labels = labels
        self.cache = cache
    }

    // MARK: - Main Parse Method

    internal func parse(_ output: String) async -> [ChannelMessage] {
        var channels: [ChannelMessage] = []
        var order: Int = 0

        // Extract analysis and commentary channels
        order = await extractTaggedChannels(
            from: output,
            to: &channels,
            startOrder: order
        )

        // Extract tool calls
        let toolCalls: [ToolRequest] = extractToolCalls(from: output)
        for toolCall in toolCalls {
            let recipient: String = "functions.\(toolCall.name)"
            let signature: String = createChannelSignature(
                type: .tool,
                order: order,
                toolCall.arguments,
                recipient: recipient
            )
            let channelId: UUID = await cache.getOrCreateChannelId(for: signature)

            channels.append(ChannelMessage(
                id: channelId,
                type: .tool,
                content: toolCall.arguments,
                order: order,
                recipient: recipient,
                toolRequest: toolCall
            ))
            order += 1
        }

        // Extract final content (everything else)
        let finalContent: String = extractFinalContent(from: output)
        if !finalContent.isEmpty {
            let signature: String = createChannelSignature(
                type: .final,
                order: order,
                finalContent,
                recipient: nil
            )
            let channelId: UUID = await cache.getOrCreateChannelId(for: signature)

            channels.append(ChannelMessage(
                id: channelId,
                type: .final,
                content: finalContent,
                order: order,
                recipient: nil,
                toolRequest: nil
            ))
        }

        return channels
    }

    // swiftlint:disable:next function_body_length
    private func extractTaggedChannels(
        from output: String,
        to channels: inout [ChannelMessage],
        startOrder: Int
    ) async -> Int {
        var order: Int = startOrder

        // Extract analysis (thinking) content - streaming progressively
        if let result = extractProgressiveTaggedContent(
            from: output,
            startTag: labels.thinkingStartLabel,
            endTag: labels.thinkingEndLabel
        ) {
            // For complete tags, check if content is empty after trimming
            // For incomplete tags (streaming), always create channel if there's any content
            let trimmedForCheck: String = result.content.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            // Both streaming and complete use same rule:
            // Only create channel if there's non-whitespace content
            let shouldCreateChannel: Bool = !trimmedForCheck.isEmpty

            if shouldCreateChannel {
                let signature: String = createChannelSignature(
                    type: .analysis,
                    order: order,
                    result.content,
                    recipient: nil
                )
                let channelId: UUID = await cache.getOrCreateChannelId(for: signature)
                channels.append(ChannelMessage(
                    id: channelId,
                    type: .analysis,
                    content: result.content,
                    order: order,
                    recipient: nil,
                    toolRequest: nil
                ))
                order += 1
            }
        }

        // Extract commentary content - streaming progressively
        if let result = extractProgressiveTaggedContent(
            from: output,
            startTag: labels.commentaryStartLabel,
            endTag: labels.commentaryEndLabel
        ) {
            let trimmedForCheck: String = result.content.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            let shouldCreateChannel: Bool = !trimmedForCheck.isEmpty

            if shouldCreateChannel {
                let signature: String = createChannelSignature(
                    type: .commentary,
                    order: order,
                    result.content,
                    recipient: nil
                )
                let channelId: UUID = await cache.getOrCreateChannelId(for: signature)
                channels.append(ChannelMessage(
                    id: channelId,
                    type: .commentary,
                    content: result.content,
                    order: order,
                    recipient: nil,
                    toolRequest: nil
                ))
                order += 1
            }
        }

        return order
    }

    // MARK: - Content Extraction Methods

    /// Extracts tool calls from the output
    private func extractToolCalls(from output: String) -> [ToolRequest] {
        let pattern: String = "<tool_call>(.*?)</tool_call>"

        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: .dotMatchesLineSeparators
        ) else {
            return []
        }

        let matches: [NSTextCheckingResult] = regex.matches(
            in: output,
            range: NSRange(output.startIndex..., in: output)
        )

        return matches.flatMap { match in
            guard let range = Range(match.range(at: 1), in: output) else {
                return [ToolRequest]()
            }
            let jsonString: String = String(output[range])
            return parseToolCallPayload(jsonString)
        }
    }

    /// Extracts final content by removing all special tags and markers
    private func extractFinalContent(from output: String) -> String {
        var workingContent: String = output

        // First handle any partial tags at the end of the input (O(1) check)
        if let excludeCount = hasIncompleteTagSuffix(workingContent) {
            let endIndex: String.Index = workingContent.index(
                workingContent.endIndex,
                offsetBy: -excludeCount
            )
            workingContent = String(workingContent[..<endIndex])
        }

        // Remove complete AND incomplete thinking/commentary blocks
        // (they're being streamed to their own channels)
        workingContent = removeTaggedBlock(
            from: workingContent,
            startTag: labels.thinkingStartLabel,
            endTag: labels.thinkingEndLabel
        )

        workingContent = removeTaggedBlock(
            from: workingContent,
            startTag: labels.commentaryStartLabel,
            endTag: labels.commentaryEndLabel
        )

        // Check for incomplete tool call block (tools still require complete blocks)
        if let toolStart = workingContent.range(of: "<tool_call>") {
            let searchRange: Range<String.Index> = toolStart.upperBound..<workingContent.endIndex
            if workingContent.range(of: "</tool_call>", range: searchRange) == nil {
                // Incomplete tool block - exclude everything from the start tag
                workingContent = String(workingContent[..<toolStart.lowerBound])
            }
        }

        // Remove complete tool call blocks
        workingContent = removeCompleteToolCalls(from: workingContent)

        // Remove end label if present
        let finalContent: String = removeEndLabel(from: workingContent)

        return finalContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Content Removal Methods

    /// Removes complete tool call blocks
    private func removeCompleteToolCalls(from text: String) -> String {
        let pattern: String = "<tool_call>.*?</tool_call>"
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.dotMatchesLineSeparators]
        ) else {
            Self.logger.error("Failed to create regex for tool call removal")
            return text
        }

        let range: NSRange = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(
            in: text,
            range: range,
            withTemplate: ""
        )
    }

    /// Create a stable signature for a channel that survives content streaming
    private func createChannelSignature(
        type: ChannelMessage.ChannelType,
        order: Int,
        _: String,
        recipient: String?
    ) -> String {
        // For streaming consistency, we use type + order + recipient as the stable signature
        // Content is deliberately excluded since it grows during streaming
        let recipientPart: String = recipient ?? ""
        return "\(type.rawValue):\(order):\(recipientPart)"
    }
}

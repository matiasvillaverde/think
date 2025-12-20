import Abstractions
import Foundation
import OSLog

// swiftlint:disable:next type_body_length
internal struct HarmonyOutputParser: OutputParser {
    private static let logger: Logger = Logger(
        subsystem: "ContextBuilder",
        category: "HarmonyParser"
    )
    private static let contentPrefixLength: Int = 50

    private enum RegexGroup {
        static let channelName: Int = 1
        static let channelContent: Int = 2
        static let recipientGroup: Int = 3
        static let recipientMatch: Int = 1
    }

    internal let labels: HarmonyLabels
    private let cache: ProcessingCache

    internal init(labels: HarmonyLabels, cache: ProcessingCache) {
        self.labels = labels
        self.cache = cache
    }

    internal func parse(_ output: String) async -> [ChannelMessage] {
        // First try to parse complete channels
        var channels: [ChannelMessage] = await parseCompleteChannels(from: output)

        // Then check for any partial/incomplete channels
        if let partialChannel = await parsePartialChannel(from: output, afterChannels: channels) {
            channels.append(partialChannel)
        }

        // If no channels found and there's content, treat it as plain text final channel
        if channels.isEmpty, !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let content: String = output.trimmingCharacters(in: .whitespacesAndNewlines)
            let signature: String = createChannelSignature(
                type: .final,
                order: 0,
                content,
                recipient: nil
            )
            let channelId: UUID = await cache.getOrCreateChannelId(for: signature)

            channels.append(ChannelMessage(
                id: channelId,
                type: .final,
                content: content,
                order: 0,
                recipient: nil,
                toolRequest: nil
            ))
        }

        return channels
    }

    private func parseCompleteChannels(from output: String) async -> [ChannelMessage] {
        let matches: [NSTextCheckingResult] = findChannelMatches(in: output)
        return await buildChannels(from: matches, in: output)
    }

    // swiftlint:disable:next function_body_length
    private func parsePartialChannel(
        from output: String,
        afterChannels channels: [ChannelMessage]
    ) async -> ChannelMessage? {
        let lastPosition: Int = findLastCompleteChannelPosition(in: output)
        let remaining: String = String(output.dropFirst(lastPosition))

        // Pattern for incomplete channel (no terminator)
        let partialPattern: String =
            "<\\|channel\\|>(\\w+)<\\|message\\|>(.*?)" +
            "(?:<\\|recipient\\|>([^<]+))?$"
        guard let regex = try? NSRegularExpression(
            pattern: partialPattern,
            options: .dotMatchesLineSeparators
        ),
        let match = regex.firstMatch(
            in: remaining,
            range: NSRange(remaining.startIndex..., in: remaining)
        ) else {
            return nil
        }

        // Extract channel info from partial match
        let channelGroupIndex: Int = 1
        let contentGroupIndex: Int = 2
        guard let channelRange = Range(match.range(at: channelGroupIndex), in: remaining),
            let contentRange = Range(match.range(at: contentGroupIndex), in: remaining) else {
            return nil
        }

        let channelName: String = String(remaining[channelRange])
        var content: String = String(remaining[contentRange])

        // Clean up content - remove any incomplete channel tags
        if let nextChannelIndex = content.range(of: "<|channel|>") {
            content = String(content[..<nextChannelIndex.lowerBound])
        }

        let channelType: ChannelMessage.ChannelType = mapChannelType(channelName)

        // Extract recipient if present
        var recipient: String?
        let recipientGroupIndex: Int = 3
        if match.numberOfRanges > recipientGroupIndex {
            let recipientRange: NSRange = match.range(at: recipientGroupIndex)
            if recipientRange.location != NSNotFound,
                let range = Range(recipientRange, in: remaining) {
                recipient = String(remaining[range])
            }
        }

        // Create tool request if needed
        let toolRequest: ToolRequest? = if channelType == .tool {
            extractToolRequest(from: content, recipient: recipient)
        } else {
            nil
        }

        let signature: String = createChannelSignature(
            type: channelType,
            order: channels.count,
            content,
            recipient: recipient
        )
        let channelId: UUID = await cache.getOrCreateChannelId(for: signature)

        return ChannelMessage(
            id: channelId,
            type: channelType,
            content: content,
            order: channels.count,
            recipient: recipient,
            toolRequest: toolRequest
        )
    }

    private func findLastCompleteChannelPosition(in output: String) -> Int {
        var lastPosition: Int = 0
        let completePattern: String =
            "<\\|channel\\|>\\w+<\\|message\\|>.*?" +
            "(?:<\\|end\\|>|<\\|return\\|>|<\\|call\\|>)"

        if let regex = try? NSRegularExpression(
            pattern: completePattern,
            options: .dotMatchesLineSeparators
        ) {
            let matches: [NSTextCheckingResult] = regex.matches(
                in: output,
                range: NSRange(output.startIndex..., in: output)
            )
            if let lastMatch = matches.last {
                lastPosition = lastMatch.range.location + lastMatch.range.length
            }
        }
        return lastPosition
    }

    private func findChannelMatches(in output: String) -> [NSTextCheckingResult] {
        // Parse channel messages using pattern matching
        // Updated pattern to only match complete channels with proper terminators
        // Use negative lookahead to prevent capturing content from next channel
        let channelPattern: String =
            "<\\|channel\\|>(\\w+)<\\|message\\|>((?:(?!<\\|channel\\|>).)*?)" +
            "(?:<\\|recipient\\|>([^<]+))?" +
            "(?:<\\|end\\|>|<\\|return\\|>|<\\|call\\|>)"
        guard let regex = try? NSRegularExpression(
            pattern: channelPattern,
            options: .dotMatchesLineSeparators
        ) else {
            return []
        }

        return regex.matches(
            in: output,
            range: NSRange(output.startIndex..., in: output)
        )
    }

    private func buildChannels(
        from matches: [NSTextCheckingResult],
        in output: String
    ) async -> [ChannelMessage] {
        var channels: [ChannelMessage] = []
        var order: Int = 0

        for match in matches {
            if let channel = await parseChannel(from: match, in: output, order: order) {
                channels.append(channel)
                order += 1
            }
        }

        return channels
    }

    private func parseChannel(
        from match: NSTextCheckingResult,
        in output: String,
        order: Int
    ) async -> ChannelMessage? {
        guard let channelRange = Range(
            match.range(at: RegexGroup.channelName),
            in: output
        ),
        let contentRange = Range(
            match.range(at: RegexGroup.channelContent),
            in: output
        ) else {
            return nil
        }

        let channelName: String = String(output[channelRange])
        let content: String = String(output[contentRange])

        // Extract recipient if present (for tool channels)
        let recipient: String? = extractChannelRecipient(from: match, in: output)
            ?? extractRecipient(from: output, beforeMatch: match.range)

        // Map channel name to ChannelType
        let channelType: ChannelMessage.ChannelType = mapChannelType(channelName)

        // Create tool request if this is a tool channel
        let toolRequest: ToolRequest? = if channelType == .tool {
            extractToolRequest(from: content, recipient: recipient)
        } else {
            nil
        }

        let signature: String = createChannelSignature(
            type: channelType,
            order: order,
            content,
            recipient: recipient
        )
        let channelId: UUID = await cache.getOrCreateChannelId(for: signature)

        return ChannelMessage(
            id: channelId,
            type: channelType,
            content: content,
            order: order,
            recipient: recipient,
            toolRequest: toolRequest
        )
    }

    private func extractChannelRecipient(
        from match: NSTextCheckingResult,
        in output: String
    ) -> String? {
        guard match.numberOfRanges > RegexGroup.recipientGroup else {
            return nil
        }

        let recipientRange: NSRange = match.range(at: RegexGroup.recipientGroup)
        guard recipientRange.location != NSNotFound,
            let range = Range(recipientRange, in: output) else {
            return nil
        }

        return String(output[range])
    }

    private func mapChannelType(_ channelName: String) -> ChannelMessage.ChannelType {
        switch channelName {
        case labels.analysisChannel:
            return .analysis

        case labels.commentaryChannel:
            return .commentary

        case labels.finalChannel:
            return .final

        case "tool":
            return .tool

        default:
            return .final
        }
    }

    // MARK: - Helper Methods

    private func extractRecipient(from output: String, beforeMatch range: NSRange) -> String? {
        // Look for "to=" pattern before the channel
        let beforeText: String = String(
            output[..<output.index(output.startIndex, offsetBy: range.location)]
        )

        let pattern: String = "to=(functions\\.[\\w_]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let matches: [NSTextCheckingResult] = regex.matches(
            in: beforeText,
            range: NSRange(beforeText.startIndex..., in: beforeText)
        )
        if let lastMatch = matches.last,
            let range = Range(lastMatch.range(at: RegexGroup.recipientMatch), in: beforeText) {
            return String(beforeText[range])
        }

        return nil
    }

    private func extractToolRequest(from content: String, recipient: String?) -> ToolRequest? {
        guard let recipient else {
            return nil
        }

        // Extract function name from recipient
        let functionName: String = if recipient.hasPrefix("functions.") {
            String(recipient.dropFirst("functions.".count))
        } else {
            recipient
        }

        // Normalize content: remove backslash continuations
        var normalizedContent: String = content

        // Remove leading backslash-newline sequences
        if normalizedContent.hasPrefix("\\") {
            normalizedContent = String(normalizedContent.dropFirst())
        }
        normalizedContent = normalizedContent.trimmingCharacters(in: .whitespacesAndNewlines)

        // Also handle backslash continuations within the content
        normalizedContent = normalizedContent.replacingOccurrences(of: "\\\n", with: "")

        // Content should be the arguments (JSON)
        return ToolRequest(
            name: functionName,
            arguments: normalizedContent,
            recipient: recipient
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

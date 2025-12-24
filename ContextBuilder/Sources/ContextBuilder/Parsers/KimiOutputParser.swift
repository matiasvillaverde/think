import Abstractions
import Foundation
import OSLog

/// Parser for Kimi-K2 style outputs with tool call sections
internal struct KimiOutputParser: OutputParser {
    private static let logger: Logger = Logger(
        subsystem: "ContextBuilder",
        category: "KimiParser"
    )
    private static let toolSectionRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "<\\|tool_calls_section_begin\\|>(.*?)<\\|tool_calls_section_end\\|>",
        options: .dotMatchesLineSeparators
    )
    private static let toolCallRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "<\\|tool_call_begin\\|>(.*?)" +
            "<\\|tool_call_argument_begin\\|>(.*?)" +
            "<\\|tool_call_end\\|>",
        options: .dotMatchesLineSeparators
    )
    private static let toolReturnRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "## Return of .*?(?=## Return of |\\z)",
        options: .dotMatchesLineSeparators
    )

    private enum RegexGroup {
        static let sectionContent: Int = 1
        static let toolId: Int = 1
        static let toolArgs: Int = 2
    }

    private let cache: ProcessingCache

    internal init(cache: ProcessingCache) {
        self.cache = cache
    }

    internal func parse(_ output: String) async -> [ChannelMessage] {
        var channels: [ChannelMessage] = []
        var order: Int = 0

        let toolSections: [String] = findToolSections(in: output)
        let preamble: String = extractPreamble(from: output, sections: toolSections)

        await appendCommentary(
            preamble: preamble,
            channels: &channels,
            order: &order
        )
        await appendToolCalls(
            toolSections: toolSections,
            channels: &channels,
            order: &order
        )

        let finalContent: String = buildFinalContent(
            output: output,
            preamble: preamble
        )
        await appendFinal(
            content: finalContent,
            channels: &channels,
            order: &order
        )

        return channels
    }

    private func appendCommentary(
        preamble: String,
        channels: inout [ChannelMessage],
        order: inout Int
    ) async {
        let trimmed: String = preamble.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        let signature: String = createChannelSignature(
            type: .commentary,
            order: order,
            recipient: nil
        )
        let channelId: UUID = await cache.getOrCreateChannelId(for: signature)
        channels.append(ChannelMessage(
            id: channelId,
            type: .commentary,
            content: trimmed,
            order: order,
            recipient: nil,
            toolRequest: nil
        ))
        order += 1
    }

    private func appendToolCalls(
        toolSections: [String],
        channels: inout [ChannelMessage],
        order: inout Int
    ) async {
        for section in toolSections {
            let toolCalls: [(id: String, arguments: String)] = parseToolCalls(in: section)
            for call in toolCalls {
                let parsed: (name: String, recipient: String?) = parseToolName(from: call.id)
                let signature: String = createChannelSignature(
                    type: .tool,
                    order: order,
                    recipient: parsed.recipient
                )
                let channelId: UUID = await cache.getOrCreateChannelId(for: signature)

                let request: ToolRequest = ToolRequest(
                    name: parsed.name,
                    arguments: call.arguments,
                    recipient: parsed.recipient
                )

                channels.append(ChannelMessage(
                    id: channelId,
                    type: .tool,
                    content: call.arguments,
                    order: order,
                    recipient: parsed.recipient,
                    toolRequest: request
                ))
                order += 1
            }
        }
    }

    private func buildFinalContent(output: String, preamble: String) -> String {
        var finalContent: String = output

        if hasIncompleteToolSection(output: output) {
            if let range = output.range(of: "<|tool_calls_section_begin|>") {
                finalContent = String(output[..<range.lowerBound])
            }
        } else {
            finalContent = removeToolSections(from: output)
        }
        finalContent = removeToolReturnBlocks(from: finalContent)

        if !preamble.isEmpty, finalContent.hasPrefix(preamble) {
            finalContent = String(finalContent.dropFirst(preamble.count))
        }

        return finalContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func appendFinal(
        content: String,
        channels: inout [ChannelMessage],
        order: inout Int
    ) async {
        guard !content.isEmpty else {
            return
        }

        let signature: String = createChannelSignature(
            type: .final,
            order: order,
            recipient: nil
        )
        let channelId: UUID = await cache.getOrCreateChannelId(for: signature)
        channels.append(ChannelMessage(
            id: channelId,
            type: .final,
            content: content,
            order: order,
            recipient: nil,
            toolRequest: nil
        ))
        order += 1
    }

    private func findToolSections(in output: String) -> [String] {
        guard let regex = Self.toolSectionRegex else {
            Self.logger.error("Failed to create regex for tool sections")
            return []
        }

        let matches: [NSTextCheckingResult] = regex.matches(
            in: output,
            range: NSRange(output.startIndex..., in: output)
        )

        return matches.compactMap { match in
            guard let range = Range(match.range(at: RegexGroup.sectionContent), in: output) else {
                return nil
            }
            return String(output[range])
        }
    }

    private func extractPreamble(from output: String, sections: [String]) -> String {
        guard !sections.isEmpty || output.contains("<|tool_calls_section_begin|>"),
            let range = output.range(of: "<|tool_calls_section_begin|>") else {
            return ""
        }
        return String(output[..<range.lowerBound])
    }

    private func hasIncompleteToolSection(output: String) -> Bool {
        let hasBegin: Bool = output.contains("<|tool_calls_section_begin|>")
        let hasEnd: Bool = output.contains("<|tool_calls_section_end|>")
        return hasBegin && !hasEnd
    }

    private func parseToolCalls(in section: String) -> [(id: String, arguments: String)] {
        guard let regex = Self.toolCallRegex else {
            Self.logger.error("Failed to create regex for tool calls")
            return []
        }

        let matches: [NSTextCheckingResult] = regex.matches(
            in: section,
            range: NSRange(section.startIndex..., in: section)
        )

        return matches.compactMap { match in
            guard let idRange = Range(match.range(at: RegexGroup.toolId), in: section),
                let argsRange = Range(match.range(at: RegexGroup.toolArgs), in: section) else {
                return nil
            }

            let toolId: String = String(section[idRange]).trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let args: String = String(section[argsRange]).trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            return (id: toolId, arguments: args)
        }
    }

    private func parseToolName(from toolId: String) -> (name: String, recipient: String?) {
        if toolId.hasPrefix("functions.") {
            let remainder: String = String(toolId.dropFirst("functions.".count))
            let name: String = remainder.split(separator: ":", maxSplits: 1)
                .first
                .map(String.init) ?? remainder
            return (name: name, recipient: "functions.\(name)")
        }

        if let name = toolId.split(separator: ":", maxSplits: 1).first.map(String.init),
            !name.isEmpty {
            return (name: name, recipient: "functions.\(name)")
        }

        return (name: toolId.isEmpty ? "tool" : toolId, recipient: nil)
    }

    private func removeToolSections(from output: String) -> String {
        guard let regex = Self.toolSectionRegex else {
            return output
        }

        let range: NSRange = NSRange(output.startIndex..., in: output)
        return regex.stringByReplacingMatches(
            in: output,
            range: range,
            withTemplate: ""
        )
    }

    private func removeToolReturnBlocks(from output: String) -> String {
        // Remove Kimi tool response blocks if they appear in output
        guard let regex = Self.toolReturnRegex else {
            return output
        }

        let range: NSRange = NSRange(output.startIndex..., in: output)
        return regex.stringByReplacingMatches(
            in: output,
            range: range,
            withTemplate: ""
        )
    }

    /// Create a stable signature for a channel that survives content streaming
    private func createChannelSignature(
        type: ChannelMessage.ChannelType,
        order: Int,
        recipient: String?
    ) -> String {
        let recipientPart: String = recipient ?? ""
        return "\(type.rawValue):\(order):\(recipientPart)"
    }
}

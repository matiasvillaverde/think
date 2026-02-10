import Foundation

/// Parses formatted prompts produced by Think's ContextBuilder into OpenAI-compatible chat messages.
///
/// Think builds rich prompts (Harmony / ChatML / Llama / Mistral) for local models.
/// Remote providers expect role-based message arrays. This component bridges that gap so remote models behave
/// like first-class citizens
/// without rewriting the entire prompt pipeline.
///
/// Design: Strategy + Chain of Responsibility
/// - Each parser is a strategy that either parses or returns nil.
/// - The facade tries parsers in priority order.
enum RemotePromptParser {
    static func parseMessages(from text: String) -> [ChatMessage]? {
        for parser in makeParsers() {
            if let messages = parser.parse(text: text) {
                return messages
            }
        }
        return nil
    }

    // MARK: - Private

    private static func makeParsers() -> [any RemotePromptParsing] {
        [
            HarmonyPromptParser(),
            Llama3PromptParser(),
            ChatMLPromptParser(),
            MistralInstPromptParser()
        ]
    }
}

// MARK: - Strategy Protocol

private protocol RemotePromptParsing {
    func parse(text: String) -> [ChatMessage]?
}

// MARK: - Harmony

private struct HarmonyPromptParser: RemotePromptParsing {
    func parse(text: String) -> [ChatMessage]? {
        let startToken = "<|start|>"
        let messageToken = "<|message|>"
        let channelToken = "<|channel|>"
        let endToken = "<|end|>"

        guard text.contains(startToken) else {
            return nil
        }

        var messages: [ChatMessage] = []
        messages.reserveCapacity(8)

        var index = text.startIndex
        while let startRange = text.range(of: startToken, range: index..<text.endIndex) {
            var cursor = startRange.upperBound

            // Role until next token boundary.
            guard let nextToken = text.range(of: "<|", range: cursor..<text.endIndex) else {
                break
            }
            let rawRole = String(text[cursor..<nextToken.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            cursor = nextToken.lowerBound

            // Optional channel marker (assistant can emit `<|channel|>final` etc).
            if text[cursor...].hasPrefix(channelToken),
               let channelStart = text.index(
                   cursor,
                   offsetBy: channelToken.count,
                   limitedBy: text.endIndex
               ),
               let channelEnd = text.range(of: "<|", range: channelStart..<text.endIndex) {
                cursor = channelEnd.lowerBound
            }

            guard text[cursor...].hasPrefix(messageToken) else {
                // Some prompts end with `<|start|>assistant` without a message; skip.
                index = cursor
                continue
            }
            cursor = text.index(cursor, offsetBy: messageToken.count)

            guard let endRange = text.range(of: endToken, range: cursor..<text.endIndex) else {
                break
            }

            let content = String(text[cursor..<endRange.lowerBound])
            if let message = Self.makeMessage(role: rawRole, content: content) {
                messages.append(message)
            }

            index = endRange.upperBound
        }

        return messages.isEmpty ? nil : messages
    }

    private static func makeMessage(role rawRole: String, content: String) -> ChatMessage? {
        switch rawRole.lowercased() {
        case "system", "developer":
            return ChatMessage(role: .system, content: content)
        case "user":
            return ChatMessage(role: .user, content: content)
        case "assistant":
            return ChatMessage(role: .assistant, content: content)
        default:
            // Ignore unsupported roles (e.g., tool markers) for now.
            return nil
        }
    }
}

// MARK: - ChatML

private struct ChatMLPromptParser: RemotePromptParsing {
    func parse(text: String) -> [ChatMessage]? {
        let startToken = "<|im_start|>"
        let endToken = "<|im_end|>"

        guard text.contains(startToken) else {
            return nil
        }

        var messages: [ChatMessage] = []
        messages.reserveCapacity(8)

        var index = text.startIndex
        while let startRange = text.range(of: startToken, range: index..<text.endIndex) {
            var cursor = startRange.upperBound

            // Role until newline.
            guard let roleEnd = text.range(of: "\n", range: cursor..<text.endIndex) else {
                break
            }
            let rawRole = String(text[cursor..<roleEnd.lowerBound]).trimmingCharacters(in: .whitespaces)
            cursor = roleEnd.upperBound

            guard let endRange = text.range(of: endToken, range: cursor..<text.endIndex) else {
                break
            }

            let content = String(text[cursor..<endRange.lowerBound])
            if let message = makeMessage(role: rawRole, content: content) {
                messages.append(message)
            }

            index = endRange.upperBound
        }

        return messages.isEmpty ? nil : messages
    }

    private func makeMessage(role rawRole: String, content: String) -> ChatMessage? {
        switch rawRole.lowercased() {
        case "system", "developer":
            return ChatMessage(role: .system, content: content)
        case "user":
            return ChatMessage(role: .user, content: content)
        case "assistant":
            return ChatMessage(role: .assistant, content: content)
        default:
            // ChatML can include tool blocks; remote requests currently ignore tool-role messages.
            return nil
        }
    }
}

// MARK: - Llama 3 Header Tokens

private struct Llama3PromptParser: RemotePromptParsing {
    func parse(text: String) -> [ChatMessage]? {
        let headerStart = "<|start_header_id|>"
        let headerEnd = "<|end_header_id|>"
        let messageEnd = "<|eot_id|>"

        guard text.contains(headerStart), text.contains(headerEnd) else {
            return nil
        }

        var messages: [ChatMessage] = []
        messages.reserveCapacity(8)

        var index = text.startIndex
        while let startRange = text.range(of: headerStart, range: index..<text.endIndex) {
            var cursor = startRange.upperBound

            guard let headerEndRange = text.range(of: headerEnd, range: cursor..<text.endIndex) else {
                break
            }

            let rawRole = String(text[cursor..<headerEndRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            cursor = headerEndRange.upperBound

            // Llama 3 format typically has "\n\n" before content.
            if text[cursor...].hasPrefix("\n\n") {
                cursor = text.index(cursor, offsetBy: 2)
            } else if text[cursor...].hasPrefix("\n") {
                cursor = text.index(cursor, offsetBy: 1)
            }

            guard let endRange = text.range(of: messageEnd, range: cursor..<text.endIndex) else {
                break
            }

            let content = String(text[cursor..<endRange.lowerBound])
            if let message = makeMessage(role: rawRole, content: content) {
                messages.append(message)
            }

            index = endRange.upperBound
        }

        return messages.isEmpty ? nil : messages
    }

    private func makeMessage(role rawRole: String, content: String) -> ChatMessage? {
        switch rawRole.lowercased() {
        case "system", "developer":
            return ChatMessage(role: .system, content: content)
        case "user":
            return ChatMessage(role: .user, content: content)
        case "assistant":
            return ChatMessage(role: .assistant, content: content)
        default:
            // Ignore tool/ipython headers for now.
            return nil
        }
    }
}

// MARK: - Mistral [INST]

private struct MistralInstPromptParser: RemotePromptParsing {
    func parse(text: String) -> [ChatMessage]? {
        let start = "[INST]"
        let end = "[/INST]"

        guard text.contains(start), text.contains(end) else {
            return nil
        }

        // Best-effort: treat each [INST]...[/INST] as a user turn, with any interleaved text
        // treated as assistant turns.
        var messages: [ChatMessage] = []
        messages.reserveCapacity(8)

        var cursor = text.startIndex
        while let instStart = text.range(of: start, range: cursor..<text.endIndex) {
            // Anything before [INST] is assistant (rare, but can happen with history).
            if instStart.lowerBound > cursor {
                let between = String(text[cursor..<instStart.lowerBound])
                if !between.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    messages.append(ChatMessage(role: .assistant, content: between))
                }
            }

            guard let instEnd = text.range(of: end, range: instStart.upperBound..<text.endIndex) else {
                break
            }

            let userContent = String(text[instStart.upperBound..<instEnd.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !userContent.isEmpty {
                messages.append(ChatMessage(role: .user, content: userContent))
            }

            cursor = instEnd.upperBound
        }

        // Trailing text becomes assistant.
        if cursor < text.endIndex {
            let trailing = String(text[cursor..<text.endIndex])
            if !trailing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                messages.append(ChatMessage(role: .assistant, content: trailing))
            }
        }

        return messages.isEmpty ? nil : messages
    }
}

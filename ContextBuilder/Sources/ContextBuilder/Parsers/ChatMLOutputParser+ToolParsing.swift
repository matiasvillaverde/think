import Abstractions
import Foundation

extension ChatMLOutputParser {
    func parseToolCallPayload(_ jsonString: String) -> [ToolRequest] {
        let trimmed: String = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else {
            return []
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) else {
            return []
        }

        return extractToolRequests(from: json)
    }

    private func extractToolRequests(from json: Any) -> [ToolRequest] {
        if let dict = json as? [String: Any] {
            return extractToolRequests(from: dict)
        }

        if let array = json as? [Any] {
            return array.flatMap { extractToolRequests(from: $0) }
        }

        return []
    }

    private func extractToolRequests(from dict: [String: Any]) -> [ToolRequest] {
        if let name = dict["name"] as? String {
            if let arguments = dict["arguments"] {
                return [makeToolRequest(name: name, arguments: arguments)]
            }
        }

        if let function = dict["function"] as? [String: Any] {
            return extractToolRequests(from: function)
        }

        if let toolCall = dict["tool_call"] {
            return extractToolRequests(from: toolCall)
        }

        if let toolCalls = dict["tool_calls"] {
            return extractToolRequests(from: toolCalls)
        }

        if let functionCall = dict["function_call"] {
            return extractToolRequests(from: functionCall)
        }

        return []
    }

    private func makeToolRequest(name: String, arguments: Any) -> ToolRequest {
        let normalizedName: String = normalizeToolName(name)
        let argsString: String = serializeArguments(arguments)
        return ToolRequest(name: normalizedName, arguments: argsString)
    }

    private func normalizeToolName(_ name: String) -> String {
        let trimmed: String = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if ToolIdentifier.from(toolName: trimmed) != nil {
            return trimmed
        }

        if let dotIndex = trimmed.firstIndex(of: ".") {
            let prefix: String = String(trimmed[..<dotIndex])
            if ToolIdentifier.from(toolName: prefix) != nil {
                return prefix
            }
        }

        return trimmed
    }

    private func serializeArguments(_ arguments: Any) -> String {
        if let string = arguments as? String {
            return string
        }

        if JSONSerialization.isValidJSONObject(arguments) {
            if let data = try? JSONSerialization.data(withJSONObject: arguments) {
                if let jsonString = String(data: data, encoding: .utf8) {
                    return jsonString
                }
            }
        }

        return String(describing: arguments)
    }
}

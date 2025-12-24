import Abstractions
import Foundation

/// Extension for tool response formatting in ChatML format
extension ChatMLContextFormatter {
    /// Formats a single tool response result into JSON-compatible string
    /// - Parameter result: The raw result string from a tool response
    /// - Returns: A JSON-formatted content string
    internal func formatToolResponseContent(_ result: String) -> String {
        if result.isEmpty {
            // Empty result - use empty string to ensure valid JSON
            return "\"\""
        }

        if let data: Data = result.data(using: .utf8),
            (try? JSONSerialization.jsonObject(with: data)) != nil {
            // Valid JSON - preserve original format but fix URL escaping only
            return result.replacingOccurrences(of: "\\/", with: "/")
        }

        // Invalid JSON - wrap as string with proper escaping
        let escaped: String = result
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(escaped)\""
    }
}

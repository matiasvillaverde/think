import Abstractions
import Foundation

/// Extension for Qwen formatter with tool formatting logic
extension QwenContextFormatter {
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
}

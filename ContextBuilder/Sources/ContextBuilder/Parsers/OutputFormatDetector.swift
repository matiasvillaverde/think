import Foundation

/// Detects output format based on signature tokens in the output
internal enum OutputFormatDetector {
    internal static func detect(from output: String) -> OutputFormat {
        let normalized: String = stripCodeBlocks(from: output)

        // Harmony uses explicit channel tokens
        if normalized.contains("<|channel|>"), normalized.contains("<|message|>") {
            return .harmony
        }

        // Kimi-K2 tool calling tokens or tool return blocks
        if normalized.contains("<|tool_calls_section_begin|>") ||
            normalized.contains("<|tool_call_begin|>") ||
            normalized.contains("## Return of ") {
            return .kimi
        }

        // ChatML/Hermes-style markers
        if normalized.contains("<tool_call>") ||
            normalized.contains("<commentary>") ||
            normalized.contains("<think>") {
            return .chatml
        }

        return .unknown
    }

    private static func stripCodeBlocks(from output: String) -> String {
        let pattern: String = "```[\\s\\S]*?```"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return output
        }

        let range: NSRange = NSRange(output.startIndex..., in: output)
        return regex.stringByReplacingMatches(
            in: output,
            range: range,
            withTemplate: ""
        )
    }
}

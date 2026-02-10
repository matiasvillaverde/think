import Foundation

/// Best-effort extraction of user-facing streaming content from raw model output.
///
/// Some architectures (notably Harmony) can stream special tokens and channel headers.
/// During streaming we want the UI to show only the `final` channel text, not the raw tags.
internal enum StreamingFinalChannelExtractor {
    private static let finalMarker: String = "<|channel|>final<|message|>"
    private static let recipientMarker: String = "<|recipient|>"
    private static let terminators: [String] = [
        "<|end|>",
        "<|return|>",
        "<|call|>",
        "<|channel|>"
    ]

    internal static func extract(from accumulatedText: String) -> String {
        guard let startRange: Range<String.Index> = accumulatedText.range(
            of: finalMarker,
            options: [.backwards, .literal]
        ) else {
            // Harmony output without a final marker is almost always just headers/tags.
            // Returning raw text causes the UI to briefly show tokens like "<|channel|>".
            // Prefer showing nothing until we have a user-facing final channel.
            if accumulatedText.contains("<|channel|>") || accumulatedText.contains("<|start|>") {
                return ""
            }

            // ChatML-style models can stream <think> or <commentary> blocks. Strip those so the
            // UI doesn't show internal tags mid-stream.
            return stripChatMLLikeMarkup(from: accumulatedText)
        }

        let afterMarker: Substring = accumulatedText[startRange.upperBound...]

        let endIndex: String.Index = terminators
            .compactMap { afterMarker.range(of: $0, options: .literal)?.lowerBound }
            .min() ?? afterMarker.endIndex

        var content: String = String(afterMarker[..<endIndex])

        if let recipientRange = content.range(of: recipientMarker, options: .literal) {
            content = String(content[..<recipientRange.lowerBound])
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripChatMLLikeMarkup(from accumulatedText: String) -> String {
        var working: String = accumulatedText

        // Remove complete and incomplete thinking/commentary blocks.
        working = stripTaggedBlock(from: working, startTag: "<think>", endTag: "</think>")
        working = stripTaggedBlock(from: working, startTag: "<commentary>", endTag: "</commentary>")
        working = stripTaggedBlock(from: working, startTag: "<tool_call>", endTag: "</tool_call>")

        working = working.replacingOccurrences(of: "<|im_end|>", with: "")
        working = working.replacingOccurrences(of: "<|im_start|>assistant\n", with: "")

        return working.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripTaggedBlock(from text: String, startTag: String, endTag: String) -> String {
        var working: String = text
        while let start = working.range(of: startTag) {
            let searchRange: Range<String.Index> = start.upperBound..<working.endIndex
            if let end = working.range(of: endTag, range: searchRange) {
                working.removeSubrange(start.lowerBound..<end.upperBound)
                continue
            }

            // Incomplete block; strip from start tag to end.
            working.removeSubrange(start.lowerBound..<working.endIndex)
            break
        }
        return working
    }
}

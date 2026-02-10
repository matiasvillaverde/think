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
            return accumulatedText
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
}

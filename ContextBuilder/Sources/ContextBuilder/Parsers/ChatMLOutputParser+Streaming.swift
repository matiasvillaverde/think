import Abstractions
import Foundation

// MARK: - Streaming Support Extension

extension ChatMLOutputParser {
    /// Progressively extracts content from start tag, even without end tag (for streaming)
    internal func extractProgressiveTaggedContent(
        from text: String,
        startTag: String?,
        endTag: String?
    ) -> (content: String, isComplete: Bool)? {
        guard let startTag, let endTag else {
            return nil
        }

        // Find the first occurrence of start tag
        guard let startRange = text.range(of: startTag) else {
            return nil
        }

        // Search for end tag after the start tag
        let searchRange: Range<String.Index> = startRange.upperBound..<text.endIndex

        if let endRange = text.range(of: endTag, range: searchRange) {
            // Complete tag pair found - extract content between tags
            let content: String = String(text[startRange.upperBound..<endRange.lowerBound])
            return (content: content, isComplete: true)
        }
        // No end tag found - return everything after start tag for streaming
        var content: String = String(text[startRange.upperBound...])

        // Check for partial closing tag at the end and exclude it
        // This prevents treating partial tags like "</thi" or just "<" as content
        if let lastOpenBracket = content.lastIndex(of: "<") {
            let remainder: String = String(content[lastOpenBracket...])
            // If we have a potential partial closing tag or just "<", exclude it
            // This handles both "</thi..." and just "<" at the end
            if !remainder.contains(">") {
                content = String(content[..<lastOpenBracket])
            }
        }

        return (content: content, isComplete: false)
    }

    /// Removes a tagged block (complete or incomplete) from the text
    internal func removeTaggedBlock(
        from text: String,
        startTag: String,
        endTag: String
    ) -> String {
        guard let startRange = text.range(of: startTag) else {
            return text
        }

        let searchRange: Range<String.Index> = startRange.upperBound..<text.endIndex

        if let endRange = text.range(of: endTag, range: searchRange) {
            // Complete block - remove from start tag to end tag
            var result: String = text
            result.removeSubrange(startRange.lowerBound..<endRange.upperBound)
            return result
        }
        // Incomplete block - remove from start tag to end
        return String(text[..<startRange.lowerBound])
    }

    /// Removes the end label from the text
    internal func removeEndLabel(from text: String) -> String {
        guard !labels.endLabel.isEmpty else {
            return text
        }

        // Use simple string replacement for end label
        // This is safe and performant for single occurrence
        if let range = text.range(of: labels.endLabel) {
            var result: String = text
            result.removeSubrange(range)
            return result
        }

        return text
    }

    /// Checks if the text ends with an incomplete tag (O(1) operation for suffix check)
    /// Returns the number of characters to exclude from the end if a partial tag is found
    internal func hasIncompleteTagSuffix(_ text: String) -> Int? {
        // Maximum possible partial tag length to check
        // "<commentary" (11 chars) is the longest possible opening tag prefix
        let maxCheckLength: Int = 20

        // Calculate the starting position for our check
        let checkStart: String.Index = text.index(
            text.endIndex,
            offsetBy: -min(maxCheckLength, text.count)
        )
        let suffix: String = String(text[checkStart...])

        // Find the last '<' in the suffix
        guard let lastOpenIndex = suffix.lastIndex(of: "<") else {
            return nil
        }

        // Get the remainder after the '<'
        let remainder: String = String(suffix[lastOpenIndex...])

        // Check if this potential tag has a closing '>'
        if !remainder.contains(">") {
            // We have an incomplete tag - return how many characters to exclude
            return remainder.count
        }

        return nil
    }
}

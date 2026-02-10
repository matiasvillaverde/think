import Abstractions
import Foundation

/// Test helper utilities for ContextBuilder tests
internal enum TestHelpers {
    /// Normalizes a string by removing extra whitespace for comparison
    /// - Removes leading/trailing whitespace from each line
    /// - Removes empty lines
    /// - Joins with single newlines
    internal static func normalizeForComparison(_ string: String) -> String {
        string
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// Compares two strings after normalizing whitespace
    internal static func areEquivalent(_ string1: String, _ string2: String) -> Bool {
        normalizeForComparison(string1) == normalizeForComparison(string2)
    }

    /// Provides detailed diff information for debugging test failures
    internal static func createDetailedDiff(
        actual: String,
        expected: String
    ) -> String {
        let actualNormalized = normalizeForComparison(actual)
        let expectedNormalized = normalizeForComparison(expected)
        let suffixLength = 200

        var result = """

        === DETAILED COMPARISON ===

        ACTUAL OUTPUT (RAW):
        \"\"\"\(actual)\"\"\"

        EXPECTED OUTPUT (RAW):
        \"\"\"\(expected)\"\"\"

        ACTUAL OUTPUT (NORMALIZED):
        \"\"\"\(actualNormalized)\"\"\"

        EXPECTED OUTPUT (NORMALIZED):
        \"\"\"\(expectedNormalized)\"\"\"

        LENGTHS:
        - Actual raw: \(actual.count) characters
        - Expected raw: \(expected.count) characters
        - Actual normalized: \(actualNormalized.count) characters
        - Expected normalized: \(expectedNormalized.count) characters

        """

        // Show character-by-character diff for the last characters
        let actualSuffix = String(actual.suffix(suffixLength))
        let expectedSuffix = String(expected.suffix(suffixLength))

        result += """
        LAST \(suffixLength) CHARACTERS (ACTUAL):
        \"\"\"\(actualSuffix.debugDescription)\"\"\"

        LAST \(suffixLength) CHARACTERS (EXPECTED):
        \"\"\"\(expectedSuffix.debugDescription)\"\"\"

        ===============================

        """

        return result
    }

    /// Creates a ContextConfiguration for testing
    internal static func createTestContextConfiguration(
        systemPrompt: String,
        history: [MessageData] = [],
        date: Date = Date(),
        knowledgeCutoff: String? = nil
    ) -> ContextConfiguration {
        let defaultMaxPrompt: Int = 4_096
        return ContextConfiguration(
            systemInstruction: systemPrompt,
            contextMessages: history,
            maxPrompt: defaultMaxPrompt,
            includeCurrentDate: true,
            knowledgeCutoffDate: knowledgeCutoff,
            currentDateOverride: ISO8601DateFormatter().string(from: date)
        )
    }

    // MARK: - Channel Creation Helpers

    /// Creates a MessageData object with channels for testing
    internal static func createMessageDataWithChannels(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        userInput: String? = nil,
        channels: [MessageChannel] = [],
        toolCalls: [ToolCall] = []
    ) -> MessageData {
        MessageData(
            id: id,
            createdAt: createdAt,
            userInput: userInput,
            channels: channels,
            toolCalls: toolCalls
        )
    }

    /// Creates a commentary channel for testing
    internal static func createCommentaryChannel(
        content: String,
        order: Int = 0,
        associatedToolId: UUID? = nil
    ) -> MessageChannel {
        MessageChannel(
            type: .commentary,
            content: content,
            order: order,
            associatedToolId: associatedToolId
        )
    }

    /// Creates a final channel for testing
    internal static func createFinalChannel(
        content: String,
        order: Int = 0,
        associatedToolId: UUID? = nil
    ) -> MessageChannel {
        MessageChannel(
            type: .final,
            content: content,
            order: order,
            associatedToolId: associatedToolId
        )
    }
}

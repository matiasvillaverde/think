import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

// MARK: - Helper Extensions

extension ChatMLThinkingStreamingTests {
    // MARK: - Helper Types

    internal struct StreamingState {
        var previousAnalysisContent = ""
        var previousFinalContent = ""
        var hasSeenAnalysisChannel = false
        var hasSeenFinalChannel = false
    }

    // MARK: - Test Constants

    internal enum TestConstants {
        static let testRAMNeeded: UInt64 = 1_000_000_000
        static let expectedChannelCount: Int = 2
    }
    internal func createTestModel(architecture: Architecture) -> SendableModel {
        SendableModel(
            id: UUID(),
            ramNeeded: TestConstants.testRAMNeeded,
            modelType: .language,
            location: "test-model",
            architecture: architecture
        )
    }

    internal func loadThinkingInputContent() throws -> String {
        guard let url = Bundle.module.url(
            forResource: "input_chatml_thinking",
            withExtension: "txt"
        ) else {
            throw ContextBuilderTestError.resourceNotFound("input_chatml_thinking.txt")
        }

        return try String(contentsOf: url, encoding: .utf8)
    }

    internal func processChannels(
        output: ProcessedOutput,
        accumulatedInput: String,
        streamState: inout StreamingState,
        position: Int
    ) throws {
        let analysisChannel = output.channels.first { $0.type == .analysis }
        let finalChannel = output.channels.first { $0.type == .final }

        if let analysis = analysisChannel {
            streamState.hasSeenAnalysisChannel = true
            try verifyAnalysisChannel(
                analysis: analysis,
                accumulatedInput: accumulatedInput,
                previousContent: streamState.previousAnalysisContent,
                position: position
            )
            streamState.previousAnalysisContent = analysis.content
        }

        if let final = finalChannel {
            streamState.hasSeenFinalChannel = true
            try verifyFinalChannel(
                final: final,
                previousContent: streamState.previousFinalContent,
                position: position
            )
            streamState.previousFinalContent = final.content
        }
    }

    internal func verifyAnalysisChannel(
        analysis: ChannelMessage,
        accumulatedInput: String,
        previousContent: String,
        position: Int
    ) throws {
        let hasCompleteThinkTag = accumulatedInput.contains("<think>")
        #expect(
            hasCompleteThinkTag,
            "Analysis channel should only appear after complete <think> tag at \(position)"
        )

        // For streaming, content should grow progressively even without closing tag
        try verifyProgressiveChannelContent(
            current: analysis.content,
            previous: previousContent,
            channelType: "analysis",
            position: position
        )

        #expect(
            !analysis.content.contains("<think>") && !analysis.content.contains("</think>"),
            "Analysis content should not contain thinking labels at position \(position)"
        )
    }

    internal func verifyFinalChannel(
        final: ChannelMessage,
        previousContent: String,
        position: Int
    ) throws {
        try verifyProgressiveChannelContent(
            current: final.content,
            previous: previousContent,
            channelType: "final",
            position: position
        )

        #expect(
            !final.content.contains("Let me calculate"),
            "Final content should not contain thinking text at position \(position)"
        )
    }

    internal func verifyPartialTagHandling(
        _ output: ProcessedOutput,
        accumulatedInput: String,
        fullContent _: String,
        position: Int
    ) throws {
        // Check for partial thinking tag scenarios
        let hasPartialThinkTag = accumulatedInput.hasSuffix("<") ||
            accumulatedInput.hasSuffix("<t") ||
            accumulatedInput.hasSuffix("<th") ||
            accumulatedInput.hasSuffix("<thi") ||
            accumulatedInput.hasSuffix("<thin") ||
            accumulatedInput.hasSuffix("<think")

        let hasCompleteOpenThink = accumulatedInput.contains("<think>")
        let hasClosingThink = accumulatedInput.contains("</think>")

        let analysisChannel = output.channels.first { $0.type == .analysis }

        if hasPartialThinkTag, !hasCompleteOpenThink {
            // Partial opening tag - should have no analysis channel
            #expect(
                analysisChannel == nil,
                "Should not have analysis channel with partial opening tag at position \(position)"
            )
        } else if hasCompleteOpenThink, !hasClosingThink {
            // Has complete opening but no closing - check if there's actual content
            let trimmedContent = accumulatedInput
                .replacingOccurrences(of: "<think>", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedContent.isEmpty {
                // Should have analysis channel only if there's non-whitespace content
                #expect(
                    analysisChannel != nil,
                    "Should have analysis channel for streaming content at position \(position)"
                )
            } else {
                // Should NOT have analysis channel for whitespace-only content
                #expect(
                    analysisChannel == nil,
                    "Should not have analysis channel for whitespace-only at position \(position)"
                )
            }
        }
    }

    internal func verifyProgressiveChannelContent(
        current: String,
        previous: String,
        channelType: String,
        position: Int
    ) throws {
        // Content should either grow, stay the same, or be a cleaned version when closing tag found
        // When closing tag is encountered, content might be cleaned (whitespace trimmed)
        let isGrowing = current.hasPrefix(previous) ||
            current == previous ||
            previous.hasPrefix(current) // Allow shrinking when cleaning occurs
        #expect(
            isGrowing,
            """
            \(channelType) channel content should progressively grow at position \(position).
            Previous: "\(previous)"
            Current: "\(current)"
            """
        )
    }

    internal func verifyFinalThinkingOutput(
        contextBuilder: ContextBuilder,
        model: SendableModel,
        inputContent: String,
        hasSeenAnalysis: Bool
    ) async throws {
        let finalOutput = try await contextBuilder.process(
            output: inputContent,
            model: model
        )

        // Should have exactly 2 channels in final output
        #expect(
            finalOutput.channels.count == TestConstants.expectedChannelCount,
            "Final output should have exactly 2 channels (analysis and final)"
        )

        // Verify we saw analysis channel during streaming
        #expect(
            hasSeenAnalysis,
            "Should have seen analysis channel during streaming"
        )

        // Verify channel ordering
        let sortedChannels = finalOutput.channels.sorted { $0.order < $1.order }
        if sortedChannels.count == TestConstants.expectedChannelCount {
            #expect(
                sortedChannels[0].type == .analysis,
                "First channel should be analysis"
            )
            #expect(
                sortedChannels[1].type == .final,
                "Second channel should be final"
            )
        }
    }
}

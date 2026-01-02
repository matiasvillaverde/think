import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

/// Tests for empty thinking tags in ChatML format - ensuring no analysis channel is created
@Suite("ChatML Empty Thinking Tests")
internal struct ChatMLEmptyThinkingTests {
    @Test(
        "Empty thinking tags should never create analysis channel during streaming",
        arguments: [
            Architecture.llama,
            Architecture.mistral,
            Architecture.mixtral,
            Architecture.deepseek,
            Architecture.qwen,
            Architecture.yi,
            Architecture.phi,
            Architecture.phi4,
            Architecture.baichuan,
            Architecture.chatglm,
            Architecture.smol,
            Architecture.falcon,
            Architecture.gemma
        ]
    )
    func testEmptyThinkingNeverCreatesAnalysisChannel(architecture: Architecture) async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let model = createTestModel(architecture: architecture)
        let inputContent = try loadEmptyThinkingInputContent()

        // Stream processing and verification
        let hasEverSeenAnalysisChannel = try await streamProcessInput(
            inputContent: inputContent,
            contextBuilder: contextBuilder,
            model: model
        )

        // Final verification
        #expect(
            !hasEverSeenAnalysisChannel,
            "Should NEVER create an analysis channel for empty thinking tags, even during streaming"
        )

        // Process and verify final output
        try await verifyFinalOutput(
            inputContent: inputContent,
            contextBuilder: contextBuilder,
            model: model
        )
    }

    @Test("Empty thinking with only whitespace should not create analysis channel")
    func testWhitespaceOnlyThinkingNoAnalysis() async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let model = createTestModel(architecture: .qwen)

        // Test various forms of empty/whitespace-only thinking tags
        let emptyThinkingVariants = [
            "<think></think>Just text",
            "<think> </think>Just text",
            "<think>\n</think>Just text",
            "<think>\n\n</think>Just text",
            "<think>   </think>Just text",
            "<think>\t</think>Just text",
            "<think>\n \t \n</think>Just text"
        ]

        for variant in emptyThinkingVariants {
            let processedOutput = try await contextBuilder.process(
                output: variant,
                model: model
            )

            // Should have only final channel
            let analysisChannel = processedOutput.channels.first { $0.type == .analysis }
            #expect(
                analysisChannel == nil,
                "Should not create analysis channel for empty/whitespace thinking: '\(variant)'"
            )

            let finalChannel = processedOutput.channels.first { $0.type == .final }
            #expect(
                finalChannel != nil,
                "Should have final channel for: '\(variant)'"
            )

            if let final = finalChannel {
                #expect(
                    final.content == "Just text",
                    "Final content should be 'Just text' for variant: '\(variant)'"
                )
            }
        }
    }

    @Test("Compare empty vs non-empty thinking behavior")
    func testCompareEmptyVsNonEmptyThinking() async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let model = createTestModel(architecture: .deepseek)

        // Non-empty thinking - should create analysis channel
        let nonEmptyThinking = "<think>Some thinking here</think>Response text"
        let nonEmptyOutput = try await contextBuilder.process(
            output: nonEmptyThinking,
            model: model
        )

        #expect(
            nonEmptyOutput.channels.count == 2,
            "Non-empty thinking should create 2 channels"
        )
        #expect(
            nonEmptyOutput.channels.contains { $0.type == .analysis },
            "Non-empty thinking should have analysis channel"
        )

        // Empty thinking - should NOT create analysis channel
        let emptyThinking = "<think></think>Response text"
        let emptyOutput = try await contextBuilder.process(
            output: emptyThinking,
            model: model
        )

        #expect(
            emptyOutput.channels.count == 1,
            "Empty thinking should create only 1 channel"
        )
        #expect(
            !emptyOutput.channels.contains { $0.type == .analysis },
            "Empty thinking should NOT have analysis channel"
        )
        #expect(
            emptyOutput.channels.contains { $0.type == .final },
            "Empty thinking should still have final channel"
        )
    }

    // MARK: - Helper Methods

    private func streamProcessInput(
        inputContent: String,
        contextBuilder: ContextBuilder,
        model: SendableModel
    ) async throws -> Bool {
        var hasEverSeenAnalysisChannel = false
        var accumulatedInput = ""

        for (index, character) in inputContent.enumerated() {
            accumulatedInput.append(character)

            let processedOutput = try await contextBuilder.process(
                output: accumulatedInput,
                model: model
            )

            // Check for analysis channel - should never exist
            let analysisChannel = processedOutput.channels.first { $0.type == .analysis }
            if let analysis = analysisChannel {
                hasEverSeenAnalysisChannel = true
                Issue.record(
                    """
                    Found unexpected analysis channel at position \(index):
                    Input: '\(accumulatedInput)'
                    Content: '\(analysis.content)'
                    """
                )
            }
        }

        return hasEverSeenAnalysisChannel
    }

    private func verifyFinalOutput(
        inputContent: String,
        contextBuilder: ContextBuilder,
        model: SendableModel
    ) async throws {
        let finalOutput = try await contextBuilder.process(
            output: inputContent,
            model: model
        )

        // Should have exactly 1 channel (final only)
        let channelCount = finalOutput.channels.count
        #expect(
            channelCount == 1,
            "Final output should have exactly 1 channel (final only), got \(channelCount)"
        )

        // Verify it's a final channel
        let finalChannel = finalOutput.channels.first { $0.type == .final }
        #expect(
            finalChannel != nil,
            "Should have a final channel"
        )

        // Verify no analysis channel in final output
        let analysisChannelInFinal = finalOutput.channels.first { $0.type == .analysis }
        #expect(
            analysisChannelInFinal == nil,
            "Should NOT have an analysis channel in final output for empty thinking tags"
        )

        // Verify the final content is correct
        if let final = finalChannel {
            #expect(
                final.content == "3 + 3 = 6",
                "Final content should be '3 + 3 = 6', got '\(final.content)'"
            )
            #expect(
                final.order == 0,
                "Final channel should have order 0 when it's the only channel"
            )
        }
    }

    private func createTestModel(architecture: Architecture) -> SendableModel {
        SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: architecture,
            locationKind: .huggingFace,
        )
    }

    private func loadEmptyThinkingInputContent() throws -> String {
        guard let url = Bundle.module.url(
            forResource: "input_chatml_empty_thinking",
            withExtension: "txt"
        ) else {
            throw ContextBuilderTestError.resourceNotFound("input_chatml_empty_thinking.txt")
        }

        return try String(contentsOf: url, encoding: .utf8)
    }
}

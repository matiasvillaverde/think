import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

/// Tests for streaming input processing of ChatML thinking format
@Suite("ChatML Thinking Streaming Tests")
internal struct ChatMLThinkingStreamingTests {
    @Test(
        "Process ChatML thinking input character by character",
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
    func testStreamingChatMLThinkingFormat(architecture: Architecture) async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let model = createTestModel(architecture: architecture)
        let inputContent = try loadThinkingInputContent()

        // Track channel evolution during streaming
        var streamState = StreamingState()

        // Process character by character
        var accumulatedInput = ""

        for (index, character) in inputContent.enumerated() {
            accumulatedInput.append(character)

            let processedOutput = try await contextBuilder.process(
                output: accumulatedInput,
                model: model
            )

            // Verify smart partial tag handling
            verifyPartialTagHandling(
                processedOutput,
                accumulatedInput: accumulatedInput,
                fullContent: inputContent,
                position: index
            )

            // Process and verify channels
            processChannels(
                output: processedOutput,
                accumulatedInput: accumulatedInput,
                streamState: &streamState,
                position: index
            )
        }

        // Final state verification
        try await verifyFinalThinkingOutput(
            contextBuilder: contextBuilder,
            model: model,
            inputContent: inputContent,
            hasSeenAnalysis: streamState.hasSeenAnalysisChannel
        )
    }

    @Test("Verify partial tag handling streams progressively for user-facing channels")
    func testPartialTagStreamsProgressively() async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let model = createTestModel(architecture: .qwen)

        // Test various partial tag scenarios
        struct TestCase {
            let input: String
            let shouldHaveChannel: Bool
            let expectedContent: String?
        }

        let testCases = [
            TestCase(input: "<thi", shouldHaveChannel: false, expectedContent: nil),
            TestCase(input: "<thin", shouldHaveChannel: false, expectedContent: nil),
            TestCase(input: "<think", shouldHaveChannel: false, expectedContent: nil),
            TestCase(input: "<think>", shouldHaveChannel: false, expectedContent: nil),
            TestCase(input: "<think>Partial", shouldHaveChannel: true, expectedContent: "Partial"),
            TestCase(
                input: "<think>Partial content without closing",
                shouldHaveChannel: true,
                expectedContent: "Partial content without closing"
            )
        ]

        for testCase in testCases {
            let processedOutput = try await contextBuilder.process(
                output: testCase.input,
                model: model
            )

            let analysisChannel = processedOutput.channels.first { $0.type == .analysis }

            if testCase.shouldHaveChannel {
                // Should have analysis channel once opening tag is complete
                #expect(
                    analysisChannel != nil,
                    "Should create analysis channel for: '\(testCase.input)'"
                )

                if let channel = analysisChannel, let expected = testCase.expectedContent {
                    #expect(
                        channel.content == expected,
                        "Content should be '\(expected)' but was '\(channel.content)'"
                    )
                    // Ensure tags are not included in content
                    #expect(
                        !channel.content.contains("<think"),
                        "Channel content should not contain think tags"
                    )
                }
            } else {
                // Should not have channel for incomplete opening tag
                #expect(
                    analysisChannel == nil,
                    "Should not create channel for incomplete tag: '\(testCase.input)'"
                )
            }
        }
    }

    @Test("Verify complete thinking tag creates analysis channel")
    func testCompleteThinkingCreatesAnalysis() async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let model = createTestModel(architecture: .qwen)

        let completeThinking = "<think>Complete thinking content</think>"

        let processedOutput = try await contextBuilder.process(
            output: completeThinking,
            model: model
        )

        // Should have exactly one analysis channel
        let analysisChannels = processedOutput.channels.filter { $0.type == .analysis }
        #expect(
            analysisChannels.count == 1,
            "Should have exactly one analysis channel for complete thinking block"
        )

        if let analysis = analysisChannels.first {
            #expect(
                analysis.content == "Complete thinking content",
                "Analysis content should match thinking content without tags"
            )
            #expect(
                analysis.order == 0,
                "Analysis channel should have order 0"
            )
        }

        // Should have no final channel for pure thinking content
        let finalChannels = processedOutput.channels.filter { $0.type == .final }
        #expect(
            finalChannels.isEmpty,
            "Should have no final channel for pure thinking content"
        )
    }

    @Test("Verify mixed content creates both analysis and final channels")
    func testMixedContentCreatesBothChannels() async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let model = createTestModel(architecture: .deepseek)

        // Use the actual thinking input content
        let inputContent = try loadThinkingInputContent()

        let processedOutput = try await contextBuilder.process(
            output: inputContent,
            model: model
        )

        // Should have exactly 2 channels
        #expect(
            processedOutput.channels.count == 2,
            "Should have exactly 2 channels (analysis and final)"
        )

        // Verify analysis channel
        let analysisChannel = processedOutput.channels.first { $0.type == .analysis }
        #expect(analysisChannel != nil, "Should have an analysis channel")

        if let analysis = analysisChannel {
            #expect(
                analysis.content.contains("Let me calculate 2 + 2"),
                "Analysis should contain thinking content"
            )
            #expect(
                !analysis.content.contains("<think>"),
                "Analysis content should not contain thinking tags"
            )
            #expect(
                analysis.order == 0,
                "Analysis channel should come first (order 0)"
            )
        }

        // Verify final channel
        let finalChannel = processedOutput.channels.first { $0.type == .final }
        #expect(finalChannel != nil, "Should have a final channel")

        if let final = finalChannel {
            #expect(
                final.content == "2 + 2 equals 4.",
                "Final content should be the user-facing response"
            )
            #expect(
                final.order == 1,
                "Final channel should come second (order 1)"
            )
        }
    }
}

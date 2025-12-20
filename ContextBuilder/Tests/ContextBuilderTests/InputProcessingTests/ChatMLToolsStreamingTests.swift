import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

/// Tests for streaming input processing of ChatML tools format with commentary
@Suite("ChatML Tools Streaming Tests")
internal struct ChatMLToolsStreamingTests {
    @Test(
        "Process ChatML tools input with commentary character by character",
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
    func testStreamingChatMLToolsWithCommentary(architecture: Architecture) async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let model = createTestModel(architecture: architecture)
        let inputContent = try loadToolsInputContent()

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
            try verifyPartialTagHandling(
                processedOutput,
                accumulatedInput: accumulatedInput,
                position: index
            )

            // Process and verify channels
            try processChannels(
                output: processedOutput,
                accumulatedInput: accumulatedInput,
                streamState: &streamState,
                position: index
            )
        }

        // Final state verification
        try await verifyFinalToolsOutput(
            contextBuilder: contextBuilder,
            model: model,
            inputContent: inputContent,
            streamState: streamState
        )
    }

    @Test(
        "Verify commentary appears before tool call",
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
    func testCommentaryBeforeToolOrder(architecture: Architecture) async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let model = createTestModel(architecture: architecture)

        let completeInput = """
        <commentary>
        I'll check the weather in Paris for you.
        </commentary>
        <tool_call>
        {"name": "weather", "arguments": {"city": "Paris"}}
        </tool_call>
        """

        let processedOutput = try await contextBuilder.process(
            output: completeInput,
            model: model
        )

        try verifyToolCommentaryOrder(processedOutput)
    }

    private func verifyToolCommentaryOrder(_ processedOutput: ProcessedOutput) throws {
        // Should have exactly 2 channels
        #expect(
            processedOutput.channels.count == TestConstants.expectedToolChannelCount,
            "Should have exactly 2 channels (commentary and tool)"
        )

        // Verify channel types and order
        let sortedChannels = processedOutput.channels.sorted { $0.order < $1.order }

        if sortedChannels.count == TestConstants.expectedToolChannelCount {
            #expect(
                sortedChannels[0].type == .commentary,
                "First channel should be commentary"
            )
            #expect(
                sortedChannels[0].order == 0,
                "Commentary channel should have order 0"
            )

            #expect(
                sortedChannels[1].type == .tool,
                "Second channel should be tool"
            )
            #expect(
                sortedChannels[1].order == 1,
                "Tool channel should have order 1"
            )

            // Verify tool request is properly parsed
            if let toolChannel = sortedChannels[1] as ChannelMessage? {
                #expect(
                    toolChannel.toolRequest != nil,
                    "Tool channel should have toolRequest"
                )
                #expect(
                    toolChannel.toolRequest?.name == "weather",
                    "Tool name should be 'weather'"
                )
                #expect(
                    toolChannel.recipient == "functions.weather",
                    "Tool recipient should be 'functions.weather'"
                )
            }
        }
    }

    @Test(
        "Verify partial tool call returns no tool channel",
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
    func testPartialToolCallReturnsEmpty(architecture: Architecture) async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let model = createTestModel(architecture: architecture)

        // Test various partial tool call scenarios
        let partialInputs = [
            "<tool_c",
            "<tool_call",
            "<tool_call>",
            "<tool_call>{",
            "<tool_call>{\"name\": \"weather\"",
            "<tool_call>{\"name\": \"weather\", \"arguments\":",
            "<tool_call>{\"name\": \"weather\", \"arguments\": {\"city\": \"Paris\"}"
        ]

        for partialInput in partialInputs {
            let processedOutput = try await contextBuilder.process(
                output: partialInput,
                model: model
            )

            // Should not have tool channel for incomplete tool calls
            let toolChannel = processedOutput.channels.first { $0.type == .tool }

            #expect(
                toolChannel == nil,
                "Should not create tool channel for incomplete tool call: '\(partialInput)'"
            )
        }
    }

    @Test(
        "Verify complete commentary creates commentary channel",
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
    func testCompleteCommentaryCreatesChannel(architecture: Architecture) async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let model = createTestModel(architecture: architecture)

        let completeCommentary = "<commentary>Checking the weather now</commentary>"

        let processedOutput = try await contextBuilder.process(
            output: completeCommentary,
            model: model
        )

        // Should have exactly one commentary channel
        let commentaryChannels = processedOutput.channels.filter { $0.type == .commentary }
        #expect(
            commentaryChannels.count == 1,
            "Should have exactly one commentary channel for complete commentary block"
        )

        if let commentary = commentaryChannels.first {
            #expect(
                commentary.content == "Checking the weather now",
                "Commentary content should match input without tags"
            )
            #expect(
                commentary.order == 0,
                "Commentary channel should have order 0"
            )
        }
    }
}

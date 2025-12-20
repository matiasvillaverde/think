import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

/// Tests for streaming input processing of ContextBuilder.process() method
@Suite("ContextBuilder Input Processing Tests")
internal struct ContextBuilderInputProcessingTests {
    @Test(
        "Process ChatML simple input character by character for qwen architecture",
        arguments: [
            Architecture.llama,
            Architecture.mistral,
            Architecture.mixtral,
            Architecture.deepseek,
            Architecture.harmony,
            Architecture.gpt,
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
    func testStreamingInputProcessingQwen(architecture: Architecture) async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let model = createTestModel(architecture: architecture)

        // Load the input file content
        let inputContent = try loadInputContent()

        // Process character by character and verify each intermediate state
        var accumulatedInput = ""
        var previousChannelContent = ""

        for character in inputContent {
            accumulatedInput.append(character)

            // Process and verify the accumulated input
            let processedOutput = try await contextBuilder.process(
                output: accumulatedInput,
                model: model
            )

            try verifyChannelCount(processedOutput, accumulatedInput, inputContent)

            if let channel = processedOutput.channels.first {
                try verifyChannelProperties(channel, at: accumulatedInput.count)
                let currentContent = channel.content
                try verifyProgressiveContent(
                    current: currentContent,
                    previous: previousChannelContent,
                    position: accumulatedInput.count
                )
                previousChannelContent = currentContent
            }
        }

        // Final assertion
        try await verifyFinalOutput(contextBuilder, model, inputContent)
    }

    // MARK: - Verification Helpers

    private func verifyChannelCount(
        _ output: ProcessedOutput,
        _ accumulated: String,
        _ full: String
    ) throws {
        #expect(
            output.channels.count == 1,
            """
            Expected exactly 1 channel, but got \(output.channels.count) channels
            at character position \(accumulated.count) of \(full.count).
            Current accumulated input: "\(accumulated)"
            """
        )
    }

    private func verifyChannelProperties(
        _ channel: ChannelMessage,
        at position: Int
    ) throws {
        #expect(
            channel.type == .final,
            "Expected channel type .final, got \(channel.type) at position \(position)"
        )

        #expect(
            channel.order == 0,
            "Expected channel order 0, got \(channel.order) at position \(position)"
        )

        #expect(
            channel.recipient == nil,
            "Expected nil recipient, got \(String(describing: channel.recipient))"
        )

        #expect(
            channel.toolRequest == nil,
            "Expected nil toolRequest, got \(String(describing: channel.toolRequest))"
        )
    }

    private func verifyProgressiveContent(
        current: String,
        previous: String,
        position: Int
    ) throws {
        #expect(
            current.hasPrefix(previous) || current == previous,
            """
            Channel content should progressively grow or stay the same.
            Previous: "\(previous)"
            Current: "\(current)"
            At character position \(position).
            """
        )
    }

    private func verifyFinalOutput(
        _ contextBuilder: ContextBuilder,
        _ model: SendableModel,
        _ inputContent: String
    ) async throws {
        let finalOutput = try await contextBuilder.process(
            output: inputContent,
            model: model
        )

        #expect(
            finalOutput.channels.count == 1,
            "Final output should have exactly 1 channel"
        )

        if let finalChannel = finalOutput.channels.first {
            let expectedContent = inputContent.trimmingCharacters(in: .whitespacesAndNewlines)
            #expect(
                finalChannel.content == expectedContent,
                """
                Final channel content doesn't match expected input.
                Expected: "\(expectedContent)"
                Actual: "\(finalChannel.content)"
                """
            )
        }
    }

    // MARK: - Helper Methods

    private func createTestModel(architecture: Architecture) -> SendableModel {
        SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: architecture
        )
    }

    private func loadInputContent() throws -> String {
        guard let url = Bundle.module.url(
            forResource: "input_chatml_simple",
            withExtension: "txt"
        ) else {
            throw ContextBuilderTestError.resourceNotFound("input_chatml_simple.txt")
        }

        return try String(contentsOf: url, encoding: .utf8)
    }
}

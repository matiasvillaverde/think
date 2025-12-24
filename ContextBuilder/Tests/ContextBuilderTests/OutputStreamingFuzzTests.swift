import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

@Suite("Output Streaming Fuzz Tests")
internal struct OutputStreamingFuzzTests {
    @Test("ChatML streaming splits never emit tool before closing tag")
    func testChatMLStreamingSplits() async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: .llama
        )

        let output = [
            "<commentary>Note</commentary>",
            "<tool_call>{\"name\":\"search\",\"arguments\":{\"q\":\"x\"}}</tool_call>",
            "Final"
        ].joined()
        let tokens = [
            "<commentary>",
            "</commentary>",
            "<tool_call>",
            "</tool_call>"
        ]

        for prefix in prefixes(for: output, tokens: tokens) {
            let result = try await contextBuilder.process(output: prefix, model: model)
            let hasToolClose = prefix.contains("</tool_call>")
            let hasToolChannel = result.channels.contains { $0.type == .tool }

            if hasToolClose {
                #expect(hasToolChannel)
            } else {
                #expect(!hasToolChannel)
            }
        }
    }

    @Test("Kimi streaming splits only emit tools after section end")
    func testKimiStreamingSplits() async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: .llama
        )

        let output = [
            "Preparing...<|tool_calls_section_begin|>",
            "<|tool_call_begin|>functions.search:0",
            "<|tool_call_argument_begin|>{\"q\":\"x\"}",
            "<|tool_call_end|><|tool_calls_section_end|>",
            "Final"
        ].joined()
        let tokens = [
            "<|tool_calls_section_begin|>",
            "<|tool_call_begin|>",
            "<|tool_call_argument_begin|>",
            "<|tool_call_end|>",
            "<|tool_calls_section_end|>"
        ]

        for prefix in prefixes(for: output, tokens: tokens) {
            let result = try await contextBuilder.process(output: prefix, model: model)
            let hasSectionEnd = prefix.contains("<|tool_calls_section_end|>")
            let hasToolChannel = result.channels.contains { $0.type == .tool }
            let hasFinalChannel = result.channels.contains { $0.type == .final }

            if hasSectionEnd {
                #expect(hasToolChannel)
            } else {
                #expect(!hasToolChannel)
                if prefix.contains("<|tool_calls_section_begin|>") {
                    #expect(!hasFinalChannel)
                }
            }
        }
    }

    @Test("Harmony streaming splits only emit tool request after call tag")
    func testHarmonyStreamingSplits() async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: .harmony
        )

        let output = [
            "<|channel|>analysis<|message|>Thinking<|return|>",
            "<|channel|>tool<|message|>{\"q\":\"x\"}<|recipient|>functions.search<|call|>",
            "<|channel|>final<|message|>Done<|return|>"
        ].joined()
        let tokens = [
            "<|channel|>",
            "<|message|>",
            "<|return|>",
            "<|recipient|>",
            "<|call|>"
        ]

        for prefix in prefixes(for: output, tokens: tokens) {
            let result = try await contextBuilder.process(output: prefix, model: model)
            let hasToolMessage = prefix.contains("<|channel|>tool<|message|>")
            let hasFullRecipient = prefix.contains("<|recipient|>functions.search")
            let hasRecipientTag = prefix.contains("<|recipient|>")
            let hasCallTag = prefix.contains("<|call|>")
            let toolChannel = result.channels.first { $0.type == .tool }

            if hasFullRecipient, hasCallTag {
                #expect(toolChannel?.toolRequest?.name == "search")
            } else if hasToolMessage, !hasRecipientTag {
                #expect(toolChannel != nil)
                #expect(toolChannel?.toolRequest == nil)
            }
        }
    }

    private func prefixes(for output: String, tokens: [String]) -> [String] {
        let offsets = splitOffsets(for: output, tokens: tokens)
        return offsets.map { offset in
            let index = output.index(output.startIndex, offsetBy: offset)
            return String(output[..<index])
        }
    }

    private func splitOffsets(for output: String, tokens: [String]) -> [Int] {
        var offsets: Set<Int> = []
        offsets.insert(0)
        offsets.insert(output.count)

        for token in tokens {
            var searchStart = output.startIndex
            while let range = output.range(of: token, range: searchStart..<output.endIndex) {
                let startOffset = output.distance(from: output.startIndex, to: range.lowerBound)
                let endOffset = output.distance(from: output.startIndex, to: range.upperBound)
                offsets.insert(startOffset)
                offsets.insert(endOffset)
                if startOffset > 0 {
                    offsets.insert(startOffset - 1)
                }
                if endOffset < output.count {
                    offsets.insert(endOffset + 1)
                }
                searchStart = range.upperBound
            }
        }

        return offsets.sorted()
    }
}

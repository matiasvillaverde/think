import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

@Suite("Kimi Output Parser Tests")
internal struct KimiOutputParserTests {
    @Test("Parses tool calls, commentary preamble, and final content")
    func testKimiToolCallsAndFinal() async throws {
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
            "I will call tools.",
            "<|tool_calls_section_begin|>",
            "<|tool_call_begin|>functions.search:0",
            "<|tool_call_argument_begin|>{\"q\":\"x\"}<|tool_call_end|>",
            "<|tool_call_begin|>functions.weather:1",
            "<|tool_call_argument_begin|>{\"city\":\"SF\"}<|tool_call_end|>",
            "<|tool_calls_section_end|>",
            "Here is the answer."
        ].joined()

        let result = try await contextBuilder.process(output: output, model: model)

        #expect(result.channels.count == 4)
        #expect(result.channels[0].type == .commentary)
        #expect(result.channels[0].content == "I will call tools.")
        #expect(result.channels[1].type == .tool)
        #expect(result.channels[1].toolRequest?.name == "search")
        #expect(result.channels[1].recipient == "functions.search")
        #expect(result.channels[2].type == .tool)
        #expect(result.channels[2].toolRequest?.name == "weather")
        #expect(result.channels[2].recipient == "functions.weather")
        #expect(result.channels[3].type == .final)
        #expect(result.channels[3].content == "Here is the answer.")
    }

    @Test("Parses final content without tool calls")
    func testKimiFinalOnly() async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: .llama
        )

        let output = "Hello from Kimi."
        let result = try await contextBuilder.process(output: output, model: model)

        #expect(result.channels.count == 1)
        #expect(result.channels.first?.type == .final)
        #expect(result.channels.first?.content == "Hello from Kimi.")
    }

    @Test("Parses tool calls without preamble or final")
    func testKimiToolCallsOnly() async throws {
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
            "<|tool_calls_section_begin|>",
            "<|tool_call_begin|>functions.search:0",
            "<|tool_call_argument_begin|>{\"q\":\"x\"}<|tool_call_end|>",
            "<|tool_calls_section_end|>"
        ].joined()

        let result = try await contextBuilder.process(output: output, model: model)

        #expect(result.channels.count == 1)
        #expect(result.channels.first?.type == .tool)
        #expect(result.channels.first?.toolRequest?.name == "search")
    }

    @Test("Ignores incomplete tool call sections for streaming safety")
    func testKimiIncompleteToolCallIgnored() async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: .llama
        )

        let output =
            "Preparing..." +
            "<|tool_calls_section_begin|>" +
            "<|tool_call_begin|>functions.search:0<|tool_call_argument_begin|>{\"q\":\"x\"}"

        let result = try await contextBuilder.process(output: output, model: model)

        #expect(result.channels.count == 1)
        #expect(result.channels.first?.type == .commentary)
        #expect(result.channels.first?.content == "Preparing...")
    }

    @Test("Ignores tool return blocks when output is tool-only")
    func testKimiToolReturnBlocksRemoved() async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: .llama
        )

        let output =
            "## Return of call_1\nresult" +
            "\n## Return of call_2\nother"

        let result = try await contextBuilder.process(output: output, model: model)

        #expect(result.channels.isEmpty)
    }
}

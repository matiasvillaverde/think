import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

@Suite("Kimi Output Parser Edge Tests")
internal struct KimiOutputParserEdgeTests {
    @Test("Parses tool calls without functions prefix")
    func testToolIdWithoutFunctionsPrefix() async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: .llama,
            locationKind: .huggingFace,
        )

        let output = [
            "<|tool_calls_section_begin|>",
            "<|tool_call_begin|>search:0",
            "<|tool_call_argument_begin|>{\"q\":\"x\"}<|tool_call_end|>",
            "<|tool_calls_section_end|>"
        ].joined()

        let result = try await contextBuilder.process(output: output, model: model)

        #expect(result.channels.count == 1)
        #expect(result.channels[0].type == .tool)
        #expect(result.channels[0].recipient == "functions.search")
        #expect(result.channels[0].toolRequest?.name == "search")
    }

    @Test("Parses multiple tool sections")
    func testMultipleToolSections() async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: .llama,
            locationKind: .huggingFace,
        )

        let output = [
            "<|tool_calls_section_begin|>",
            "<|tool_call_begin|>functions.search:0",
            "<|tool_call_argument_begin|>{\"q\":\"x\"}<|tool_call_end|>",
            "<|tool_calls_section_end|>",
            "<|tool_calls_section_begin|>",
            "<|tool_call_begin|>functions.weather:1",
            "<|tool_call_argument_begin|>{\"city\":\"SF\"}<|tool_call_end|>",
            "<|tool_calls_section_end|>"
        ].joined()

        let result = try await contextBuilder.process(output: output, model: model)

        #expect(result.channels.count == 2)
        #expect(result.channels[0].toolRequest?.name == "search")
        #expect(result.channels[1].toolRequest?.name == "weather")
    }
}

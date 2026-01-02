import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

@Suite("Kimi Output Streaming Tests")
internal struct KimiOutputStreamingTests {
    @Test("Streaming tool section keeps commentary and adds tools when complete")
    func testStreamingToolSection() async throws {
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

        let part1 = "Preparing...<|tool_calls_section_begin|>"
        let result1 = try await contextBuilder.process(output: part1, model: model)
        #expect(result1.channels.count == 1)
        #expect(result1.channels[0].type == .commentary)
        #expect(result1.channels[0].content == "Preparing...")

        let part2 = [
            part1,
            "<|tool_call_begin|>functions.search:0",
            "<|tool_call_argument_begin|>{\"q\":\"x\"}"
        ].joined()
        let result2 = try await contextBuilder.process(output: part2, model: model)
        #expect(result2.channels.count == 1)
        #expect(result2.channels[0].type == .commentary)

        let part3 = part2 + "<|tool_call_end|><|tool_calls_section_end|>"
        let result3 = try await contextBuilder.process(output: part3, model: model)
        #expect(result3.channels.count == 2)
        #expect(result3.channels[1].type == .tool)
        #expect(result3.channels[1].toolRequest?.name == "search")

        let part4 = part3 + "Final"
        let result4 = try await contextBuilder.process(output: part4, model: model)
        #expect(result4.channels.count == 3)
        #expect(result4.channels[2].type == .final)
        #expect(result4.channels[2].content == "Final")
    }
}

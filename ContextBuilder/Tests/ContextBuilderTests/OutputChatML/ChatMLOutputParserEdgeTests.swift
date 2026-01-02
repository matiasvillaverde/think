import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

@Suite("ChatML Output Parser Edge Tests")
internal struct ChatMLOutputParserEdgeTests {
    @Test("Parses multiple tool calls")
    func testMultipleToolCalls() async throws {
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
            "<commentary>Do it</commentary>",
            "<tool_call>{\"name\":\"search\",\"arguments\":{\"q\":\"x\"}}</tool_call>",
            "<tool_call>{\"name\":\"weather\",\"arguments\":{\"city\":\"SF\"}}</tool_call>",
            "Final"
        ].joined()

        let result = try await contextBuilder.process(output: output, model: model)

        #expect(result.channels.count == 4)
        #expect(result.channels[0].type == .commentary)
        #expect(result.channels[1].type == .tool)
        #expect(result.channels[1].toolRequest?.name == "search")
        #expect(result.channels[2].type == .tool)
        #expect(result.channels[2].toolRequest?.name == "weather")
        #expect(result.channels[3].type == .final)
        #expect(result.channels[3].content == "Final")
    }

    @Test("Empty commentary tags do not create channel")
    func testEmptyCommentaryIgnored() async throws {
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

        let output = "<commentary>\n</commentary>Final"
        let result = try await contextBuilder.process(output: output, model: model)

        #expect(result.channels.count == 1)
        #expect(result.channels[0].type == .final)
        #expect(result.channels[0].content == "Final")
    }
}

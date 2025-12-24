import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

@Suite("ChatML Streaming Edge Tests")
internal struct ChatMLStreamingEdgeTests {
    @Test("Streaming partial tool call does not create tool until complete")
    func testPartialToolCallStreaming() async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: .llama
        )

        let part1 = "<commentary>Use tool</commentary><tool_call>{\"name\":\"search\""
        let result1 = try await contextBuilder.process(output: part1, model: model)
        #expect(result1.channels.count == 1)
        #expect(result1.channels[0].type == .commentary)

        let part2 = [
            part1,
            ",\"arguments\":{\"q\":\"x\"}}"
        ].joined()
        let result2 = try await contextBuilder.process(output: part2, model: model)
        #expect(result2.channels.count == 1)
        #expect(result2.channels[0].type == .commentary)

        let part3 = [
            part2,
            "</tool_call>Final"
        ].joined()
        let result3 = try await contextBuilder.process(output: part3, model: model)
        #expect(result3.channels.count == 3)
        #expect(result3.channels[1].type == .tool)
        #expect(result3.channels[1].toolRequest?.name == "search")
        #expect(result3.channels[2].type == .final)
        #expect(result3.channels[2].content == "Final")
    }
}

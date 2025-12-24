import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

@Suite("Harmony Output Streaming Edge Tests")
internal struct HarmonyOutputStreamingEdgeTests {
    @Test("Streaming partial final channel stays available")
    func testPartialFinalChannelStreaming() async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: .harmony
        )

        let part1 = "<|channel|>analysis<|message|>Thinking<|return|>"
        let result1 = try await contextBuilder.process(output: part1, model: model)
        #expect(result1.channels.count == 1)
        #expect(result1.channels[0].type == .analysis)

        let part2 = [
            part1,
            "<|channel|>final<|message|>Partial"
        ].joined()
        let result2 = try await contextBuilder.process(output: part2, model: model)
        #expect(result2.channels.count == 2)
        #expect(result2.channels[1].type == .final)
        #expect(result2.channels[1].content == "Partial")

        let part3 = [
            part2,
            "<|return|>"
        ].joined()
        let result3 = try await contextBuilder.process(output: part3, model: model)
        #expect(result3.channels.count == 2)
        #expect(result3.channels[1].content == "Partial")
    }

    @Test("Streaming partial tool channel yields tool request when complete")
    func testPartialToolChannelStreaming() async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: .harmony
        )

        let part1 = "<|channel|>tool<|message|>{\"q\":\"x\"}"
        let result1 = try await contextBuilder.process(output: part1, model: model)
        #expect(result1.channels.count == 1)
        #expect(result1.channels[0].type == .tool)
        #expect(result1.channels[0].toolRequest == nil)

        let part2 = [
            part1,
            "<|recipient|>functions.search<|call|>"
        ].joined()
        let result2 = try await contextBuilder.process(output: part2, model: model)
        #expect(result2.channels.count == 1)
        #expect(result2.channels[0].type == .tool)
        #expect(result2.channels[0].toolRequest?.name == "search")
        #expect(result2.channels[0].toolRequest?.arguments == "{\"q\":\"x\"}")
    }
}

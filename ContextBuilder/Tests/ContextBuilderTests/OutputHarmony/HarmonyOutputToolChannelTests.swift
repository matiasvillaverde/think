import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

@Suite("Harmony Output Tool Channel Tests")
internal struct HarmonyOutputToolChannelTests {
    @Test("Parses tool channel with recipient and tool request")
    func testToolChannelParsing() async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: .harmony,
            locationKind: .huggingFace,
        )

        let output = [
            "<|channel|>commentary<|message|>Calling tool...<|return|>",
            "<|channel|>tool<|message|>{\"q\":\"x\"}<|recipient|>functions.search<|call|>",
            "<|channel|>final<|message|>Done<|return|>"
        ].joined()

        let result = try await contextBuilder.process(output: output, model: model)

        #expect(result.channels.count == 3)
        let toolChannel = result.channels[1]
        #expect(toolChannel.type == .tool)
        #expect(toolChannel.recipient == "functions.search")
        #expect(toolChannel.toolRequest?.name == "search")
        #expect(toolChannel.toolRequest?.arguments == "{\"q\":\"x\"}")
    }

    @Test("Parses partial trailing channel")
    func testPartialTrailingChannel() async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: .harmony,
            locationKind: .huggingFace,
        )

        let output = [
            "<|channel|>analysis<|message|>Thinking<|return|>",
            "<|channel|>final<|message|>Partial"
        ].joined()

        let result = try await contextBuilder.process(output: output, model: model)

        #expect(result.channels.count == 2)
        #expect(result.channels[1].type == .final)
        #expect(result.channels[1].content == "Partial")
    }
}

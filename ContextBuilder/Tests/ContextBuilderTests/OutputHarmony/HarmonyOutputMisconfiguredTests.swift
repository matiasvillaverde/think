import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

@Suite("Harmony Output Misconfiguration Tests")
internal struct HarmonyOutputMisconfiguredTests {
    private let harmonyOutput: String =
        "<|start|>assistant" +
        "<|channel|>analysis<|message|>User says \"What is going on?\"" +
        "<|return|>" +
        "<|channel|>final<|message|>Hello there" +
        "<|return|>"

    @Test("Harmony parser strips channel tokens and splits channels")
    func testHarmonyArchitectureParsesChannels() async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: .harmony
        )

        let result = try await contextBuilder.process(output: harmonyOutput, model: model)

        #expect(result.channels.count == 2)
        #expect(result.channels.first?.type == .analysis)
        #expect(result.channels.last?.type == .final)
        #expect(result.channels.last?.content == "Hello there")
        #expect(result.channels.last?.content.contains("<|channel|>") == false)
    }

    @Test("Format detector routes Harmony output even if architecture is wrong")
    func testWrongArchitectureStillParsesHarmony() async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: .llama
        )

        let result = try await contextBuilder.process(output: harmonyOutput, model: model)

        #expect(result.channels.count == 2)
        #expect(result.channels.first?.type == .analysis)
        #expect(result.channels.last?.type == .final)
        #expect(result.channels.last?.content == "Hello there")
    }
}

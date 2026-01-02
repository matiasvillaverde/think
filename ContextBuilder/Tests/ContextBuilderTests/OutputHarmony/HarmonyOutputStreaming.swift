import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

@Suite("Harmony Test: Harmony Output Streaming")
internal struct HarmonyOutputStreaming {
    @Test(
        "Validates harmony_output_streaming",
        arguments: [Architecture.harmony, Architecture.gpt]
    )
    func test(architecture: Architecture) async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)

        let expectedOutput = try loadResource("harmony_output_streaming")

        // For output tests, we need to parse/process the output
        // This is a placeholder - actual implementation depends on test specifics
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: architecture,
            locationKind: .huggingFace,
        )

        // Read the input from the file to determine what to process
        let result = try await contextBuilder.process(
            output: expectedOutput,
            model: model
        )

        #expect(result.channels.count == 3)
        #expect(result.channels[0].type == .analysis)
        #expect(result.channels[0].content == "Let me analyze this step by step.")
        #expect(result.channels[1].type == .commentary)
        #expect(result.channels[1].content == "The calculation is straightforward.")
        #expect(result.channels[2].type == .final)
        #expect(result.channels[2].content == "The answer is 4.")
    }

    private func loadResource(_ name: String) throws -> String {
        guard let url = Bundle.module.url(
            forResource: "Examples-Harmony/\(name)",
            withExtension: "txt"
        ) else {
            throw ContextBuilderTestError.resourceNotFound("Examples-Harmony/\(name).txt")
        }

        return try String(contentsOf: url, encoding: .utf8)
    }
}

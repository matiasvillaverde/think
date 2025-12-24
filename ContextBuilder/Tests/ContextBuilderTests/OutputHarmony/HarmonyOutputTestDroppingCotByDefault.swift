import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

@Suite("Harmony Test: Harmony Output Test Dropping Cot By Default")
internal struct HarmonyOutputTestDroppingCotByDefault {
    @Test(
        "Validates harmony_output_test_dropping_cot_by_default",
        arguments: [Architecture.harmony, Architecture.gpt]
    )
    func test(architecture: Architecture) async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)

        let expectedOutput = try loadResource("harmony_output_test_dropping_cot_by_default")

        // For output tests, we need to parse/process the output
        // This is a placeholder - actual implementation depends on test specifics
        let model = SendableModel(
            id: UUID(),
            ramNeeded: 1_000_000_000,
            modelType: .language,
            location: "test-model",
            architecture: architecture
        )

        // Read the input from the file to determine what to process
        let result = try await contextBuilder.process(
            output: expectedOutput,
            model: model
        )

        #expect(result.channels.count == 1)
        #expect(result.channels[0].type == .final)
        #expect(result.channels[0].content == "2 + 2 equals 4.")
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

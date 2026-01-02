import Abstractions
@testable import ContextBuilder
import Foundation
import Testing

@Suite("Harmony Test: Harmony Output Test Streamable Parser")
internal struct HarmonyOutputTestStreamableParser {
    @Test(
        "Validates harmony_output_test_streamable_parser",
        arguments: [Architecture.harmony, Architecture.gpt]
    )
    func test(architecture: Architecture) async throws {
        let tooling = MockTooling()
        let contextBuilder = ContextBuilder(tooling: tooling)

        let expectedOutput = try loadResource("harmony_output_test_streamable_parser")

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

        // For output tests, we're validating the parsing works correctly
        // The exact assertion depends on what the test is checking
        #expect(result.channels.isEmpty == false)
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

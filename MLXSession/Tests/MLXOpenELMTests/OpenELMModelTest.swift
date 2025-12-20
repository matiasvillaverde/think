import Foundation
@testable import MLXSession
import MLXSessionTestUtilities
import Testing

@Suite("OpenELM Model Generation Tests")
struct OpenELMModelTest {
    let baseTest = BaseModelTest()

    @Test("Generate text with OpenELM-270M model")
    func testOpenELMGeneration() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "OpenELM-270M-Instruct",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "OpenELM-270M-Instruct",
            prompt: "Once upon a time",
            expectedTokens: ["there", "was", "in", "a"],
            maxTokens: 10
        )
    }
}

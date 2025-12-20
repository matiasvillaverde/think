import Foundation
@testable import MLXSession
import MLXSessionTestUtilities
import Testing

@Suite("Mistral Model Generation Tests")
struct MistralModelTest {
    let baseTest = BaseModelTest()

    @Test("Generate text with Mistral-7B model")
    func testMistralGeneration() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "Mistral-7B-Instruct-v0.2-4bit",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "Mistral-7B-Instruct",
            prompt: "What is machine learning?",
            expectedTokens: ["machine", "learning", "data", "algorithm"],
            maxTokens: 10
        )
    }
}

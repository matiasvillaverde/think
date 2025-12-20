import Foundation
@testable import MLXSession
import MLXSessionTestUtilities
import Testing

@Suite("Gemma Model Generation Tests")
struct GemmaModelTest {
    let baseTest = BaseModelTest()

    @Test("Generate text with Gemma-3-1B model")
    func testGemma3Generation() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "gemma-3-1b-it-qat-4bit",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "gemma-3-1b-it",
            prompt: "Write a haiku about coding:",
            expectedTokens: ["code", "line", "bug", "function"],
            maxTokens: 20
        )
    }

    @Test("Generate text with Gemma-3n model")
    func testGemma3nGeneration() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "gemma-3n-E2B-it-lm-4bit",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "gemma-3n-E2B-it",
            prompt: "The weather today is",
            expectedTokens: ["sunny", "cloudy", "warm", "cold"],
            maxTokens: 10
        )
    }
}

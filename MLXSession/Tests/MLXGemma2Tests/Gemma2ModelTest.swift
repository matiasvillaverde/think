import Foundation
@testable import MLXSession
import MLXSessionTestUtilities
import Testing

@Suite("Gemma-2 Model Generation Tests")
struct Gemma2ModelTest {
    let baseTest = BaseModelTest()

    @Test("Generate text with Gemma-2-2B model")
    func testGemma2Generation() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "gemma-2-2b-it-4bit",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "gemma-2-2b-it",
            prompt: "List three programming languages:",
            expectedTokens: ["python", "java", "javascript", "swift"],
            maxTokens: 15
        )
    }

    @Test("Gemma-2 list house pets")
    func testGemma2ListHousePets() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "gemma-2-2b-it-4bit",
            in: Bundle.module
        ) else {
            return
        }

        let result = try await baseTest.runGenerationForAssertion(
            modelURL: modelURL,
            modelName: "gemma-2-2b-it",
            prompt: "List 5 common house pets:",
            maxTokens: 30
        )

        #expect(result.lowercased().contains("dog"))
    }

    @Test("Gemma-2 simple math")
    func testGemma2SimpleMath() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "gemma-2-2b-it-4bit",
            in: Bundle.module
        ) else {
            return
        }

        let result = try await baseTest.runGenerationForAssertion(
            modelURL: modelURL,
            modelName: "gemma-2-2b-it",
            prompt: "What is 7 + 8?",
            maxTokens: 10
        )

        #expect(result.contains("15"))
    }
}

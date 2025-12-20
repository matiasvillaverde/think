import Foundation
@testable import MLXSession
import MLXSessionTestUtilities
import Testing

@Suite("Deepseek Model Generation Tests")
struct DeepseekModelTest {
    let baseTest = BaseModelTest()

    @Test("Generate text with DeepSeek-R1-Distill model")
    func testDeepseekGeneration() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "DeepSeek-R1-Distill-Qwen-7B-4bit",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "DeepSeek-R1-Distill-Qwen-7B",
            prompt: "What is deep learning?",
            expectedTokens: ["neural", "network", "learning", "deep"],
            maxTokens: 20
        )
    }

    @Test("DeepSeek list house pets")
    func testDeepseekListHousePets() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "DeepSeek-R1-Distill-Qwen-7B-4bit",
            in: Bundle.module
        ) else {
            return
        }

        let result = try await baseTest.runGenerationForAssertion(
            modelURL: modelURL,
            modelName: "DeepSeek-R1-Distill-Qwen-7B",
            prompt: "List 5 common house pets:",
            maxTokens: 30
        )

        #expect(result.lowercased().contains("dog"))
    }

    @Test("DeepSeek simple math")
    func testDeepseekSimpleMath() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "DeepSeek-R1-Distill-Qwen-7B-4bit",
            in: Bundle.module
        ) else {
            return
        }

        let result = try await baseTest.runGenerationForAssertion(
            modelURL: modelURL,
            modelName: "DeepSeek-R1-Distill-Qwen-7B",
            prompt: "What is 10 - 3?",
            maxTokens: 10
        )

        #expect(result.contains("7"))
    }
}

import Foundation
@testable import MLXSession
import MLXSessionTestUtilities
import Testing

@Suite("SmolLM Model Generation Tests")
struct SmolLMModelTest {
    let baseTest = BaseModelTest()

    @Test("Generate text with SmolLM3-3B model")
    func testSmolLMGeneration() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "SmolLM3-3B-4bit",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "SmolLM3-3B",
            prompt: "The quick brown fox",
            expectedTokens: ["jumps", "jumped", "over", "the"],
            maxTokens: 10
        )
    }

    @Test("Generate text with LFM2-1.2B model")
    func testLFM2Generation() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "LFM2-1.2B-4bit",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "LFM2-1.2B",
            prompt: "Today's weather is",
            expectedTokens: ["sunny", "cloudy", "warm", "nice"],
            maxTokens: 10
        )
    }
}

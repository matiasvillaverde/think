import Foundation
@testable import MLXSession
import MLXSessionTestUtilities
import Testing

@Suite("InternLM Model Generation Tests")
struct InternLMModelTest {
    let baseTest = BaseModelTest()

    @Test("Generate text with InternLM2-1.8B model")
    func testInternLMGeneration() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "internlm2-chat-1_8b-4bit",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "internlm2-chat-1.8b",
            prompt: "Explain quantum computing:",
            expectedTokens: ["quantum", "qubit", "computer", "computing"],
            maxTokens: 15
        )
    }
}

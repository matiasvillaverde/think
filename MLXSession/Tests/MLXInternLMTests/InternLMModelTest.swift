import Foundation
@testable import MLXSession
import MLXSessionTestUtilities
import Testing

@Suite("InternLM Model Generation Tests")
struct InternLMModelTest {
    let baseTest = BaseModelTest()

    @Test("Generate text with InternLM2.5-7B model")
    func testInternLMGeneration() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "internlm2_5-7b-chat-4bit",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "internlm2_5-7b-chat",
            prompt: "Explain quantum computing:",
            expectedTokens: ["quantum", "qubit", "computer", "computing"],
            maxTokens: 15
        )
    }
}

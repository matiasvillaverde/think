import Foundation
@testable import MLXSession
import MLXSessionTestUtilities
import Testing

@Suite("Phi-3 Model Generation Tests")
struct Phi3ModelTest {
    let baseTest = BaseModelTest()

    @Test("Generate text with Phi-3.5-mini model")
    func testPhi3Generation() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "Phi-3.5-mini-instruct-4bit",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "Phi-3.5-mini-instruct",
            prompt: "What is artificial intelligence?",
            expectedTokens: ["artificial", "intelligence", "ai", "computer"],
            maxTokens: 10
        )
    }
}

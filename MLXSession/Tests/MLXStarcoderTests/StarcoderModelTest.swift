import Foundation
@testable import MLXSession
import MLXSessionTestUtilities
import Testing

@Suite("Starcoder Model Generation Tests")
struct StarcoderModelTest {
    let baseTest = BaseModelTest()

    @Test("Generate code with Starcoder2-3B model")
    func testStarcoderGeneration() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "starcoder2-3b-4bit",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "starcoder2-3b",
            prompt: "def fibonacci(n):",
            expectedTokens: ["if", "return", "def", "fibonacci"],
            maxTokens: 20
        )
    }
}

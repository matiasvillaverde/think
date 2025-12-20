import Foundation
@testable import MLXSession
import MLXSessionTestUtilities
import Testing

@Suite("ERNIE Model Generation Tests")
struct ErnieModelTest {
    let baseTest = BaseModelTest()

    @Test("Generate text with ERNIE-4.5-0.3B model")
    func testErnieGeneration() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "ERNIE-4.5-0.3B-PT-bf16-ft",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "ERNIE-4.5-0.3B",
            prompt: "Natural language processing is",
            expectedTokens: ["language", "processing", "nlp", "text"],
            maxTokens: 10
        )
    }
}

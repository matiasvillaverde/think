import Foundation
@testable import MLXSession
import MLXSessionTestUtilities
import Testing

@Suite("Phi Model Generation Tests")
struct PhiModelTest {
    let baseTest = BaseModelTest()

    @Test("Generate text with Phi-2 model")
    func testPhiGeneration() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "phi-2-hf-4bit-mlx",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "Phi-2",
            prompt: "The meaning of life is",
            expectedTokens: ["to", "the", "is"],
            maxTokens: 10
        )
    }
}

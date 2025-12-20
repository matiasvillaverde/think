import Foundation
@testable import MLXSession
import MLXSessionTestUtilities
import Testing

@Suite("Phi-MoE Model Generation Tests")
struct PhiMoEModelTest {
    let baseTest = BaseModelTest()

    @Test("Generate text with Phi-3.5-MoE model")
    func testPhiMoEGeneration() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "Phi-3.5-MoE-instruct-4bit",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "Phi-3.5-MoE-instruct",
            prompt: "Explain mixture of experts:",
            expectedTokens: ["mixture", "expert", "model", "network"],
            maxTokens: 15
        )
    }
}

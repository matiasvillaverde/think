import Foundation
@testable import MLXSession
import MLXSessionTestUtilities
import Testing

@Suite("LFM2 MoE Model Generation Tests")
struct LFM2MoEModelTest {
    let baseTest = BaseModelTest()

    @Test("Generate text with LFM2-8B-A1B model")
    func testLFM2MoEGeneration() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "LFM2-8B-A1B-4bit",
            in: Bundle.module
        ) else {
            return
        }

        let text = try await baseTest.runGenerationForAssertion(
            modelURL: modelURL,
            modelName: "LFM2-8B-A1B-4bit",
            prompt: "The quick brown fox",
            maxTokens: 12
        )

        #expect(!text.isEmpty)
    }
}

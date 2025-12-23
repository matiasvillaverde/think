import Foundation
@testable import MLXSession
import MLXSessionTestUtilities
import Testing

@Suite("Mamba Model Generation Tests")
struct MambaModelTest {
    let baseTest = BaseModelTest()

    @Test("Generate text with Mamba-130m model")
    func testMambaGeneration() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "mamba-130m-hf-f32",
            in: Bundle.module
        ) else {
            return
        }

        let text = try await baseTest.runGenerationForAssertion(
            modelURL: modelURL,
            modelName: "mamba-130m-hf-f32",
            prompt: "The quick brown fox",
            maxTokens: 12
        )

        #expect(!text.isEmpty)
    }
}

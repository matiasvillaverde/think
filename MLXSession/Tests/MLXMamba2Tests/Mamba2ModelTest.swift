import Foundation
@testable import MLXSession
import MLXSessionTestUtilities
import Testing

@Suite("Mamba2 Model Generation Tests")
struct Mamba2ModelTest {
    let baseTest = BaseModelTest()

    @Test("Generate text with Mamba2-370m model")
    func testMamba2Generation() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "mamba2-370m",
            in: Bundle.module
        ) else {
            return
        }

        let text = try await baseTest.runGenerationForAssertion(
            modelURL: modelURL,
            modelName: "mamba2-370m",
            prompt: "The quick brown fox",
            maxTokens: 12
        )

        #expect(!text.isEmpty)
    }
}

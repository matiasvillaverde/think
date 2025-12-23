import Foundation
@testable import MLXSession
import MLXSessionTestUtilities
import Testing

@Suite("Granite Hybrid MoE Model Generation Tests")
struct GraniteHybridModelTest {
    let baseTest = BaseModelTest()

    @Test("Generate text with Granite 4.0 H Tiny model")
    func testGraniteHybridGeneration() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "granite-4.0-h-tiny-4bit",
            in: Bundle.module
        ) else {
            return
        }

        let text = try await baseTest.runGenerationForAssertion(
            modelURL: modelURL,
            modelName: "granite-4.0-h-tiny-4bit",
            prompt: "The quick brown fox",
            maxTokens: 12
        )

        #expect(!text.isEmpty)
    }
}

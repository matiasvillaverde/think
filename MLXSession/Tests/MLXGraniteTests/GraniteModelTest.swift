import Foundation
@testable import MLXSession
import MLXSessionTestUtilities
import Testing

@Suite("Granite Model Generation Tests")
struct GraniteModelTest {
    let baseTest = BaseModelTest()

    @Test("Generate text with Granite-3.3-2B model")
    func testGraniteGeneration() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "granite-3.3-2b-instruct-4bit",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "granite-3.3-2b-instruct",
            prompt: "Explain cloud computing:",
            expectedTokens: ["cloud", "server", "computing", "data"],
            maxTokens: 15
        )
    }
}

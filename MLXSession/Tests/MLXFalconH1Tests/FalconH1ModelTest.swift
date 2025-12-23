import Foundation
@testable import MLXSession
import MLXSessionTestUtilities
import Testing

@Suite("Falcon H1 Model Generation Tests")
struct FalconH1ModelTest {
    let baseTest = BaseModelTest()

    @Test("Generate text with Falcon-H1-0.5B model")
    func testFalconH1Generation() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "Falcon-H1-0.5B-Instruct-4bit",
            in: Bundle.module
        ) else {
            return
        }

        let text = try await baseTest.runGenerationForAssertion(
            modelURL: modelURL,
            modelName: "Falcon-H1-0.5B-Instruct-4bit",
            prompt: "The quick brown fox",
            maxTokens: 12
        )

        #expect(!text.isEmpty)
    }
}

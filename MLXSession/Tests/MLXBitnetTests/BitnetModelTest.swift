import Foundation
@testable import MLXSession
import MLXSessionTestUtilities
import Testing

@Suite("Bitnet Model Generation Tests")
struct BitnetModelTest {
    let baseTest = BaseModelTest()

    @Test("Generate text with Bitnet-1.58-2B model")
    func testBitnetGeneration() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "bitnet-b1.58-2B-4T-4bit",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "bitnet-b1.58-2B",
            prompt: "Binary neural networks are",
            expectedTokens: ["binary", "network", "neural", "bit"],
            maxTokens: 10
        )
    }

    @Test("Generate text with Bitnet technical explanation")
    func testBitnetTechnicalGeneration() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "bitnet-b1.58-2B-4T-4bit",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "bitnet-b1.58-2B",
            prompt: "Explain how 1.58-bit quantization works:",
            expectedTokens: ["quantization", "bit", "weight", "values"],
            maxTokens: 20
        )
    }

    @Test("Generate text with Bitnet creative writing")
    func testBitnetCreativeGeneration() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "bitnet-b1.58-2B-4T-4bit",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "bitnet-b1.58-2B",
            prompt: "Write a short story about efficient computing:",
            expectedTokens: ["story", "computing", "efficient", "technology"],
            maxTokens: 25
        )
    }

    @Test("Generate text with Bitnet question answering")
    func testBitnetQuestionAnswering() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "bitnet-b1.58-2B-4T-4bit",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "bitnet-b1.58-2B",
            prompt: "Q: What are the benefits of binary neural networks? A:",
            expectedTokens: ["binary", "benefits", "efficiency", "speed"],
            maxTokens: 15
        )
    }

    @Test("List house pets with string assertion")
    func testBitnetListHousePets() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "bitnet-b1.58-2B-4T-4bit",
            in: Bundle.module
        ) else {
            return
        }

        let result = try await baseTest.runGenerationForAssertion(
            modelURL: modelURL,
            modelName: "bitnet-b1.58-2B",
            prompt: "List 5 common house pets:",
            maxTokens: 30
        )

        #expect(result.lowercased().contains("dog"))
    }

    @Test("Simple math with string assertion")
    func testBitnetSimpleMath() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "bitnet-b1.58-2B-4T-4bit",
            in: Bundle.module
        ) else {
            return
        }

        let result = try await baseTest.runGenerationForAssertion(
            modelURL: modelURL,
            modelName: "bitnet-b1.58-2B",
            prompt: "What is 2 + 2?",
            maxTokens: 10
        )

        #expect(result.contains("4"))
    }
}

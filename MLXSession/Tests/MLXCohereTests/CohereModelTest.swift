import Foundation
@testable import MLXSession
import MLXSessionTestUtilities
import Testing

@Suite("Cohere Model Generation Tests")
struct CohereModelTest {
    let baseTest = BaseModelTest()

    @Test("Generate text with Exaone-4.0 model")
    func testCohereGeneration() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "exaone-4.0-1.2b-4bit",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "exaone-4.0-1.2b",
            prompt: "Summarize the following text:",
            expectedTokens: ["summary", "text", "following", "the"],
            maxTokens: 10
        )
    }

    @Test("Generate text with Exaone-4.0 creative writing")
    func testCohereCreativeGeneration() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "exaone-4.0-1.2b-4bit",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "exaone-4.0-1.2b",
            prompt: "Write a haiku about artificial intelligence:",
            expectedTokens: ["haiku", "intelligence", "artificial", "lines", "syllables"],
            maxTokens: 20
        )
    }

    @Test("Generate text with Exaone-4.0 model")
    func testExaoneGeneration() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "exaone-4.0-1.2b-4bit",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "exaone-4.0-1.2b",
            prompt: "What is machine learning?",
            expectedTokens: ["machine", "learning", "algorithm", "data"],
            maxTokens: 15
        )
    }

    @Test("Generate text with Exaone-4.0 reasoning")
    func testExaoneReasoning() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "exaone-4.0-1.2b-4bit",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "exaone-4.0-1.2b",
            prompt: "Q: What is 2+2? A:",
            expectedTokens: ["4", "four", "two", "plus"],
            maxTokens: 10
        )
    }

    @Test("Exaone list house pets")
    func testExaoneListHousePets() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "exaone-4.0-1.2b-4bit",
            in: Bundle.module
        ) else {
            return
        }

        let result = try await baseTest.runGenerationForAssertion(
            modelURL: modelURL,
            modelName: "exaone-4.0-1.2b",
            prompt: "List 5 common house pets:",
            maxTokens: 30
        )

        #expect(result.lowercased().contains("dog"))
    }

    @Test("Exaone simple math")
    func testExaoneSimpleMath() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "exaone-4.0-1.2b-4bit",
            in: Bundle.module
        ) else {
            return
        }

        let result = try await baseTest.runGenerationForAssertion(
            modelURL: modelURL,
            modelName: "exaone-4.0-1.2b",
            prompt: "5 + 3 =",
            maxTokens: 15
        )

        let normalized = result.lowercased()
        #expect(normalized.contains("8") || normalized.contains("eight"))
    }
}

import Foundation
@testable import MLXSession
import MLXSessionTestUtilities
import Testing

@Suite("Llama Model Generation Tests")
struct LlamaModelTest {
    let baseTest = BaseModelTest()

    @Test("Generate text with Llama-3.2-1B model")
    func testLlamaGeneration() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "Llama-3.2-1B-Instruct-4bit",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "Llama-3.2-1B-Instruct",
            prompt: "The capital of France is",
            expectedTokens: ["paris"],
            maxTokens: 5
        )
    }

    @Test("Generate text with Llama instruction following")
    func testLlamaInstructionFollowing() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "Llama-3.2-1B-Instruct-4bit",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "Llama-3.2-1B-Instruct",
            prompt: "Explain machine learning in simple terms:",
            expectedTokens: ["machine", "learning", "data", "algorithm"],
            maxTokens: 20
        )
    }

    @Test("Generate text with Llama creative writing")
    func testLlamaCreativeGeneration() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "Llama-3.2-1B-Instruct-4bit",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "Llama-3.2-1B-Instruct",
            prompt: "Write a limerick about AI:",
            expectedTokens: ["limerick", "ai", "there", "once"],
            maxTokens: 30
        )
    }

    @Test("Generate text with Llama conversation")
    func testLlamaConversation() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "Llama-3.2-1B-Instruct-4bit",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "Llama-3.2-1B-Instruct",
            prompt: "Hello! How are you today?",
            expectedTokens: ["hello", "good", "fine", "today"],
            maxTokens: 15
        )
    }

    @Test("Llama list house pets")
    func testLlamaListHousePets() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "Llama-3.2-1B-Instruct-4bit",
            in: Bundle.module
        ) else {
            return
        }

        let result = try await baseTest.runGenerationForAssertion(
            modelURL: modelURL,
            modelName: "Llama-3.2-1B-Instruct",
            prompt: "Name one common house pet. Answer with exactly one word from this list: " +
                "dog, cat, fish, bird, hamster, rabbit, turtle.",
            maxTokens: 10
        )

        let normalized = result.lowercased()
        let pets = ["dog", "cat", "fish", "bird", "hamster", "rabbit", "turtle"]
        #expect(pets.contains { normalized.contains($0) })
    }

    @Test("Llama simple math")
    func testLlamaSimpleMath() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "Llama-3.2-1B-Instruct-4bit",
            in: Bundle.module
        ) else {
            return
        }

        let result = try await baseTest.runGenerationForAssertion(
            modelURL: modelURL,
            modelName: "Llama-3.2-1B-Instruct",
            prompt: "What is 6 * 4? Answer with only the number.",
            maxTokens: 15
        )

        let normalized = result.lowercased()
        let matcher = try? NSRegularExpression(pattern: "(?<!\\d)24(?!\\d)")
        let hasExactNumber = matcher?.firstMatch(
            in: normalized,
            range: NSRange(normalized.startIndex..., in: normalized)
        ) != nil

        #expect(hasExactNumber || normalized.contains("twenty-four"))
    }
}

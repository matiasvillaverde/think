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
            prompt: "List 5 common house pets:",
            maxTokens: 30
        )

        #expect(result.lowercased().contains("dog"))
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
            prompt: "What is 6 × 4?",
            maxTokens: 10
        )

        #expect(result.contains("24"))
    }
}

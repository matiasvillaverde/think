import Foundation
@testable import MLXSession
import MLXSessionTestUtilities
import Testing

@Suite("Qwen Model Generation Tests")
struct QwenModelTest {
    let baseTest = BaseModelTest()

    @Test("Generate text with Qwen3-0.6B model")
    func testQwen3Generation() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "Qwen3-0.6B-4bit",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "Qwen3-0.6B",
            prompt: "Hello, how are you?",
            expectedTokens: ["fine", "good", "well", "great"],
            maxTokens: 10
        )
    }

    @Test("Generate text with Qwen1.5 model")
    func testQwen15Generation() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "Qwen1.5-0.5B-Chat-4bit",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "Qwen1.5-0.5B-Chat",
            prompt: "What is machine learning?",
            expectedTokens: ["algorithm", "data", "model", "learn"],
            maxTokens: 15
        )
    }

    @Test("Generate creative text with Qwen1.5 model")
    func testQwen15CreativeGeneration() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "Qwen1.5-0.5B-Chat-4bit",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "Qwen1.5-0.5B-Chat",
            prompt: "Write a short story about a robot:",
            expectedTokens: ["robot", "machine", "story", "once", "there"],
            maxTokens: 25
        )
    }

    @Test("Test Qwen1.5 question answering")
    func testQwen15QuestionAnswering() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "Qwen1.5-0.5B-Chat-4bit",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "Qwen1.5-0.5B-Chat",
            prompt: "Q: What is the capital of Japan? A:",
            expectedTokens: ["tokyo", "japan", "capital"],
            maxTokens: 10
        )
    }

    @Test("Test Qwen1.5 simple conversation")
    func testQwen15SimpleConversation() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "Qwen1.5-0.5B-Chat-4bit",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "Qwen1.5-0.5B-Chat",
            prompt: "Hello! How are you today?",
            expectedTokens: ["hello", "fine", "good", "well", "thank"],
            maxTokens: 20
        )
    }
}

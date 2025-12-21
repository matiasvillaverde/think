import Foundation
@testable import MLXSession
import MLXSessionTestUtilities
import Testing

@Suite("Deepseek Model Generation Tests")
struct DeepseekModelTest {
    let baseTest = BaseModelTest()

    @Test("Generate text with DeepSeek-R1-Distill model")
    func testDeepseekGeneration() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "DeepSeek-R1-Distill-Qwen-7B-4bit",
            in: Bundle.module
        ) else {
            return
        }

        try await baseTest.runBasicGenerationTest(
            modelURL: modelURL,
            modelName: "DeepSeek-R1-Distill-Qwen-7B",
            prompt: "What is deep learning?",
            expectedTokens: ["neural", "network", "learning", "deep"],
            maxTokens: 20
        )
    }

    @Test("DeepSeek list house pets")
    func testDeepseekListHousePets() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "DeepSeek-R1-Distill-Qwen-7B-4bit",
            in: Bundle.module
        ) else {
            return
        }

        let result = try await baseTest.runGenerationForAssertion(
            modelURL: modelURL,
            modelName: "DeepSeek-R1-Distill-Qwen-7B",
            prompt: "Name one common house pet. Answer with a single word and no reasoning.",
            maxTokens: 60
        )

        let normalized = result.lowercased()
        let pets = [
            "dog", "cat", "fish", "bird", "hamster", "rabbit", "turtle",
            "perro", "gato", "pez", "pajaro", "pájaro", "hámster", "hamster", "conejo", "tortuga"
        ]
        let petsCn = ["狗", "猫", "鱼", "鸟", "仓鼠", "兔", "兔子", "乌龟"]
        let matchesPet = pets.contains { normalized.contains($0) } || petsCn.contains { result.contains($0) }
        #expect(matchesPet)
    }

    @Test("DeepSeek simple math")
    func testDeepseekSimpleMath() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "DeepSeek-R1-Distill-Qwen-7B-4bit",
            in: Bundle.module
        ) else {
            return
        }

        let result = try await baseTest.runGenerationForAssertion(
            modelURL: modelURL,
            modelName: "DeepSeek-R1-Distill-Qwen-7B",
            prompt: "Compute 10 - 3. Answer with a single digit and no reasoning.",
            maxTokens: 60
        )

        let normalized = result.lowercased()
        let matcher = try? NSRegularExpression(pattern: "(?<!\\d)[7７](?!\\d)")
        let hasExactNumber = matcher?.firstMatch(
            in: normalized,
            range: NSRange(normalized.startIndex..., in: normalized)
        ) != nil

        let hasChineseNumeral = normalized.contains("七") || normalized.contains("柒")
        let matchesNumber = hasExactNumber || normalized.contains("seven") || hasChineseNumeral
        #expect(matchesNumber)
    }
}

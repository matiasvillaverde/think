import Abstractions
import Foundation
@testable import LLamaCPP
import Testing

/// Debug test to see what the model actually generates
extension LlamaCPPModelTestSuite {
    @Test("Debug: See what model generates for various prompts")
    internal func testDebugModelGeneration() async throws {
        guard let configuration: ProviderConfiguration = TestHelpers.createTestConfiguration() else {
            return
        }
        let session: LLMSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        for try await _ in preloadStream {
            // Just consume the progress updates
        }

        // Test various prompts to see what the model generates
        let testCases: [(prompt: String, description: String)] = [
            ("The capital of France is", "Capital city completion"),
            ("2 + 2 =", "Simple math"),
            ("Hello", "Greeting response"),
            ("Once upon a time", "Story beginning"),
            ("The color of the sky is", "Color completion"),
            ("One, two, three,", "Number sequence"),
            ("Q: What is water?\nA:", "Question answering")
        ]

        for testCase in testCases {
            print("\n=== Testing: \(testCase.description) ===")
            print("Prompt: '\(testCase.prompt)'")

            let input: LLMInput = LLMInput(
                context: testCase.prompt,
                sampling: SamplingParameters(
                    temperature: 0.0,  // Deterministic
                    topP: 1.0,
                    topK: 1,
                    seed: 42
                ),
                limits: ResourceLimits(maxTokens: 10)
            )

            var generatedText: String = ""
            let stream: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)

            for try await chunk in stream {
                if case .text = chunk.event {
                    generatedText += chunk.text
                }
            }

            print("Generated: '\(generatedText)'")
            print("Generated (escaped): '\(generatedText.debugDescription)'")
            #expect(generatedText.isEmpty == false)
        }

        await session.unload()
    }
}

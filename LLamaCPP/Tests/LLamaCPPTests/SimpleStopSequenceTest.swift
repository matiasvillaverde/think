import Abstractions
import Foundation
@testable import LLamaCPP
import Testing

extension LlamaCPPModelTestSuite {
    @Test("Basic generation without stop sequences")
    internal func testBasicGeneration() async throws {
        let configuration: ProviderConfiguration = try TestHelpers.createTestConfiguration()
        let session: LLMSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        for try await _ in preloadStream {
            // Consume progress
        }

        // Simple prompt without stop sequences first
        let input: LLMInput = LLMInput(
            context: "Hello",
            sampling: SamplingParameters(
                temperature: 0.7,
                topP: 0.9,
                stopSequences: []  // No stop sequences
            ),
            limits: ResourceLimits(maxTokens: 10)
        )

        var generatedText: String = ""
        let stream: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)

        for try await chunk in stream {
            if case .text = chunk.event {
                generatedText += chunk.text
                print("[SIMPLE TEST] Generated: '\(chunk.text)'")
            }
        }

        print("[SIMPLE TEST] Total generated: '\(generatedText)'")
        #expect(!generatedText.isEmpty, "Should generate some text without stop sequences")
    }

    @Test("Generation with simple stop sequence")
    internal func testWithStopSequence() async throws {
        let configuration: ProviderConfiguration = try TestHelpers.createTestConfiguration()
        let session: LLMSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        for try await _ in preloadStream {
            // Consume progress
        }

        // Test with a simple stop sequence
        let input: LLMInput = LLMInput(
            context: "Count to ten: 1 2 3",
            sampling: SamplingParameters(
                temperature: 0.1,
                topP: 0.9,
                stopSequences: ["7"]  // Stop at "7"
            ),
            limits: ResourceLimits(maxTokens: 20)
        )

        var generatedText: String = ""
        let stream: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)

        for try await chunk in stream {
            if case .text = chunk.event {
                generatedText += chunk.text
                print("[STOP TEST] Generated: '\(chunk.text)'")
            }
        }

        print("[STOP TEST] Total generated: '\(generatedText)'")
        #expect(!generatedText.isEmpty, "Should generate some text before stop sequence")
        #expect(!generatedText.contains("7"), "Should not contain the stop sequence '7'")
    }
}

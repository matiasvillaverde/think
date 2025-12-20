import Abstractions
import Foundation
@testable import LLamaCPP
import Testing

extension LlamaCPPModelTestSuite {
    @Test("Debug simple generation with BF16 model")
    internal func testSimpleGeneration() async throws {
        guard let configuration: ProviderConfiguration = TestHelpers.createTestConfiguration() else {
            return
        }
        let session: LlamaCPPSession = LlamaCPPSession()

        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        for try await _ in preloadStream {
            // Just consume the progress updates
        }

        let input: LLMInput = LLMInput(
            context: "Hello",
            sampling: SamplingParameters(
                temperature: 0.0,
                topP: 1.0,
                topK: 1,
                seed: 42
            ),
            limits: ResourceLimits(maxTokens: 5)
        )

        var text: String = ""
        let stream: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)

        for try await chunk in stream {
            if case .text = chunk.event {
                text += chunk.text
                print("Chunk: '\(chunk.text)'")
            }
        }

        print("Total generated: '\(text)'")

        #expect(!text.isEmpty, "Should generate text")

        await session.unload()
    }
}

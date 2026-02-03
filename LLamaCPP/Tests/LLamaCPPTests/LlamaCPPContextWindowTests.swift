import Abstractions
import Foundation
@testable import LLamaCPP
import Testing

extension LlamaCPPModelTestSuite {
    @Test("Prompts are truncated to fit the context window")
    internal func testPromptTruncationFitsContext() async throws {
        guard let configuration: ProviderConfiguration = TestHelpers.createTestConfiguration() else {
            return
        }
        let session: LlamaCPPSession = LlamaCPPSession()
        let preloadStream: AsyncThrowingStream<Progress, Error> = await session.preload(
            configuration: configuration
        )
        for try await _ in preloadStream {
            // Consume progress updates
        }

        let longPrompt: String = String(repeating: "hello ", count: 10_000)
        let input: LLMInput = TestHelpers.createTestInput(
            context: longPrompt,
            maxTokens: 16,
            temperature: 0.0
        )

        let stream: AsyncThrowingStream<LLMStreamChunk, Error> = await session.stream(input)
        let chunks: [LLMStreamChunk] = try await TestHelpers.collectChunks(from: stream, limit: 64)

        let finished: LLMStreamChunk? = chunks.last { chunk in
            if case .finished = chunk.event {
                return true
            }
            return false
        }
        #expect(finished != nil)

        if let usage = finished?.metrics?.usage {
            if let contextSize = usage.contextWindowSize {
                if let promptTokens = usage.promptTokens {
                    #expect(promptTokens <= max(0, contextSize - input.limits.maxTokens))
                }
            }
        }

        let textChunks: [LLMStreamChunk] = chunks.filter { chunk in
            if case .text = chunk.event {
                return true
            }
            return false
        }
        #expect(!textChunks.isEmpty)

        await session.unload()
    }
}

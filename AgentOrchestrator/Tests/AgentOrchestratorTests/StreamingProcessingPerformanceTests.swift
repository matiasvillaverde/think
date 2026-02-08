import Abstractions
@testable import AgentOrchestrator
import Foundation
import Testing

@Suite("Streaming Processing Performance Tests")
@MainActor
internal struct StreamingProcessingPerformanceTests {
    @Test("Streaming does not re-process full accumulated output on every throttle tick")
    internal func streamingLimitsContextBuilderProcessCalls() async throws {
        let fixture: StreamingProcessingPerformanceFixture = try await StreamingProcessingPerformanceFixture
            .make()

        try await fixture.orchestrator.load(chatId: fixture.chatId)
        try await fixture.orchestrator.generate(prompt: "Hello", action: Action.textGeneration([]))

        let processCalls: Int = await fixture.counting.processCallCount
        #expect(
            processCalls == StreamingProcessingPerformanceFixture.expectedProcessCalls,
            "Expected 2 process() calls (first UI init + final parse), got \(processCalls)"
        )
    }
}

import Abstractions
import Foundation
import Testing

@testable import AgentOrchestrator

/// Tests for SubAgentResult
@Suite("SubAgentResult Tests")
internal struct SubAgentResultTests {
    @Test("Success factory creates completed result")
    internal func successCreatesCompletedResult() {
        let requestId: UUID = UUID()
        let result: SubAgentResult = SubAgentResult.success(
            id: requestId,
            output: "Done",
            toolsUsed: ["browser.search"],
            durationMs: 100
        )

        #expect(result.id == requestId)
        #expect(result.status == .completed)
        #expect(result.output == "Done")
        #expect(result.toolsUsed == ["browser.search"])
    }

    @Test("Failure factory creates failed result")
    internal func failureCreatesFailedResult() {
        let requestId: UUID = UUID()
        let result: SubAgentResult = SubAgentResult.failure(
            id: requestId,
            error: "Something went wrong",
            durationMs: 50
        )

        #expect(result.id == requestId)
        #expect(result.status == .failed)
        #expect(result.errorMessage == "Something went wrong")
    }

    @Test("Cancelled factory creates cancelled result")
    internal func cancelledCreatesCancelledResult() {
        let requestId: UUID = UUID()
        let result: SubAgentResult = SubAgentResult.cancelled(id: requestId, durationMs: 25)

        #expect(result.status == .cancelled)
    }

    @Test("Timed out factory creates timed out result")
    internal func timedOutCreatesTimedOutResult() {
        let requestId: UUID = UUID()
        let result: SubAgentResult = SubAgentResult.timedOut(id: requestId, durationMs: 300)

        #expect(result.status == .timedOut)
        #expect(result.errorMessage != nil)
    }
}

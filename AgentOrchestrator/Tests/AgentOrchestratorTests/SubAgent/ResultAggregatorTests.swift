import Abstractions
import Foundation
import Testing

@testable import AgentOrchestrator

/// Tests for ResultAggregator
@Suite("ResultAggregator Tests")
internal struct ResultAggregatorTests {
    @Test("Register aggregation returns aggregation ID")
    internal func registerAggregationReturnsId() async {
        let aggregator: ResultAggregator = ResultAggregator()
        let requestIds: Set<UUID> = [UUID(), UUID()]

        let aggregationId: UUID = await aggregator.registerAggregation(requestIds: requestIds)

        #expect(aggregationId != UUID())
    }

    @Test("Record result stores result")
    internal func recordResultStoresResult() async {
        let aggregator: ResultAggregator = ResultAggregator()
        let requestId: UUID = UUID()
        let result: SubAgentResult = SubAgentResult.success(
            id: requestId,
            output: "Done",
            toolsUsed: [],
            durationMs: 100
        )

        await aggregator.recordResult(result)
        let results: [SubAgentResult] = await aggregator.getResults(for: Set([requestId]))

        #expect(results.count == 1)
        #expect(results.first?.id == requestId)
    }

    @Test("Aggregate summary formats results")
    internal func aggregateSummaryFormatsResults() async {
        let aggregator: ResultAggregator = ResultAggregator()
        let results: [SubAgentResult] = [
            SubAgentResult.success(id: UUID(), output: "Task 1 done", toolsUsed: [], durationMs: 100),
            SubAgentResult.failure(id: UUID(), error: "Oops", durationMs: 50)
        ]

        let summary: String = await aggregator.aggregateSummary(results)

        #expect(summary.contains("Sub-Agent Results Summary"))
        #expect(summary.contains("Task 1"))
        #expect(summary.contains("Task 2"))
    }
}

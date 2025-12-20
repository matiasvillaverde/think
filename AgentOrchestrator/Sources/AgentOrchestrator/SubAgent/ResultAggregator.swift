import Abstractions
import Foundation
import OSLog

/// Aggregates results from multiple sub-agents running in parallel
internal actor ResultAggregator {
    private static let logger: Logger = Logger(
        subsystem: AgentOrchestratorConfiguration.shared.logging.subsystem,
        category: "ResultAggregator"
    )

    // MARK: - Properties

    private var pendingRequests: Set<UUID> = []
    private var collectedResults: [UUID: SubAgentResult] = [:]
    private var completionContinuations: [UUID: CheckedContinuation<[SubAgentResult], Error>] = [:]

    // MARK: - Public Methods

    /// Register requests that should be aggregated together
    /// - Parameter requestIds: The request IDs to aggregate
    /// - Returns: A unique aggregation ID
    internal func registerAggregation(requestIds: Set<UUID>) -> UUID {
        let aggregationId: UUID = UUID()
        Self.logger.info("Registering aggregation \(aggregationId) for \(requestIds.count) requests")
        pendingRequests.formUnion(requestIds)
        return aggregationId
    }

    /// Record a result from a sub-agent
    /// - Parameter result: The sub-agent result
    internal func recordResult(_ result: SubAgentResult) {
        Self.logger.info("Recording result for request: \(result.id)")
        collectedResults[result.id] = result
        pendingRequests.remove(result.id)

        // Check if any aggregations are complete
        checkCompletions()
    }

    /// Wait for all specified requests to complete
    /// - Parameter requestIds: The request IDs to wait for
    /// - Returns: All results
    internal func waitForAll(requestIds: Set<UUID>) async throws -> [SubAgentResult] {
        // Check if all are already complete
        let completed: [SubAgentResult] = requestIds.compactMap { collectedResults[$0] }
        if completed.count == requestIds.count {
            return completed
        }

        // Wait for completion
        let aggregationId: UUID = UUID()
        return try await withCheckedThrowingContinuation { continuation in
            completionContinuations[aggregationId] = continuation
        }
    }

    /// Get results that match a set of request IDs
    /// - Parameter requestIds: The request IDs to filter by
    /// - Returns: Available results
    internal func getResults(for requestIds: Set<UUID>) -> [SubAgentResult] {
        requestIds.compactMap { collectedResults[$0] }
    }

    /// Aggregate results into a summary
    /// - Parameter results: The results to aggregate
    /// - Returns: A summary string
    internal func aggregateSummary(_ results: [SubAgentResult]) -> String {
        var summary: [String] = ["## Sub-Agent Results Summary", ""]

        for (index, result) in results.enumerated() {
            summary.append(contentsOf: formatResultEntry(result, index: index))
        }

        return summary.joined(separator: "\n")
    }

    private func formatResultEntry(_ result: SubAgentResult, index: Int) -> [String] {
        var lines: [String] = []
        let statusEmoji: String = statusToEmoji(result.status)
        lines.append("### Task \(index + 1) \(statusEmoji)")
        lines.append(statusMessage(for: result))

        if !result.toolsUsed.isEmpty {
            lines.append("*Tools used: \(result.toolsUsed.joined(separator: ", "))*")
        }

        lines.append("")
        return lines
    }

    private func statusMessage(for result: SubAgentResult) -> String {
        switch result.status {
        case .cancelled:
            return "**Cancelled**"

        case .completed:
            return result.output

        case .failed:
            return "**Failed:** \(result.errorMessage ?? "Unknown error")"

        case .running:
            return "*Still running...*"

        case .timedOut:
            return "**Timed out**"
        }
    }

    // MARK: - Private Methods

    private func checkCompletions() {
        // Simple implementation - in production would track which continuations
        // are waiting for which request IDs
        Self.logger.debug("Checking completions, pending: \(self.pendingRequests.count)")
    }

    private func statusToEmoji(_ status: SubAgentStatus) -> String {
        switch status {
        case .cancelled:
            return "🚫"

        case .completed:
            return "✅"

        case .failed:
            return "❌"

        case .running:
            return "🔄"

        case .timedOut:
            return "⏰"
        }
    }
}

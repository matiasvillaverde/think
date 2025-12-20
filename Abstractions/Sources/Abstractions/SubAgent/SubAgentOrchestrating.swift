import Foundation

/// Protocol for sub-agent orchestration
public protocol SubAgentOrchestrating: Actor {
    /// Spawn a new sub-agent
    /// - Parameter request: The sub-agent request
    /// - Returns: The request ID for tracking
    func spawn(request: SubAgentRequest) async -> UUID

    /// Get the result of a sub-agent if complete
    /// - Parameter requestId: The request ID
    /// - Returns: The result if available
    func getResult(for requestId: UUID) async -> SubAgentResult?

    /// Cancel a running sub-agent
    /// - Parameter requestId: The request ID to cancel
    func cancel(requestId: UUID) async

    /// Wait for a sub-agent to complete
    /// - Parameter requestId: The request ID to wait for
    /// - Returns: The result
    func waitForCompletion(requestId: UUID) async throws -> SubAgentResult

    /// Get all active sub-agent requests
    func getActiveRequests() async -> [SubAgentRequest]

    /// Stream of sub-agent results
    var resultStream: AsyncStream<SubAgentResult> { get async }
}

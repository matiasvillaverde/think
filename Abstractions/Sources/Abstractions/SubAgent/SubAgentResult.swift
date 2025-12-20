import Foundation

/// Status of a sub-agent execution
public enum SubAgentStatus: String, Sendable, Codable, Equatable {
    /// Sub-agent is currently running
    case running = "running"
    /// Sub-agent completed successfully
    case completed = "completed"
    /// Sub-agent failed with an error
    case failed = "failed"
    /// Sub-agent was cancelled
    case cancelled = "cancelled"
    /// Sub-agent timed out
    case timedOut = "timed_out"
}

/// Result of a sub-agent execution
public struct SubAgentResult: Sendable, Equatable, Identifiable {
    /// The request ID this result corresponds to
    public let id: UUID
    /// The final output text
    public let output: String
    /// Tools that were called during execution
    public let toolsUsed: [String]
    /// Total duration of execution
    public let durationMs: Int
    /// Final status
    public let status: SubAgentStatus
    /// Error message if failed
    public let errorMessage: String?
    /// When the result was produced
    public let completedAt: Date

    /// Initialize a new sub-agent result
    public init(
        id: UUID,
        output: String,
        durationMs: Int,
        status: SubAgentStatus,
        toolsUsed: [String] = [],
        errorMessage: String? = nil,
        completedAt: Date = Date()
    ) {
        self.id = id
        self.output = output
        self.durationMs = durationMs
        self.status = status
        self.toolsUsed = toolsUsed
        self.errorMessage = errorMessage
        self.completedAt = completedAt
    }

    /// Create a successful result
    public static func success(
        id: UUID,
        output: String,
        toolsUsed: [String],
        durationMs: Int
    ) -> SubAgentResult {
        SubAgentResult(
            id: id,
            output: output,
            durationMs: durationMs,
            status: .completed,
            toolsUsed: toolsUsed
        )
    }

    /// Create a failed result
    public static func failure(
        id: UUID,
        error: String,
        durationMs: Int
    ) -> SubAgentResult {
        SubAgentResult(
            id: id,
            output: "",
            durationMs: durationMs,
            status: .failed,
            errorMessage: error
        )
    }

    /// Create a cancelled result
    public static func cancelled(id: UUID, durationMs: Int) -> SubAgentResult {
        SubAgentResult(
            id: id,
            output: "",
            durationMs: durationMs,
            status: .cancelled
        )
    }

    /// Create a timed out result
    public static func timedOut(id: UUID, durationMs: Int) -> SubAgentResult {
        SubAgentResult(
            id: id,
            output: "",
            durationMs: durationMs,
            status: .timedOut,
            errorMessage: "Sub-agent execution timed out"
        )
    }
}

import Foundation

/// Events emitted during agent generation for richer UI feedback
public enum AgentEvent: Sendable {
    /// Generation has started
    case generationStarted(runId: UUID)

    /// Text token received during streaming
    case textDelta(text: String)

    /// Extended thinking/reasoning content (if enabled)
    case reasoningDelta(text: String)

    /// A tool execution has started
    case toolStarted(requestId: UUID, toolName: String)

    /// Tool execution progress update
    case toolProgress(requestId: UUID, progress: Double, status: String)

    /// A tool execution has completed successfully
    case toolCompleted(requestId: UUID, result: String, durationMs: Int)

    /// A tool execution has failed
    case toolFailed(requestId: UUID, error: String)

    /// An iteration of the agentic loop has completed
    case iterationCompleted(iteration: Int, decision: String)

    /// Generation has completed successfully
    case generationCompleted(runId: UUID, totalDurationMs: Int)

    /// Generation has failed with an error
    case generationFailed(runId: UUID, error: String)

    /// Current state update for UI
    case stateUpdate(state: GenerationStateInfo)
}

/// Information about the current generation state for UI display
public struct GenerationStateInfo: Sendable, Equatable {
    /// Current iteration number (0-based)
    public let iteration: Int
    /// Whether tools are currently executing
    public let isExecutingTools: Bool
    /// Names of tools currently being executed
    public let activeTools: [String]
    /// Number of completed tool calls this iteration
    public let completedToolCalls: Int
    /// Total pending tool calls this iteration
    public let pendingToolCalls: Int

    /// Initialize a new generation state info
    public init(
        iteration: Int,
        isExecutingTools: Bool = false,
        activeTools: [String] = [],
        completedToolCalls: Int = 0,
        pendingToolCalls: Int = 0
    ) {
        self.iteration = iteration
        self.isExecutingTools = isExecutingTools
        self.activeTools = activeTools
        self.completedToolCalls = completedToolCalls
        self.pendingToolCalls = pendingToolCalls
    }
}

extension AgentEvent: Equatable {
    // swiftlint:disable:next cyclomatic_complexity
    public static func == (lhs: AgentEvent, rhs: AgentEvent) -> Bool {
        switch (lhs, rhs) {
        case let (.generationStarted(lhsId), .generationStarted(rhsId)):
            return lhsId == rhsId

        case let (.textDelta(lhsText), .textDelta(rhsText)):
            return lhsText == rhsText

        case let (.reasoningDelta(lhsText), .reasoningDelta(rhsText)):
            return lhsText == rhsText

        case let (.toolStarted(lhsId, lhsName), .toolStarted(rhsId, rhsName)):
            return lhsId == rhsId && lhsName == rhsName

        case let (.toolProgress(lhsId, lhsProg, lhsStat), .toolProgress(rhsId, rhsProg, rhsStat)):
            return lhsId == rhsId && lhsProg == rhsProg && lhsStat == rhsStat

        case let (.toolCompleted(lhsId, lhsRes, lhsDur), .toolCompleted(rhsId, rhsRes, rhsDur)):
            return lhsId == rhsId && lhsRes == rhsRes && lhsDur == rhsDur

        case let (.toolFailed(lhsId, lhsErr), .toolFailed(rhsId, rhsErr)):
            return lhsId == rhsId && lhsErr == rhsErr

        case let (.iterationCompleted(lhsIter, lhsDec), .iterationCompleted(rhsIter, rhsDec)):
            return lhsIter == rhsIter && lhsDec == rhsDec

        case let (.generationCompleted(lhsId, lhsDur), .generationCompleted(rhsId, rhsDur)):
            return lhsId == rhsId && lhsDur == rhsDur

        case let (.generationFailed(lhsId, lhsErr), .generationFailed(rhsId, rhsErr)):
            return lhsId == rhsId && lhsErr == rhsErr

        case let (.stateUpdate(lhsState), .stateUpdate(rhsState)):
            return lhsState == rhsState

        default:
            return false
        }
    }
}

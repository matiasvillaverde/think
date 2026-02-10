import Abstractions
import Foundation
import OSLog

/// Actor that manages event emission during agent generation
internal actor EventEmitter {
    /// Logger for event emission
    private static let logger: Logger = Logger(
        subsystem: AgentOrchestratorConfiguration.shared.logging.subsystem,
        category: "EventEmitter"
    )

    /// Maximum prefix length for log message truncation
    private static let logPrefixLength: Int = 50

    /// Milliseconds per second for duration calculations
    private static let millisecondsPerSecond: Int = 1_000

    /// Attoseconds to milliseconds divisor
    private static let attosecondsToMilliseconds: Int64 = 1_000_000_000_000_000

    /// Continuation for the event stream
    private var continuation: AsyncStream<AgentEvent>.Continuation?

    /// The public event stream
    internal private(set) var eventStream: AgentEventStream

    /// Track the start time for duration calculations
    private var startTime: ContinuousClock.Instant?

    /// The clock for timing
    private let clock: ContinuousClock = ContinuousClock()

    /// Initialize a new EventEmitter
    internal init() {
        var continuation: AsyncStream<AgentEvent>.Continuation?
        self.eventStream = AsyncStream<AgentEvent> { cont in
            continuation = cont
        }
        self.continuation = continuation
    }

    // MARK: - Generation Lifecycle Events

    /// Emit that generation has started
    /// - Parameter runId: The unique ID for this generation run
    internal func emitGenerationStarted(runId: UUID) {
        startTime = clock.now
        let event: AgentEvent = .generationStarted(runId: runId)
        Self.logger.info("Generation started: \(runId)")
        continuation?.yield(event)
    }

    /// Emit that generation has completed
    /// - Parameter runId: The unique ID for this generation run
    internal func emitGenerationCompleted(runId: UUID) {
        let durationMs: Int = calculateDurationMs()
        let event: AgentEvent = .generationCompleted(runId: runId, totalDurationMs: durationMs)
        Self.logger.info("Generation completed: \(runId), duration: \(durationMs)ms")
        continuation?.yield(event)
    }

    /// Emit that generation has failed
    /// - Parameters:
    ///   - runId: The unique ID for this generation run
    ///   - error: The error that caused the failure
    internal func emitGenerationFailed(runId: UUID, error: Error) {
        let event: AgentEvent = .generationFailed(runId: runId, error: error.localizedDescription)
        Self.logger.error("Generation failed: \(runId), error: \(error.localizedDescription)")
        continuation?.yield(event)
    }

    // MARK: - Text Streaming Events

    /// Emit a text delta during streaming
    /// - Parameter text: The text chunk received
    internal func emitTextDelta(text: String) {
        let event: AgentEvent = .textDelta(text: text)
        Self.logger.debug("Text delta: \(text.prefix(Self.logPrefixLength))...")
        continuation?.yield(event)
    }

    // MARK: - Tool Events

    /// Emit that a tool execution has started
    /// - Parameters:
    ///   - requestId: The unique ID for this tool request
    ///   - toolName: The name of the tool being executed
    internal func emitToolStarted(requestId: UUID, toolName: String) {
        let event: AgentEvent = .toolStarted(requestId: requestId, toolName: toolName)
        Self.logger.info("Tool started: \(toolName), request: \(requestId)")
        continuation?.yield(event)
    }

    /// Emit tool execution progress
    /// - Parameters:
    ///   - requestId: The unique ID for this tool request
    ///   - progress: Progress value between 0.0 and 1.0
    ///   - status: Human-readable status message
    internal func emitToolProgress(requestId: UUID, progress: Double, status: String) {
        let event: AgentEvent = .toolProgress(requestId: requestId, progress: progress, status: status)
        Self.logger.debug("Tool progress: \(requestId), \(Int(progress * 100))%")
        continuation?.yield(event)
    }

    /// Emit that a tool execution has completed
    /// - Parameters:
    ///   - requestId: The unique ID for this tool request
    ///   - result: The tool execution result
    ///   - durationMs: How long the tool took to execute
    internal func emitToolCompleted(requestId: UUID, result: String, durationMs: Int) {
        let event: AgentEvent = .toolCompleted(requestId: requestId, result: result, durationMs: durationMs)
        Self.logger.info("Tool completed: \(requestId), duration: \(durationMs)ms")
        continuation?.yield(event)
    }

    /// Emit that a tool execution has failed
    /// - Parameters:
    ///   - requestId: The unique ID for this tool request
    ///   - error: The error message
    internal func emitToolFailed(requestId: UUID, error: String) {
        let event: AgentEvent = .toolFailed(requestId: requestId, error: error)
        Self.logger.error("Tool failed: \(requestId), error: \(error)")
        continuation?.yield(event)
    }

    // MARK: - Iteration Events

    /// Emit that an iteration of the agentic loop has completed
    /// - Parameters:
    ///   - iteration: The iteration number (1-based)
    ///   - decision: Description of the decision made
    internal func emitIterationCompleted(iteration: Int, decision: String) {
        let event: AgentEvent = .iterationCompleted(iteration: iteration, decision: decision)
        Self.logger.info("Iteration \(iteration) completed, decision: \(decision)")
        continuation?.yield(event)
    }

    /// Emit a state update for UI display
    /// - Parameter state: The current generation state info
    internal func emitStateUpdate(state: GenerationStateInfo) {
        let event: AgentEvent = .stateUpdate(state: state)
        let isExecuting: Bool = state.isExecutingTools
        Self.logger.debug("State update: iteration \(state.iteration), tools executing: \(isExecuting)")
        continuation?.yield(event)
    }

    // MARK: - Lifecycle

    /// Reset internal state for a new generation (keeps the stream stable)
    /// The stream remains the same so existing subscribers continue to receive events
    internal func resetState() {
        Self.logger.info("Event emitter state reset for new generation")
        self.startTime = nil
    }

    /// Finish the event stream
    /// Call this when the orchestrator is being deallocated or no more events will be emitted
    internal func finish() {
        Self.logger.info("Event stream finished")
        continuation?.finish()
    }

    // MARK: - Private Helpers

    private func calculateDurationMs() -> Int {
        guard let start = startTime else {
            return 0
        }
        let elapsed: Duration = start.duration(to: clock.now)
        let secondsMs: Int = Int(elapsed.components.seconds) * Self.millisecondsPerSecond
        let attosecondsMs: Int = Int(elapsed.components.attoseconds / Self.attosecondsToMilliseconds)
        return secondsMs + attosecondsMs
    }
}

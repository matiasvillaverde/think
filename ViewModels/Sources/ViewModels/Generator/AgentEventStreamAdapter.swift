import Abstractions
import Database
import Foundation
import OSLog

/// Bridges agent event streams into persisted tool execution state for UI updates.
public final actor AgentEventStreamAdapter {
    private let orchestrator: AgentOrchestrating
    private let database: DatabaseProtocol
    private let logger: Logger = Logger(subsystem: "ViewModels", category: "AgentEventStreamAdapter")

    private var eventTask: Task<Void, Never>?

    /// Creates a new adapter that listens to agent event streams.
    public init(orchestrator: AgentOrchestrating, database: DatabaseProtocol) {
        self.orchestrator = orchestrator
        self.database = database
    }

    /// Starts consuming the agent event stream.
    public func start() {
        stop()
        eventTask = Task { [weak self] in
            guard let self else {
                return
            }
            await consumeEvents()
        }
    }

    /// Stops consuming the agent event stream.
    public func stop() {
        eventTask?.cancel()
        eventTask = nil
    }

    private func consumeEvents() async {
        let stream: AgentEventStream = await orchestrator.eventStream
        for await event in stream {
            if Task.isCancelled {
                break
            }
            await handle(event)
        }
    }

    private func handle(_ event: AgentEvent) async {
        switch event {
        case let .toolStarted(requestId, _):
            await markToolExecuting(requestId: requestId)

        case let .toolProgress(requestId, progress, status):
            await updateToolProgress(requestId: requestId, progress: progress, status: status)

        case let .toolFailed(requestId, error):
            await updateToolProgress(requestId: requestId, progress: nil, status: error)

        case let .toolCompleted(requestId, _, _):
            await updateToolProgress(requestId: requestId, progress: 1.0, status: nil)

        default:
            break
        }
    }

    private func markToolExecuting(requestId: UUID) async {
        do {
            _ = try await database.write(
                ToolExecutionCommands.StartExecution(executionId: requestId)
            )
        } catch {
            logger.debug("Skipping tool start update: \(error.localizedDescription)")
        }
    }

    private func updateToolProgress(
        requestId: UUID,
        progress: Double?,
        status: String?
    ) async {
        do {
            _ = try await database.write(
                ToolExecutionCommands.UpdateProgress(
                    executionId: requestId,
                    progress: progress,
                    status: status
                )
            )
        } catch {
            logger.debug("Skipping tool progress update: \(error.localizedDescription)")
        }
    }
}

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

        case let .generationFailed(runId, errorMessage):
            await persistGenerationFailure(messageId: runId, errorMessage: errorMessage)

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

    private func persistGenerationFailure(messageId: UUID, errorMessage: String) async {
        do {
            _ = try await database.write(
                MessageCommands.AppendFinalChannelContent(
                    messageId: messageId,
                    appendedContent: Self.userFacingErrorMarkdown(for: errorMessage),
                    isComplete: true
                )
            )
        } catch {
            logger.debug("Skipping generation failure persistence: \(error.localizedDescription)")
        }
    }

    private static func userFacingErrorMarkdown(for errorMessage: String) -> String {
        let normalized: String = errorMessage.trimmingCharacters(in: .whitespacesAndNewlines)

        // OpenRouter data policy block: make it actionable and non-mysterious.
        if normalized.localizedCaseInsensitiveContains("OpenRouter blocked this request due to your data policy")
            || normalized.localizedCaseInsensitiveContains("No endpoints found matching your data policy") {
            return """
            **OpenRouter blocked this request due to your privacy settings.**

            1. Open OpenRouter Settings -> Privacy.
            2. Allow an endpoint for this model (free models commonly require enabling Free model publication).
            3. Retry your message.

            https://openrouter.ai/settings/privacy
            """
        }

        if normalized.localizedCaseInsensitiveContains("No API key configured")
            || normalized.localizedCaseInsensitiveContains("Missing or invalid API key")
            || normalized.localizedCaseInsensitiveContains("Invalid API key") {
            return """
            **Remote model needs an API key.**

            Go to Settings -> API Keys, add a key for your provider, then retry.
            """
        }

        return """
        **Generation failed**

        \(normalized)
        """
    }
}

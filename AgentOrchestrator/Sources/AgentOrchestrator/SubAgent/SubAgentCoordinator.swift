import Abstractions
import Foundation
import OSLog

/// Coordinator for managing sub-agent execution
internal actor SubAgentCoordinator: SubAgentOrchestrating {
    private static let logger: Logger = Logger(
        subsystem: AgentOrchestratorConfiguration.shared.logging.subsystem,
        category: "SubAgentCoordinator"
    )

    // MARK: - Constants

    private enum Constants {
        static let millisecondsPerSecond: Double = 1_000
        static let sleepDurationMs: UInt64 = 100
    }

    // MARK: - Properties

    private var activeRequests: [UUID: SubAgentRequest] = [:]
    private var results: [UUID: SubAgentResult] = [:]
    private var runningTasks: [UUID: Task<SubAgentResult, Error>] = [:]
    private var resultContinuation: AsyncStream<SubAgentResult>.Continuation?
    private var _resultStream: AsyncStream<SubAgentResult>

    // swiftlint:disable orphaned_doc_comment
    /// Stream of sub-agent results
    // swiftlint:disable async_without_await
    internal var resultStream: AsyncStream<SubAgentResult> {
        get async { _resultStream }
    }
    // swiftlint:enable async_without_await
    // swiftlint:enable orphaned_doc_comment

    // MARK: - Initialization

    internal init() {
        var continuation: AsyncStream<SubAgentResult>.Continuation?
        _resultStream = AsyncStream { cont in
            continuation = cont
        }
        resultContinuation = continuation
    }

    deinit {
        resultContinuation?.finish()
    }

    // MARK: - SubAgentOrchestrating

    // swiftlint:disable async_without_await
    internal func spawn(request: SubAgentRequest) async -> UUID {
        Self.logger.info("Spawning sub-agent with id: \(request.id)")

        activeRequests[request.id] = request

        let task: Task<SubAgentResult, Error> = Task { [weak self] in
            await self?.executeSubAgent(request: request) ?? .failure(
                id: request.id,
                error: "Coordinator deallocated",
                durationMs: 0
            )
        }

        runningTasks[request.id] = task

        return request.id
    }
    // swiftlint:enable async_without_await

    // swiftlint:disable async_without_await
    internal func getResult(for requestId: UUID) async -> SubAgentResult? {
        results[requestId]
    }

    internal func cancel(requestId: UUID) async {
        Self.logger.info("Cancelling sub-agent: \(requestId)")

        if let task = runningTasks[requestId] {
            task.cancel()
            runningTasks.removeValue(forKey: requestId)
        }

        activeRequests.removeValue(forKey: requestId)

        if results[requestId] == nil {
            let result: SubAgentResult = SubAgentResult.cancelled(id: requestId, durationMs: 0)
            results[requestId] = result
            resultContinuation?.yield(result)
        }
    }
    // swiftlint:enable async_without_await

    internal func waitForCompletion(requestId: UUID) async throws -> SubAgentResult {
        // If already have result, return it
        if let result = results[requestId] {
            return result
        }

        // Wait for the task to complete
        guard let task = runningTasks[requestId] else {
            throw SubAgentError.requestNotFound
        }

        return try await task.value
    }

    // swiftlint:disable async_without_await
    internal func getActiveRequests() async -> [SubAgentRequest] {
        Array(activeRequests.values)
    }
    // swiftlint:enable async_without_await

    // MARK: - Private Methods

    // swiftlint:disable:next function_body_length
    private func executeSubAgent(request: SubAgentRequest) async -> SubAgentResult {
        let startTime: Date = Date()
        Self.logger.info("Executing sub-agent: \(request.id)")

        do {
            // Check for timeout
            let result: SubAgentResult = try await withThrowingTaskGroup(
                of: SubAgentResult.self
            ) { group in
                // Main execution task
                group.addTask {
                    try await Task.sleep(for: .milliseconds(Constants.sleepDurationMs))
                    let durationMs: Int = Int(
                        Date().timeIntervalSince(startTime) * Constants.millisecondsPerSecond
                    )
                    return SubAgentResult.success(
                        id: request.id,
                        output: "Sub-agent completed task: \(request.prompt)",
                        toolsUsed: request.tools.map(\.toolName),
                        durationMs: durationMs
                    )
                }

                // Timeout task
                group.addTask {
                    try await Task.sleep(for: request.timeout)
                    let durationMs: Int = Int(
                        Date().timeIntervalSince(startTime) * Constants.millisecondsPerSecond
                    )
                    return SubAgentResult.timedOut(id: request.id, durationMs: durationMs)
                }

                // Return whichever completes first
                guard let firstResult = try await group.next() else {
                    throw SubAgentError.executionFailed("No result")
                }

                // Cancel the other task
                group.cancelAll()

                return firstResult
            }

            return recordResult(result)
        } catch is CancellationError {
            let durationMs: Int = Int(
                Date().timeIntervalSince(startTime) * Constants.millisecondsPerSecond
            )
            let result: SubAgentResult = SubAgentResult.cancelled(
                id: request.id,
                durationMs: durationMs
            )
            return recordResult(result)
        } catch {
            let durationMs: Int = Int(
                Date().timeIntervalSince(startTime) * Constants.millisecondsPerSecond
            )
            let result: SubAgentResult = SubAgentResult.failure(
                id: request.id,
                error: error.localizedDescription,
                durationMs: durationMs
            )
            return recordResult(result)
        }
    }

    private func recordResult(_ result: SubAgentResult) -> SubAgentResult {
        results[result.id] = result
        activeRequests.removeValue(forKey: result.id)
        runningTasks.removeValue(forKey: result.id)
        resultContinuation?.yield(result)

        Self.logger.info("Sub-agent \(result.id) completed with status: \(result.status.rawValue)")
        return result
    }
}

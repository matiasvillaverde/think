import Abstractions
import ContextBuilder
import Database
import Foundation
import OSLog
import Tools

/// Coordinator for managing sub-agent execution
internal actor SubAgentCoordinator: SubAgentOrchestrating {
    internal static let logger: Logger = Logger(
        subsystem: AgentOrchestratorConfiguration.shared.logging.subsystem,
        category: "SubAgentCoordinator"
    )

    // MARK: - Constants

    internal enum Constants {
        internal static let millisecondsPerSecond: Double = 1_000
        internal static let maxIterations: Int = 4
    }

    // MARK: - Properties

    internal let database: DatabaseProtocol
    internal let modelCoordinator: ModelStateCoordinator
    internal let workspaceRoot: URL?
    internal let workspaceContextProvider: WorkspaceContextProvider?
    internal let workspaceSkillLoader: WorkspaceSkillLoader?
    internal let workspaceMemoryLoader: WorkspaceMemoryLoader?

    internal var activeRequests: [UUID: SubAgentRequest] = [:]
    internal var results: [UUID: SubAgentResult] = [:]
    internal var runningTasks: [UUID: Task<SubAgentResult, Error>] = [:]
    internal var resultContinuation: AsyncStream<SubAgentResult>.Continuation?
    internal var resultStreamStorage: AsyncStream<SubAgentResult>

    // swiftlint:disable orphaned_doc_comment
    /// Stream of sub-agent results
    // swiftlint:disable async_without_await
    internal var resultStream: AsyncStream<SubAgentResult> {
        get async { resultStreamStorage }
    }
    // swiftlint:enable async_without_await
    // swiftlint:enable orphaned_doc_comment

    // MARK: - Initialization

    internal init(
        database: DatabaseProtocol,
        modelCoordinator: ModelStateCoordinator,
        workspaceRoot: URL? = nil
    ) {
        self.database = database
        self.modelCoordinator = modelCoordinator
        self.workspaceRoot = workspaceRoot
        if let workspaceRoot {
            self.workspaceContextProvider = WorkspaceContextProvider(rootURL: workspaceRoot)
            self.workspaceSkillLoader = WorkspaceSkillLoader(rootURL: workspaceRoot)
            self.workspaceMemoryLoader = WorkspaceMemoryLoader(rootURL: workspaceRoot)
        } else {
            self.workspaceContextProvider = nil
            self.workspaceSkillLoader = nil
            self.workspaceMemoryLoader = nil
        }

        var continuation: AsyncStream<SubAgentResult>.Continuation?
        resultStreamStorage = AsyncStream { cont in
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
        if let result = results[requestId] {
            return result
        }

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
}

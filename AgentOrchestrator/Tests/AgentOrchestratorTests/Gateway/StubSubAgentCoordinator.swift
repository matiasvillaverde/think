import Abstractions
import Foundation

internal actor StubSubAgentCoordinator: SubAgentOrchestrating {
    private let result: SubAgentResult
    private var captured: SubAgentRequest?

    internal init(result: SubAgentResult) {
        self.result = result
    }

    internal func spawn(request: SubAgentRequest) async -> UUID {
        await Task.yield()
        captured = request
        return request.id
    }

    internal func getResult(for requestId: UUID) async -> SubAgentResult? {
        await Task.yield()
        return requestId == result.id ? result : nil
    }

    internal func cancel(requestId: UUID) async {
        await Task.yield()
        let _: UUID = requestId
    }

    internal func waitForCompletion(requestId: UUID) async throws -> SubAgentResult {
        try Task.checkCancellation()
        await Task.yield()
        if requestId == result.id {
            return result
        }
        return SubAgentResult.success(
            id: requestId,
            output: result.output,
            toolsUsed: result.toolsUsed,
            durationMs: result.durationMs
        )
    }

    internal func getActiveRequests() async -> [SubAgentRequest] {
        await Task.yield()
        return captured.map { [$0] } ?? []
    }

    internal var resultStream: AsyncStream<SubAgentResult> {
        get async {
            await Task.yield()
            return AsyncStream { continuation in
                continuation.yield(result)
                continuation.finish()
            }
        }
    }

    internal func lastRequest() async -> SubAgentRequest? {
        await Task.yield()
        return captured
    }
}

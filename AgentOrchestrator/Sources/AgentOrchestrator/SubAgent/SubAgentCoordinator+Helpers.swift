import Abstractions
import Database
import Foundation

extension SubAgentCoordinator {
    internal func applyToolPolicy(
        action: Action,
        allowedTools: Set<ToolIdentifier>,
        hasToolPolicy: Bool
    ) -> Action {
        guard hasToolPolicy else {
            return action
        }

        let filteredTools: Set<ToolIdentifier> = action.tools.intersection(allowedTools)
        switch action {
        case .textGeneration:
            return .textGeneration(filteredTools)

        case .imageGeneration:
            return .imageGeneration(filteredTools)
        }
    }

    internal func partitionToolRequests(
        _ requests: [ToolRequest],
        allowed: Set<String>
    ) -> ToolPartition {
        var allowedRequests: [ToolRequest] = []
        var blockedRequests: [ToolRequest] = []

        for request in requests {
            if allowed.contains(request.name) {
                allowedRequests.append(request)
            } else {
                blockedRequests.append(request)
            }
        }

        return ToolPartition(allowed: allowedRequests, blocked: blockedRequests)
    }

    internal func mergeToolUsage(current: [String], additional: [String]) -> [String] {
        var merged: Set<String> = Set(current)
        merged.formUnion(additional)
        return Array(merged)
    }

    internal func createMessageData(
        request: SubAgentRequest,
        channels: [MessageChannel],
        toolRequests: [ToolCall]
    ) -> MessageData {
        MessageData(
            id: request.parentMessageId,
            createdAt: request.createdAt,
            userInput: request.prompt,
            channels: channels,
            toolCalls: toolRequests
        )
    }

    internal func extractFinalOutput(from processed: ProcessedOutput, fallback: String) -> String {
        let finalChunks: [String] = processed.channels
            .filter { channel in channel.type == .final }
            .map(\.content)

        if !finalChunks.isEmpty {
            return finalChunks.joined(separator: "\n").trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        }

        return fallback.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    internal func streamToString(input: LLMInput) async throws -> String {
        var accumulated: String = ""
        for try await chunk in await modelCoordinator.stream(input) {
            accumulated += chunk.text
            if Task.isCancelled {
                throw CancellationError()
            }
        }
        return accumulated
    }

    internal func mergeSkillContext(current: SkillContext?, additional: [SkillData]) -> SkillContext? {
        guard !additional.isEmpty else {
            return current
        }

        let existing: [SkillData] = current?.activeSkills ?? []
        var merged: [SkillData] = existing
        let existingNames: Set<String> = Set(existing.map { skill in
            skill.name.lowercased()
        })

        for skill in additional where !existingNames.contains(skill.name.lowercased()) {
            merged.append(skill)
        }

        return merged.isEmpty ? nil : SkillContext(activeSkills: merged)
    }

    internal func makeBlockedResponses(from blocked: [ToolRequest]) -> [ToolResponse] {
        blocked.map { request in
            ToolResponse(
                requestId: request.id,
                toolName: request.name,
                result: "",
                error: "Tool not allowed: \(request.name)"
            )
        }
    }

    internal func collectToolNames(
        allowed: [ToolResponse],
        blocked: [ToolRequest]
    ) -> [String] {
        let allowedNames: [String] = allowed.map(\.toolName)
        let blockedNames: [String] = blocked.map(\.name)
        return allowedNames + blockedNames
    }

    internal func updateRun(runId: UUID?, with result: SubAgentResult) async {
        guard let runId else {
            return
        }

        do {
            try await persistRun(runId: runId, result: result)
        } catch {
            Self.logger.warning("Failed to update sub-agent run status")
        }
    }

    internal func recordResult(_ result: SubAgentResult) -> SubAgentResult {
        results[result.id] = result
        activeRequests.removeValue(forKey: result.id)
        runningTasks.removeValue(forKey: result.id)
        resultContinuation?.yield(result)

        Self.logger.info("Sub-agent \(result.id) completed with status: \(result.status.rawValue)")
        return result
    }

    internal func makeTimedOutResult(id: UUID, startTime: Date) -> SubAgentResult {
        SubAgentResult.timedOut(
            id: id,
            durationMs: Self.elapsedMs(since: startTime)
        )
    }

    internal func makeCancelledResult(id: UUID, startTime: Date) -> SubAgentResult {
        SubAgentResult.cancelled(
            id: id,
            durationMs: Self.elapsedMs(since: startTime)
        )
    }

    internal func makeFailureResult(id: UUID, error: String, startTime: Date) -> SubAgentResult {
        SubAgentResult.failure(
            id: id,
            error: error,
            durationMs: Self.elapsedMs(since: startTime)
        )
    }

    internal func makeCompletedResult(
        requestId: UUID,
        output: String,
        toolsUsed: [String],
        startTime: Date
    ) -> SubAgentResult {
        SubAgentResult.success(
            id: requestId,
            output: output,
            toolsUsed: toolsUsed,
            durationMs: Self.elapsedMs(since: startTime)
        )
    }

    internal func makeIterationFailureResult(requestId: UUID, startTime: Date) -> SubAgentResult {
        SubAgentResult.failure(
            id: requestId,
            error: "Exceeded maximum tool iterations",
            durationMs: Self.elapsedMs(since: startTime)
        )
    }

    internal static func elapsedMs(since startTime: Date) -> Int {
        Int(Date().timeIntervalSince(startTime) * Constants.millisecondsPerSecond)
    }

    private func persistRun(runId: UUID, result: SubAgentResult) async throws {
        switch result.status {
        case .completed:
            try await markRunCompleted(runId: runId, result: result)

        case .failed:
            try await markRunFailed(runId: runId, result: result)

        case .cancelled:
            try await markRunCancelled(runId: runId, result: result)

        case .timedOut:
            try await markRunTimedOut(runId: runId, result: result)

        case .running:
            break
        }
    }

    private func markRunCompleted(runId: UUID, result: SubAgentResult) async throws {
        _ = try await database.write(SubAgentCommands.MarkCompleted(
            runId: runId,
            output: result.output,
            toolsUsed: result.toolsUsed,
            durationMs: result.durationMs
        ))
    }

    private func markRunFailed(runId: UUID, result: SubAgentResult) async throws {
        _ = try await database.write(SubAgentCommands.MarkFailed(
            runId: runId,
            error: result.errorMessage ?? "Sub-agent failed",
            durationMs: result.durationMs
        ))
    }

    private func markRunCancelled(runId: UUID, result: SubAgentResult) async throws {
        _ = try await database.write(SubAgentCommands.MarkCancelled(
            runId: runId,
            durationMs: result.durationMs
        ))
    }

    private func markRunTimedOut(runId: UUID, result: SubAgentResult) async throws {
        _ = try await database.write(SubAgentCommands.MarkTimedOut(
            runId: runId,
            durationMs: result.durationMs
        ))
    }
}

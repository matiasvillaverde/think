import Abstractions
import Foundation
import OSLog

internal struct GenerationState {
    private static let logger: Logger = Logger(
        subsystem: "AgentOrchestrator",
        category: "GenerationState"
    )

    internal let messageId: UUID
    internal let chatId: UUID
    internal let model: SendableModel
    internal let action: Action
    internal let prompt: String

    internal var previousOutput: ProcessedOutput?
    internal var latestOutput: ProcessedOutput?
    internal var pendingToolCalls: [ToolRequest] = []
    internal var toolResults: [ToolResponse] = []
    internal var lastMetrics: ChunkMetrics?
    internal var iterationCount: Int = 0
    internal var isComplete: Bool = false

    internal init(request: GenerationRequest) {
        self.messageId = request.messageId
        self.chatId = request.chatId
        self.model = request.model
        self.action = request.action
        self.prompt = request.prompt

        Self.logger.debug("Generation state initialized for message: \(request.messageId)")
    }

    internal func withStreamComplete(output: ProcessedOutput, metrics: ChunkMetrics?) ->
    Self {
        var new: Self = self
        new.latestOutput = output
        new.pendingToolCalls = output.toolRequests
        new.lastMetrics = metrics
        return new
    }

    internal func continueWithTools(_ results: [ToolResponse]) -> Self {
        var new: Self = self
        new.toolResults = results
        new.previousOutput = latestOutput
        new.latestOutput = nil  // Clear latest output to continue generation
        new.pendingToolCalls = []
        new.iterationCount += 1

        Self.logger.debug(
            "Tool results continuation - iteration: \(new.iterationCount), results: \(results.count)"
        )
        return new
    }

    internal func continueWithPrompt(_: String) -> Self {
        var new: Self = self
        new.iterationCount += 1
        return new
    }

    internal func markComplete() -> Self {
        var new: Self = self
        new.isComplete = true
        return new
    }
}

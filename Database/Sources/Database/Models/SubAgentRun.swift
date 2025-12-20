import Foundation
import SwiftData
import Abstractions

/// A record of a sub-agent execution
@Model
@DebugDescription
public final class SubAgentRun: Identifiable, Equatable {
    // MARK: - Identity

    /// A unique identifier for the run
    @Attribute(.unique)
    public private(set) var id: UUID = UUID()

    /// The creation date of the run
    @Attribute()
    public private(set) var createdAt: Date = Date()

    /// When the run completed
    @Attribute()
    public internal(set) var completedAt: Date?

    // MARK: - Request Info

    /// The prompt/task for the sub-agent
    @Attribute()
    public private(set) var prompt: String

    /// The execution mode (background, parallel, sequential)
    @Attribute()
    public private(set) var modeRaw: String

    /// The execution mode
    public var mode: SubAgentMode {
        SubAgentMode(rawValue: modeRaw) ?? .background
    }

    /// Tools available to the sub-agent (stored as raw strings)
    @Attribute()
    public private(set) var tools: [String]

    // MARK: - Result Info

    /// The status of the run (running, completed, failed, cancelled, timedOut)
    @Attribute()
    public internal(set) var statusRaw: String

    /// The run status
    public var status: SubAgentStatus {
        SubAgentStatus(rawValue: statusRaw) ?? .running
    }

    /// The output text
    @Attribute()
    public internal(set) var output: String

    /// Tools that were actually used
    @Attribute()
    public internal(set) var toolsUsed: [String]

    /// Duration in milliseconds
    @Attribute()
    public internal(set) var durationMs: Int

    /// Error message if failed
    @Attribute()
    public internal(set) var errorMessage: String?

    // MARK: - Relationships

    /// The parent message that spawned this sub-agent
    @Relationship(deleteRule: .nullify)
    public private(set) var parentMessage: Message?

    /// The chat this run belongs to
    @Relationship(deleteRule: .nullify)
    public private(set) var chat: Chat?

    /// The user who owns this run
    @Relationship(deleteRule: .nullify)
    public private(set) var user: User?

    // MARK: - Initializer

    init(
        prompt: String,
        mode: SubAgentMode,
        tools: [String] = [],
        parentMessage: Message? = nil,
        chat: Chat? = nil,
        user: User? = nil
    ) {
        self.prompt = prompt
        self.modeRaw = mode.rawValue
        self.tools = tools
        self.statusRaw = SubAgentStatus.running.rawValue
        self.output = ""
        self.toolsUsed = []
        self.durationMs = 0
        self.parentMessage = parentMessage
        self.chat = chat
        self.user = user
    }

    // MARK: - Update Methods

    /// Mark the run as completed
    internal func markCompleted(output: String, toolsUsed: [String], durationMs: Int) {
        self.statusRaw = SubAgentStatus.completed.rawValue
        self.output = output
        self.toolsUsed = toolsUsed
        self.durationMs = durationMs
        self.completedAt = Date()
    }

    /// Mark the run as failed
    internal func markFailed(error: String, durationMs: Int) {
        self.statusRaw = SubAgentStatus.failed.rawValue
        self.errorMessage = error
        self.durationMs = durationMs
        self.completedAt = Date()
    }

    /// Mark the run as cancelled
    internal func markCancelled(durationMs: Int) {
        self.statusRaw = SubAgentStatus.cancelled.rawValue
        self.durationMs = durationMs
        self.completedAt = Date()
    }

    /// Mark the run as timed out
    internal func markTimedOut(durationMs: Int) {
        self.statusRaw = SubAgentStatus.timedOut.rawValue
        self.errorMessage = "Sub-agent execution timed out"
        self.durationMs = durationMs
        self.completedAt = Date()
    }

    // MARK: - Sendable Conversion

    /// Convert to a result
    public func toResult() -> SubAgentResult {
        SubAgentResult(
            id: id,
            output: output,
            durationMs: durationMs,
            status: status,
            toolsUsed: toolsUsed,
            errorMessage: errorMessage,
            completedAt: completedAt ?? Date()
        )
    }
}

#if DEBUG

extension SubAgentRun {
    @MainActor public static let preview: SubAgentRun = {
        let run = SubAgentRun(
            prompt: "Research the latest Swift concurrency features",
            mode: .background,
            tools: ["browser.search", "duckduckgo_search"]
        )
        run.markCompleted(
            output: "Swift 6 introduces several new concurrency features...",
            toolsUsed: ["duckduckgo_search"],
            durationMs: 5_000
        )
        return run
    }()

    @MainActor public static let runningPreview: SubAgentRun = {
        SubAgentRun(
            prompt: "Analyze code for potential improvements",
            mode: .parallel,
            tools: ["python_exec"]
        )
    }()
}

#endif

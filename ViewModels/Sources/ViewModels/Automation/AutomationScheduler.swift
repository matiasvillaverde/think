import Abstractions
import Database
import Foundation
import OSLog

/// Schedules and executes automation tasks based on stored cron/one-shot entries.
public actor AutomationScheduler {
    private let database: DatabaseProtocol
    private let orchestrator: AgentOrchestrating
    private let logger: Logger = Logger(subsystem: "ViewModels", category: "AutomationScheduler")
    private let pollInterval: TimeInterval

    private var task: Task<Void, Never>?

    /// Creates a scheduler with a polling interval.
    /// - Parameters:
    ///   - database: Database instance for schedule storage.
    ///   - orchestrator: Orchestrator used to run scheduled prompts.
    ///   - pollInterval: Polling interval in seconds.
    public init(
        database: DatabaseProtocol,
        orchestrator: AgentOrchestrating,
        pollInterval: TimeInterval = 60
    ) {
        self.database = database
        self.orchestrator = orchestrator
        self.pollInterval = pollInterval
    }

    /// Starts the polling loop if not already running.
    public func start() {
        guard task == nil else {
            return
        }
        task = Task { [weak self] in
            guard let self else {
                return
            }
            while !Task.isCancelled {
                await runOnce()
                try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            }
        }
    }

    /// Stops the polling loop.
    public func stop() {
        task?.cancel()
        task = nil
    }

    /// Runs a single polling cycle for due schedules.
    public func runOnce() async {
        do {
            let due: [AutomationScheduleSnapshot] = try await fetchDueScheduleSnapshots()
            for schedule in due {
                await execute(schedule)
            }
        } catch {
            logger.error("Failed to fetch due schedules: \(error.localizedDescription)")
        }
    }

    private func execute(_ schedule: AutomationScheduleSnapshot) async {
        guard let chatId = schedule.chatId else {
            logger.error("Automation schedule missing chat id: \(schedule.id)")
            return
        }

        _ = try? await database.write(
            AutomationScheduleCommands.MarkRunning(id: schedule.id)
        )

        do {
            try await orchestrator.load(chatId: chatId)
            let action: Action = buildAction(for: schedule)
            try await orchestrator.generate(prompt: schedule.prompt, action: action)
            try? await orchestrator.unload()
        } catch {
            logger.error("Schedule execution failed: \(error.localizedDescription)")
        }

        _ = try? await database.write(
            AutomationScheduleCommands.MarkCompleted(id: schedule.id, finishedAt: Date())
        )
    }

    private func buildAction(for schedule: AutomationScheduleSnapshot) -> Action {
        let toolIdentifiers: Set<ToolIdentifier> = Set(
            schedule.toolNames.compactMap(ToolIdentifier.from(toolName:))
        )
        switch schedule.actionType {
        case .image:
            return .imageGeneration(toolIdentifiers)

        case .text:
            return .textGeneration(toolIdentifiers)
        }
    }

    @MainActor
    private func fetchDueScheduleSnapshots() async throws -> [AutomationScheduleSnapshot] {
        let due: [AutomationSchedule] = try await database.read(
            AutomationScheduleCommands.FetchDue()
        )
        return due.map { schedule in
            AutomationScheduleSnapshot(
                id: schedule.id,
                prompt: schedule.prompt,
                actionType: schedule.actionType,
                toolNames: schedule.toolNames,
                chatId: schedule.chat?.id
            )
        }
    }
}

private struct AutomationScheduleSnapshot: Sendable {
    let id: UUID
    let prompt: String
    let actionType: AutomationActionType
    let toolNames: [String]
    let chatId: UUID?
}

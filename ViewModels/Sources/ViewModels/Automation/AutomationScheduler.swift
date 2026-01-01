import Abstractions
import Database
import Foundation
import OSLog

public actor AutomationScheduler {
    private let database: DatabaseProtocol
    private let orchestrator: AgentOrchestrating
    private let logger: Logger = Logger(subsystem: "ViewModels", category: "AutomationScheduler")
    private let pollInterval: TimeInterval

    private var task: Task<Void, Never>?

    public init(
        database: DatabaseProtocol,
        orchestrator: AgentOrchestrating,
        pollInterval: TimeInterval = 60
    ) {
        self.database = database
        self.orchestrator = orchestrator
        self.pollInterval = pollInterval
    }

    public func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.runOnce()
                try? await Task.sleep(nanoseconds: UInt64(self.pollInterval * 1_000_000_000))
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
    }

    public func runOnce() async {
        do {
            let due = try await database.read(AutomationScheduleCommands.FetchDue())
            for schedule in due {
                await execute(schedule)
            }
        } catch {
            logger.error("Failed to fetch due schedules: \(error.localizedDescription)")
        }
    }

    private func execute(_ schedule: AutomationSchedule) async {
        guard let chatId = schedule.chat?.id else {
            logger.error("Automation schedule missing chat id: \(schedule.id)")
            return
        }

        _ = try? await database.write(
            AutomationScheduleCommands.MarkRunning(id: schedule.id)
        )

        do {
            try await orchestrator.load(chatId: chatId)
            let action = buildAction(for: schedule)
            try await orchestrator.generate(prompt: schedule.prompt, action: action)
            try? await orchestrator.unload()
        } catch {
            logger.error("Schedule execution failed: \(error.localizedDescription)")
        }

        _ = try? await database.write(
            AutomationScheduleCommands.MarkCompleted(id: schedule.id, finishedAt: Date())
        )
    }

    private func buildAction(for schedule: AutomationSchedule) -> Action {
        let toolIdentifiers = Set(schedule.toolNames.compactMap(ToolIdentifier.from(toolName:)))
        switch schedule.actionType {
        case .image:
            return .imageGeneration(toolIdentifiers)
        case .text:
            return .textGeneration(toolIdentifiers)
        }
    }
}

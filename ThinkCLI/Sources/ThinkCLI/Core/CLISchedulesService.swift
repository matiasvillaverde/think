import Abstractions
import Database
import Foundation

enum CLISchedulesService {
    static func list(runtime: CLIRuntime, chatId: UUID?) async throws {
        let summaries = try await Task { @MainActor in
            let schedules = try await runtime.database.read(
                AutomationScheduleCommands.List(chatId: chatId)
            )
            return schedules.map(ScheduleSummary.init(schedule:))
        }.value
        let fallback = summaries.isEmpty
            ? "No schedules."
            : summaries.map { "\($0.id.uuidString)  \($0.title)" }.joined(separator: "\n")
        runtime.output.emit(summaries, fallback: fallback)
    }

    static func create(
        runtime: CLIRuntime,
        title: String,
        prompt: String,
        cronExpression: String,
        scheduleKind: AutomationScheduleKind,
        actionType: AutomationActionType,
        timezoneIdentifier: String?,
        toolNames: [String],
        isEnabled: Bool,
        chatId: UUID?
    ) async throws {
        let scheduleId = try await runtime.database.write(
            AutomationScheduleCommands.Create(
                title: title,
                prompt: prompt,
                scheduleKind: scheduleKind,
                actionType: actionType,
                cronExpression: cronExpression,
                timezoneIdentifier: timezoneIdentifier,
                toolNames: toolNames,
                isEnabled: isEnabled,
                chatId: chatId
            )
        )
        runtime.output.emit("Created schedule \(scheduleId.uuidString)")
    }

    static func update(
        runtime: CLIRuntime,
        scheduleId: UUID,
        title: String?,
        prompt: String?,
        cronExpression: String?,
        timezoneIdentifier: String?,
        toolNames: [String]?,
        actionType: AutomationActionType?,
        scheduleKind: AutomationScheduleKind?
    ) async throws {
        _ = try await runtime.database.write(
            AutomationScheduleCommands.Update(
                id: scheduleId,
                title: title,
                prompt: prompt,
                cronExpression: cronExpression,
                timezoneIdentifier: timezoneIdentifier,
                toolNames: toolNames,
                actionType: actionType,
                scheduleKind: scheduleKind
            )
        )
        runtime.output.emit("Updated schedule \(scheduleId.uuidString)")
    }

    static func enable(runtime: CLIRuntime, scheduleId: UUID) async throws {
        _ = try await runtime.database.write(
            AutomationScheduleCommands.SetEnabled(id: scheduleId, isEnabled: true)
        )
        runtime.output.emit("Enabled schedule \(scheduleId.uuidString)")
    }

    static func disable(runtime: CLIRuntime, scheduleId: UUID) async throws {
        _ = try await runtime.database.write(
            AutomationScheduleCommands.SetEnabled(id: scheduleId, isEnabled: false)
        )
        runtime.output.emit("Disabled schedule \(scheduleId.uuidString)")
    }

    static func delete(runtime: CLIRuntime, scheduleId: UUID) async throws {
        _ = try await runtime.database.write(
            AutomationScheduleCommands.Delete(id: scheduleId)
        )
        runtime.output.emit("Deleted schedule \(scheduleId.uuidString)")
    }
}

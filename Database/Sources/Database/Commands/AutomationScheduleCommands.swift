import Abstractions
import Foundation
import OSLog
import SwiftData

// MARK: - Automation Schedule Commands

public enum AutomationScheduleCommands {}

extension AutomationScheduleCommands {
    /// Creates a new automation schedule.
    public struct Create: WriteCommand {
        private let title: String
        private let prompt: String
        private let scheduleKind: AutomationScheduleKind
        private let actionType: AutomationActionType
        private let cronExpression: String
        private let timezoneIdentifier: String?
        private let toolNames: [String]
        private let isEnabled: Bool
        private let chatId: UUID?

        public init(
            title: String,
            prompt: String,
            scheduleKind: AutomationScheduleKind,
            actionType: AutomationActionType,
            cronExpression: String,
            timezoneIdentifier: String? = nil,
            toolNames: [String] = [],
            isEnabled: Bool = true,
            chatId: UUID?
        ) {
            self.title = title
            self.prompt = prompt
            self.scheduleKind = scheduleKind
            self.actionType = actionType
            self.cronExpression = cronExpression
            self.timezoneIdentifier = timezoneIdentifier
            self.toolNames = toolNames
            self.isEnabled = isEnabled
            self.chatId = chatId
            Logger.database.info("AutomationScheduleCommands.Create initialized")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("AutomationScheduleCommands.Create.execute started")

            guard let userId else {
                throw DatabaseError.userNotFound
            }

            let user = try context.getUser(id: userId)

            let chat: Chat? = try fetchChat(in: context, user: user)
            let nextRunAt: Date? = try computeNextRunAt(after: Date())

            let schedule = AutomationSchedule(
                title: title,
                prompt: prompt,
                scheduleKind: scheduleKind,
                actionType: actionType,
                cronExpression: cronExpression,
                timezoneIdentifier: timezoneIdentifier,
                toolNames: toolNames,
                isEnabled: isEnabled,
                chat: chat
            )
            schedule.nextRunAt = isEnabled ? nextRunAt : nil

            context.insert(schedule)
            try context.save()

            Logger.database.info("Automation schedule created: \(schedule.id)")
            return schedule.id
        }

        private func fetchChat(in context: ModelContext, user: User) throws -> Chat? {
            guard let chatId else {
                return nil
            }

            guard user.chats.contains(where: { $0.id == chatId }) else {
                Logger.database.error("Automation schedule chat not found")
                throw DatabaseError.chatNotFound
            }

            let descriptor = FetchDescriptor<Chat>(
                predicate: #Predicate<Chat> { $0.id == chatId }
            )
            return try context.fetch(descriptor).first
        }

        private func computeNextRunAt(after date: Date) throws -> Date? {
            guard isEnabled else {
                return nil
            }

            switch scheduleKind {
            case .cron:
                let expression: CronExpression
                do {
                    expression = try CronExpression(cronExpression)
                } catch {
                    throw DatabaseError.invalidInput("Invalid cron expression: \(cronExpression)")
                }
                let calendar = Calendar(identifier: .gregorian).withTimeZone(identifier: timezoneIdentifier)
                return expression.nextDate(after: date, calendar: calendar)

            case .oneShot:
                guard let oneShotDate = Self.parseOneShotDate(cronExpression) else {
                    throw DatabaseError.invalidInput("Invalid one-shot date: \(cronExpression)")
                }
                return oneShotDate
            }
        }
    }

    /// Fetch a schedule by id.
    public struct Get: ReadCommand {
        private let id: UUID

        public init(id: UUID) {
            self.id = id
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> AutomationSchedule {
            let descriptor = FetchDescriptor<AutomationSchedule>(
                predicate: #Predicate<AutomationSchedule> { $0.id == id }
            )
            guard let schedule = try context.fetch(descriptor).first else {
                throw DatabaseError.invalidInput("Automation schedule not found")
            }
            return schedule
        }
    }

    /// List schedules, optionally filtered by chat.
    public struct List: ReadCommand {
        private let chatId: UUID?

        public init(chatId: UUID? = nil) {
            self.chatId = chatId
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> [AutomationSchedule] {
            if let chatId {
                let descriptor = FetchDescriptor<AutomationSchedule>(
                    predicate: #Predicate<AutomationSchedule> { schedule in
                        schedule.chat?.id == chatId
                    }
                )
                return try context.fetch(descriptor)
            }

            let descriptor = FetchDescriptor<AutomationSchedule>()
            return try context.fetch(descriptor)
        }
    }

    /// Fetch schedules that are due to run.
    public struct FetchDue: ReadCommand {
        private let now: Date

        public init(now: Date = Date()) {
            self.now = now
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> [AutomationSchedule] {
            let descriptor = FetchDescriptor<AutomationSchedule>()
            let schedules = try context.fetch(descriptor)

            return schedules.filter { schedule in
                guard schedule.isEnabled, schedule.isRunning == false else {
                    return false
                }
                guard let nextRunAt = schedule.nextRunAt else {
                    return false
                }
                return nextRunAt <= now
            }
        }
    }

    /// Marks a schedule as running.
    public struct MarkRunning: WriteCommand {
        private let id: UUID

        public init(id: UUID) {
            self.id = id
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            let schedule = try AutomationScheduleCommands.Get(id: id).execute(
                in: context,
                userId: userId,
                rag: rag
            )
            schedule.isRunning = true
            schedule.updatedAt = Date()
            try context.save()
            return schedule.id
        }
    }

    /// Marks a schedule as completed and calculates the next run time.
    public struct MarkCompleted: WriteCommand {
        private let id: UUID
        private let finishedAt: Date

        public init(id: UUID, finishedAt: Date = Date()) {
            self.id = id
            self.finishedAt = finishedAt
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            let schedule = try AutomationScheduleCommands.Get(id: id).execute(
                in: context,
                userId: userId,
                rag: rag
            )

            schedule.lastRunAt = finishedAt
            schedule.isRunning = false
            schedule.updatedAt = Date()

            switch schedule.scheduleKind {
            case .cron:
                do {
                    let expression = try CronExpression(schedule.cronExpression)
                    let calendar = Calendar(identifier: .gregorian)
                        .withTimeZone(identifier: schedule.timezoneIdentifier)
                    schedule.nextRunAt = expression.nextDate(after: finishedAt, calendar: calendar)
                } catch {
                    schedule.nextRunAt = nil
                    schedule.isEnabled = false
                }

            case .oneShot:
                schedule.nextRunAt = nil
                schedule.isEnabled = false
            }

            try context.save()
            return schedule.id
        }
    }

    /// Enables or disables a schedule.
    public struct SetEnabled: WriteCommand {
        private let id: UUID
        private let isEnabled: Bool

        public init(id: UUID, isEnabled: Bool) {
            self.id = id
            self.isEnabled = isEnabled
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            let schedule = try AutomationScheduleCommands.Get(id: id).execute(
                in: context,
                userId: userId,
                rag: rag
            )
            schedule.isEnabled = isEnabled
            schedule.isRunning = false
            schedule.updatedAt = Date()

            if isEnabled {
                let nextRunAt = try AutomationScheduleCommands.computeNextRun(
                    schedule: schedule,
                    after: Date()
                )
                schedule.nextRunAt = nextRunAt
            } else {
                schedule.nextRunAt = nil
            }

            try context.save()
            return schedule.id
        }
    }

    /// Updates schedule details.
    public struct Update: WriteCommand {
        private let id: UUID
        private let title: String?
        private let prompt: String?
        private let cronExpression: String?
        private let timezoneIdentifier: String?
        private let toolNames: [String]?
        private let actionType: AutomationActionType?
        private let scheduleKind: AutomationScheduleKind?

        public init(
            id: UUID,
            title: String? = nil,
            prompt: String? = nil,
            cronExpression: String? = nil,
            timezoneIdentifier: String? = nil,
            toolNames: [String]? = nil,
            actionType: AutomationActionType? = nil,
            scheduleKind: AutomationScheduleKind? = nil
        ) {
            self.id = id
            self.title = title
            self.prompt = prompt
            self.cronExpression = cronExpression
            self.timezoneIdentifier = timezoneIdentifier
            self.toolNames = toolNames
            self.actionType = actionType
            self.scheduleKind = scheduleKind
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            let schedule = try AutomationScheduleCommands.Get(id: id).execute(
                in: context,
                userId: userId,
                rag: rag
            )

            if let title { schedule.title = title }
            if let prompt { schedule.prompt = prompt }
            if let cronExpression { schedule.cronExpression = cronExpression }
            if let timezoneIdentifier { schedule.timezoneIdentifier = timezoneIdentifier }
            if let toolNames { schedule.toolNames = toolNames }
            if let actionType { schedule.actionType = actionType }
            if let scheduleKind { schedule.scheduleKind = scheduleKind }

            schedule.updatedAt = Date()

            if schedule.isEnabled {
                schedule.nextRunAt = try AutomationScheduleCommands.computeNextRun(
                    schedule: schedule,
                    after: Date()
                )
            }

            try context.save()
            return schedule.id
        }
    }

    /// Deletes a schedule.
    public struct Delete: WriteCommand {
        private let id: UUID

        public init(id: UUID) {
            self.id = id
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            let schedule = try AutomationScheduleCommands.Get(id: id).execute(
                in: context,
                userId: userId,
                rag: rag
            )
            context.delete(schedule)
            try context.save()
            return schedule.id
        }
    }

    internal static func computeNextRun(
        schedule: AutomationSchedule,
        after date: Date
    ) throws -> Date? {
        switch schedule.scheduleKind {
        case .cron:
            let expression = try CronExpression(schedule.cronExpression)
            let calendar = Calendar(identifier: .gregorian)
                .withTimeZone(identifier: schedule.timezoneIdentifier)
            return expression.nextDate(after: date, calendar: calendar)

        case .oneShot:
            return parseOneShotDate(schedule.cronExpression)
        }
    }

    internal static func parseOneShotDate(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let timestamp = Double(trimmed) {
            if timestamp > 1_000_000_000_000 {
                return Date(timeIntervalSince1970: timestamp / 1_000)
            }
            return Date(timeIntervalSince1970: timestamp)
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: trimmed) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: trimmed)
    }
}

private extension Calendar {
    func withTimeZone(identifier: String?) -> Calendar {
        guard let identifier,
              let timeZone = TimeZone(identifier: identifier) else {
            return self
        }
        var copy = self
        copy.timeZone = timeZone
        return copy
    }
}

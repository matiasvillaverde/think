import Foundation
import SwiftData
import OSLog
import Abstractions

// MARK: - Memory Delete Commands
extension MemoryCommands {
    /// Deletes a memory by ID
    public struct Delete: WriteCommand {
        private let memoryId: UUID

        public var requiresUser: Bool { false }
        public var requiresRag: Bool { false }

        /// Initialize a Delete command
        /// - Parameter memoryId: The ID of the memory to delete
        public init(memoryId: UUID) {
            self.memoryId = memoryId
            Logger.database.info("MemoryCommands.Delete initialized for memory: \(memoryId)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("MemoryCommands.Delete.execute started for memory: \(memoryId)")

            let descriptor = FetchDescriptor<Memory>(
                predicate: #Predicate<Memory> { $0.id == memoryId }
            )

            guard let memory = try context.fetch(descriptor).first else {
                Logger.database.error("MemoryCommands.Delete.execute failed: memory not found")
                throw DatabaseError.memoryNotFound
            }

            let deletedId = memory.id
            context.delete(memory)
            try context.save()

            Logger.database.info("MemoryCommands.Delete.execute completed successfully")
            return deletedId
        }
    }

    /// Deletes all memories of a specific type for the current user
    public struct DeleteByType: WriteCommand {
        private let type: MemoryType
        private let chatId: UUID?

        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        /// Initialize a DeleteByType command
        /// - Parameters:
        ///   - type: The type of memories to delete
        ///   - chatId: Optional chat filter (nil for global memories only)
        public init(type: MemoryType, chatId: UUID? = nil) {
            self.type = type
            self.chatId = chatId
            Logger.database.info("MemoryCommands.DeleteByType initialized for type: \(type.rawValue)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("MemoryCommands.DeleteByType.execute started for type: \(type.rawValue)")

            guard let userId else {
                Logger.database.error("MemoryCommands.DeleteByType.execute failed: user not found")
                throw DatabaseError.userNotFound
            }

            let user = try context.getUser(id: userId)

            let typeRawValue = type.rawValue
            let descriptor = FetchDescriptor<Memory>(
                predicate: #Predicate<Memory> { memory in
                    memory.typeRaw == typeRawValue
                }
            )
            let memories = try context.fetch(descriptor)
            let memoriesToDelete = memories.filter { memory in
                memory.user?.id == user.id &&
                (chatId == nil ? memory.chat == nil : memory.chat?.id == chatId)
            }

            Logger.database.info("Deleting \(memoriesToDelete.count) memories of type: \(type.rawValue)")

            for memory in memoriesToDelete {
                context.delete(memory)
            }
            try context.save()

            Logger.database.info("MemoryCommands.DeleteByType.execute completed successfully")
            return user.id
        }
    }

    /// Deletes daily logs older than a specified number of days
    public struct PruneDailyLogs: WriteCommand {
        private let olderThanDays: Int

        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        /// Initialize a PruneDailyLogs command
        /// - Parameter olderThanDays: Delete logs older than this many days
        public init(olderThanDays: Int) {
            self.olderThanDays = olderThanDays
            Logger.database.info("MemoryCommands.PruneDailyLogs initialized with days: \(olderThanDays)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("MemoryCommands.PruneDailyLogs.execute started")

            guard let userId else {
                Logger.database.error("MemoryCommands.PruneDailyLogs.execute failed: user not found")
                throw DatabaseError.userNotFound
            }

            let user = try context.getUser(id: userId)

            let calendar = Calendar.current
            let cutoffDate = calendar.date(byAdding: .day, value: -olderThanDays, to: Date()) ?? Date()

            let dailyType = MemoryType.daily.rawValue
            let descriptor = FetchDescriptor<Memory>(
                predicate: #Predicate<Memory> { memory in
                    memory.typeRaw == dailyType
                }
            )
            let dailyLogs = try context.fetch(descriptor)
            let logsToDelete = dailyLogs.filter { memory in
                memory.user?.id == user.id &&
                memory.date != nil &&
                memory.date! < cutoffDate
            }

            Logger.database.info("Pruning \(logsToDelete.count) daily logs older than \(olderThanDays) days")

            for log in logsToDelete {
                context.delete(log)
            }
            try context.save()

            Logger.database.info("MemoryCommands.PruneDailyLogs.execute completed successfully")
            return user.id
        }
    }
}

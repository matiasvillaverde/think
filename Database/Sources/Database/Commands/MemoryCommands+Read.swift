import Foundation
import SwiftData
import OSLog
import Abstractions

// MARK: - Memory Read Commands
extension MemoryCommands {
    /// Reads a single memory by ID
    public struct Read: ReadCommand {
        public typealias Result = Memory

        private let memoryId: UUID

        public var requiresUser: Bool { false }
        public var requiresRag: Bool { false }

        /// Initialize a Read command
        /// - Parameter memoryId: The ID of the memory to read
        public init(memoryId: UUID) {
            self.memoryId = memoryId
            Logger.database.info("MemoryCommands.Read initialized with memoryId: \(memoryId)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> Memory {
            Logger.database.info("MemoryCommands.Read.execute started for memory: \(memoryId)")

            let descriptor = FetchDescriptor<Memory>(
                predicate: #Predicate<Memory> { $0.id == memoryId }
            )

            let memories = try context.fetch(descriptor)
            guard let memory = memories.first else {
                Logger.database.error("MemoryCommands.Read.execute failed: memory not found")
                throw DatabaseError.memoryNotFound
            }

            Logger.database.info("MemoryCommands.Read.execute completed successfully")
            return memory
        }
    }

    /// Gets all memories for the current user
    public struct GetAll: ReadCommand {
        public typealias Result = [Memory]

        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        public init() {
            Logger.database.info("MemoryCommands.GetAll initialized")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> [Memory] {
            Logger.database.info("MemoryCommands.GetAll.execute started")

            guard let userId else {
                Logger.database.error("MemoryCommands.GetAll.execute failed: user not found")
                throw DatabaseError.userNotFound
            }

            let user = try context.getUser(id: userId)

            let descriptor = FetchDescriptor<Memory>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            let allMemories = try context.fetch(descriptor)
            let userMemories = allMemories.filter { $0.user?.id == user.id }

            Logger.database.info("MemoryCommands.GetAll.execute completed - found \(userMemories.count) memories")
            return userMemories
        }
    }

    /// Gets memories by type for the current user
    public struct GetByType: ReadCommand {
        public typealias Result = [Memory]

        private let type: MemoryType
        private let chatId: UUID?

        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        /// Initialize a GetByType command
        /// - Parameters:
        ///   - type: The type of memories to retrieve
        ///   - chatId: Optional chat filter (nil for global memories)
        public init(type: MemoryType, chatId: UUID? = nil) {
            self.type = type
            self.chatId = chatId
            Logger.database.info("MemoryCommands.GetByType initialized with type: \(type.rawValue)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> [Memory] {
            Logger.database.info("MemoryCommands.GetByType.execute started for type: \(type.rawValue)")

            guard let userId else {
                Logger.database.error("MemoryCommands.GetByType.execute failed: user not found")
                throw DatabaseError.userNotFound
            }

            let user = try context.getUser(id: userId)

            let typeRawValue = type.rawValue
            let descriptor = FetchDescriptor<Memory>(
                predicate: #Predicate<Memory> { memory in
                    memory.typeRaw == typeRawValue
                },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            let allMemories = try context.fetch(descriptor)
            let filteredMemories = allMemories.filter { memory in
                memory.user?.id == user.id &&
                (chatId == nil || memory.chat?.id == chatId)
            }

            Logger.database.info("MemoryCommands.GetByType.execute completed - found \(filteredMemories.count) memories")
            return filteredMemories
        }
    }

    /// Gets the soul memory for the current user
    public struct GetSoul: ReadCommand {
        public typealias Result = Memory?

        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        public init() {
            Logger.database.info("MemoryCommands.GetSoul initialized")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> Memory? {
            Logger.database.info("MemoryCommands.GetSoul.execute started")

            guard let userId else {
                Logger.database.error("MemoryCommands.GetSoul.execute failed: user not found")
                throw DatabaseError.userNotFound
            }

            let user = try context.getUser(id: userId)

            let soulType = MemoryType.soul.rawValue
            let descriptor = FetchDescriptor<Memory>(
                predicate: #Predicate<Memory> { memory in
                    memory.typeRaw == soulType && memory.chat == nil
                }
            )
            let memories = try context.fetch(descriptor)
            let soul = memories.first { $0.user?.id == user.id }

            Logger.database.info("MemoryCommands.GetSoul.execute completed - soul found: \(soul != nil)")
            return soul
        }
    }

    /// Gets recent daily logs (last N days)
    public struct GetRecentDailyLogs: ReadCommand {
        public typealias Result = [Memory]

        private let days: Int
        private let chatId: UUID?

        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        /// Initialize a GetRecentDailyLogs command
        /// - Parameters:
        ///   - days: Number of days to look back (default: 2)
        ///   - chatId: Optional chat filter
        public init(days: Int = 2, chatId: UUID? = nil) {
            self.days = days
            self.chatId = chatId
            Logger.database.info("MemoryCommands.GetRecentDailyLogs initialized with days: \(days)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> [Memory] {
            Logger.database.info("MemoryCommands.GetRecentDailyLogs.execute started")

            guard let userId else {
                Logger.database.error("MemoryCommands.GetRecentDailyLogs.execute failed: user not found")
                throw DatabaseError.userNotFound
            }

            let user = try context.getUser(id: userId)

            let calendar = Calendar.current
            let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()

            let dailyType = MemoryType.daily.rawValue
            let descriptor = FetchDescriptor<Memory>(
                predicate: #Predicate<Memory> { memory in
                    memory.typeRaw == dailyType
                },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            let dailyLogs = try context.fetch(descriptor)
            let filteredLogs = dailyLogs.filter { memory in
                memory.user?.id == user.id &&
                (chatId == nil || memory.chat?.id == chatId) &&
                memory.date != nil &&
                memory.date! >= cutoffDate
            }

            Logger.database.info(
                "MemoryCommands.GetRecentDailyLogs.execute completed - found \(filteredLogs.count) logs"
            )
            return filteredLogs
        }
    }

    /// Gets the complete memory context for prompt injection
    public struct GetMemoryContext: ReadCommand {
        public typealias Result = MemoryContext

        private let chatId: UUID?
        private let dailyLogDays: Int

        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        /// Initialize a GetMemoryContext command
        /// - Parameters:
        ///   - chatId: Optional chat for chat-specific memories
        ///   - dailyLogDays: Number of days of daily logs to include (default: 2)
        public init(chatId: UUID? = nil, dailyLogDays: Int = 2) {
            self.chatId = chatId
            self.dailyLogDays = dailyLogDays
            Logger.database.info("MemoryCommands.GetMemoryContext initialized")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> MemoryContext {
            Logger.database.info("MemoryCommands.GetMemoryContext.execute started")

            guard let userId else {
                Logger.database.error("MemoryCommands.GetMemoryContext.execute failed: user not found")
                throw DatabaseError.userNotFound
            }

            // Get soul
            let soul = try GetSoul().execute(in: context, userId: userId, rag: rag)

            // Get long-term memories
            let longTermMemories = try GetByType(type: .longTerm, chatId: chatId)
                .execute(in: context, userId: userId, rag: rag)

            // Get recent daily logs
            let recentDailyLogs = try GetRecentDailyLogs(days: dailyLogDays, chatId: chatId)
                .execute(in: context, userId: userId, rag: rag)

            let memoryContext = MemoryContext(
                soul: soul?.toData,
                longTermMemories: longTermMemories.map(\.toData),
                recentDailyLogs: recentDailyLogs.map(\.toData)
            )

            Logger.database.info("""
                MemoryCommands.GetMemoryContext.execute completed - \
                soul: \(soul != nil), longTerm: \(longTermMemories.count), daily: \(recentDailyLogs.count)
                """)
            return memoryContext
        }
    }
}

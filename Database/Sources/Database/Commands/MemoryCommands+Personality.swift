import Foundation
import SwiftData
import OSLog
import Abstractions

// MARK: - Personality-Specific Memory Commands
extension MemoryCommands {
    /// Creates or updates the soul memory for a specific personality
    public struct UpsertPersonalitySoul: WriteCommand {
        private let personalityId: UUID
        private let content: String

        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        /// Initialize an UpsertPersonalitySoul command
        /// - Parameters:
        ///   - personalityId: The ID of the personality to associate the soul with
        ///   - content: The soul/persona content
        public init(personalityId: UUID, content: String) {
            self.personalityId = personalityId
            self.content = content
            Logger.database.info("MemoryCommands.UpsertPersonalitySoul initialized for personality: \(personalityId)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("MemoryCommands.UpsertPersonalitySoul.execute started")

            guard let userId else {
                Logger.database.error("MemoryCommands.UpsertPersonalitySoul.execute failed: user not found")
                throw DatabaseError.userNotFound
            }

            let user = try context.getUser(id: userId)

            // Find the personality
            let personalityDescriptor = FetchDescriptor<Personality>(
                predicate: #Predicate<Personality> { $0.id == personalityId }
            )
            guard let personality = try context.fetch(personalityDescriptor).first else {
                Logger.database.error("MemoryCommands.UpsertPersonalitySoul: personality not found")
                throw DatabaseError.personalityNotFound
            }

            // Try to find existing soul memory for this personality
            let soulType = MemoryType.soul.rawValue
            let descriptor = FetchDescriptor<Memory>(
                predicate: #Predicate<Memory> { memory in
                    memory.typeRaw == soulType
                }
            )
            let existingMemories = try context.fetch(descriptor)
            let existingSoul = existingMemories.first { $0.personality?.id == personalityId }

            if let existingSoul {
                Logger.database.info("Updating existing personality soul memory: \(existingSoul.id)")
                existingSoul.content = content
                existingSoul.updatedAt = Date()
                try context.save()
                return existingSoul.id
            } else {
                Logger.database.info("Creating new personality soul memory")
                let memory = Memory(
                    type: .soul,
                    content: content,
                    keywords: ["soul", "persona", "identity"],
                    user: user,
                    personality: personality
                )
                context.insert(memory)
                try context.save()
                Logger.database.info(
                    "MemoryCommands.UpsertPersonalitySoul.execute completed - memory id: \(memory.id)"
                )
                return memory.id
            }
        }
    }

    /// Creates a memory entry associated with a specific personality
    public struct CreatePersonalityMemory: WriteCommand {
        private let personalityId: UUID
        private let type: MemoryType
        private let content: String
        private let date: Date?
        private let keywords: [String]

        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        /// Initialize a CreatePersonalityMemory command
        /// - Parameters:
        ///   - personalityId: The ID of the personality to associate the memory with
        ///   - type: The type of memory to create
        ///   - content: The content of the memory
        ///   - date: For daily logs, the date this entry refers to
        ///   - keywords: Keywords for semantic search
        public init(
            personalityId: UUID,
            type: MemoryType,
            content: String,
            date: Date? = nil,
            keywords: [String] = []
        ) {
            self.personalityId = personalityId
            self.type = type
            self.content = content
            self.date = date
            self.keywords = keywords
            Logger.database.info(
                "MemoryCommands.CreatePersonalityMemory initialized for personality: \(personalityId)"
            )
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("MemoryCommands.CreatePersonalityMemory.execute started")

            guard let userId else {
                Logger.database.error("MemoryCommands.CreatePersonalityMemory.execute failed: user not found")
                throw DatabaseError.userNotFound
            }

            let user = try context.getUser(id: userId)

            // Find the personality
            let personalityDescriptor = FetchDescriptor<Personality>(
                predicate: #Predicate<Personality> { $0.id == personalityId }
            )
            guard let personality = try context.fetch(personalityDescriptor).first else {
                Logger.database.error("MemoryCommands.CreatePersonalityMemory: personality not found")
                throw DatabaseError.personalityNotFound
            }

            Logger.database.info("Creating new personality memory of type: \(type.rawValue)")
            let memory = Memory(
                type: type,
                content: content,
                date: date,
                keywords: keywords,
                user: user,
                personality: personality
            )
            context.insert(memory)

            Logger.database.info("Saving context changes")
            try context.save()

            Logger.database.info(
                "MemoryCommands.CreatePersonalityMemory.execute completed - memory id: \(memory.id)"
            )
            return memory.id
        }
    }

    /// Appends content to today's daily log for a specific personality
    public struct AppendToPersonalityDaily: WriteCommand {
        private let personalityId: UUID
        private let content: String
        private let chatId: UUID?

        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        /// Initialize an AppendToPersonalityDaily command
        /// - Parameters:
        ///   - personalityId: The ID of the personality to associate the daily log with
        ///   - content: The content to append
        ///   - chatId: Optional chat association
        public init(personalityId: UUID, content: String, chatId: UUID? = nil) {
            self.personalityId = personalityId
            self.content = content
            self.chatId = chatId
            Logger.database.info(
                "MemoryCommands.AppendToPersonalityDaily initialized for personality: \(personalityId)"
            )
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("MemoryCommands.AppendToPersonalityDaily.execute started")

            guard let userId else {
                Logger.database.error("MemoryCommands.AppendToPersonalityDaily.execute failed: user not found")
                throw DatabaseError.userNotFound
            }

            let user = try context.getUser(id: userId)

            // Find the personality
            let personalityDescriptor = FetchDescriptor<Personality>(
                predicate: #Predicate<Personality> { $0.id == personalityId }
            )
            guard let personality = try context.fetch(personalityDescriptor).first else {
                Logger.database.error("MemoryCommands.AppendToPersonalityDaily: personality not found")
                throw DatabaseError.personalityNotFound
            }

            // Get today's date (normalized to start of day)
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())

            // Find chat if provided
            var chat: Chat?
            if let chatId {
                let chatDescriptor = FetchDescriptor<Chat>(
                    predicate: #Predicate<Chat> { $0.id == chatId }
                )
                chat = try context.fetch(chatDescriptor).first
            }

            // Try to find existing daily log for today for this personality
            let dailyType = MemoryType.daily.rawValue
            let descriptor = FetchDescriptor<Memory>(
                predicate: #Predicate<Memory> { memory in
                    memory.typeRaw == dailyType
                }
            )
            let dailyMemories = try context.fetch(descriptor)
            let existingDaily = dailyMemories.first { memory in
                memory.personality?.id == personalityId &&
                memory.chat?.id == chat?.id &&
                memory.date != nil &&
                calendar.isDate(memory.date!, inSameDayAs: today)
            }

            if let existingDaily {
                Logger.database.info("Appending to existing personality daily log: \(existingDaily.id)")
                existingDaily.content = existingDaily.content + "\n" + content
                existingDaily.updatedAt = Date()
                try context.save()
                return existingDaily.id
            } else {
                Logger.database.info("Creating new personality daily log for today")
                let memory = Memory(
                    type: .daily,
                    content: content,
                    date: today,
                    keywords: ["daily"],
                    chat: chat,
                    user: user,
                    personality: personality
                )
                context.insert(memory)
                try context.save()
                Logger.database.info(
                    "MemoryCommands.AppendToPersonalityDaily.execute completed - memory id: \(memory.id)"
                )
                return memory.id
            }
        }
    }

    /// Gets the complete memory context for a specific personality
    public struct GetPersonalityMemoryContext: ReadCommand {
        public typealias Result = MemoryContext

        private let personalityId: UUID
        private let chatId: UUID?
        private let dailyLogDays: Int

        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        /// Initialize a GetPersonalityMemoryContext command
        /// - Parameters:
        ///   - personalityId: The ID of the personality
        ///   - chatId: Optional chat for chat-specific memories
        ///   - dailyLogDays: Number of days of daily logs to include (default: 2)
        public init(personalityId: UUID, chatId: UUID? = nil, dailyLogDays: Int = 2) {
            self.personalityId = personalityId
            self.chatId = chatId
            self.dailyLogDays = dailyLogDays
            Logger.database.info(
                "MemoryCommands.GetPersonalityMemoryContext initialized for personality: \(personalityId)"
            )
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> MemoryContext {
            Logger.database.info("MemoryCommands.GetPersonalityMemoryContext.execute started")

            guard let userId else {
                Logger.database.error("MemoryCommands.GetPersonalityMemoryContext: user not found")
                throw DatabaseError.userNotFound
            }

            let user = try context.getUser(id: userId)

            // Find the personality
            let personalityDescriptor = FetchDescriptor<Personality>(
                predicate: #Predicate<Personality> { $0.id == personalityId }
            )
            guard let personality = try context.fetch(personalityDescriptor).first else {
                Logger.database.error("MemoryCommands.GetPersonalityMemoryContext: personality not found")
                throw DatabaseError.personalityNotFound
            }

            // Get soul for personality
            let soulType = MemoryType.soul.rawValue
            let soulDescriptor = FetchDescriptor<Memory>(
                predicate: #Predicate<Memory> { memory in
                    memory.typeRaw == soulType
                }
            )
            let soulMemories = try context.fetch(soulDescriptor)
            let soul = soulMemories.first { $0.personality?.id == personality.id }

            // Get long-term memories for personality
            let longTermType = MemoryType.longTerm.rawValue
            let longTermDescriptor = FetchDescriptor<Memory>(
                predicate: #Predicate<Memory> { memory in
                    memory.typeRaw == longTermType
                },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            let allLongTermMemories = try context.fetch(longTermDescriptor)
            // Include memories that are:
            // 1. Global to the personality (no chat association), OR
            // 2. Specific to this chat (if chatId provided)
            let longTermMemories = allLongTermMemories.filter { memory in
                memory.personality?.id == personality.id &&
                memory.user?.id == user.id &&
                (memory.chat == nil || memory.chat?.id == chatId)
            }

            // Get recent daily logs for personality
            let calendar = Calendar.current
            let cutoffDate = calendar.date(byAdding: .day, value: -dailyLogDays, to: Date()) ?? Date()
            let dailyType = MemoryType.daily.rawValue
            let dailyDescriptor = FetchDescriptor<Memory>(
                predicate: #Predicate<Memory> { memory in
                    memory.typeRaw == dailyType
                },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            let allDailyLogs = try context.fetch(dailyDescriptor)
            // Include daily logs that are:
            // 1. Global to the personality (no chat association), OR
            // 2. Specific to this chat (if chatId provided)
            let recentDailyLogs = allDailyLogs.filter { memory in
                memory.personality?.id == personality.id &&
                memory.user?.id == user.id &&
                (memory.chat == nil || memory.chat?.id == chatId) &&
                memory.date != nil &&
                memory.date! >= cutoffDate
            }

            let memoryContext = MemoryContext(
                soul: soul?.toData,
                longTermMemories: longTermMemories.map(\.toData),
                recentDailyLogs: recentDailyLogs.map(\.toData)
            )

            Logger.database.info("""
                MemoryCommands.GetPersonalityMemoryContext.execute completed - \
                soul: \(soul != nil), longTerm: \(longTermMemories.count), daily: \(recentDailyLogs.count)
                """)
            return memoryContext
        }
    }
}

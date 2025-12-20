import Foundation
import SwiftData
import OSLog
import Abstractions

// MARK: - Memory Creation Commands
extension MemoryCommands {
    /// Creates a new memory entry
    public struct Create: WriteCommand {
        private let type: MemoryType
        private let content: String
        private let date: Date?
        private let keywords: [String]
        private let chatId: UUID?

        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        /// Initialize a Create command
        /// - Parameters:
        ///   - type: The type of memory to create
        ///   - content: The content of the memory
        ///   - date: For daily logs, the date this entry refers to
        ///   - keywords: Keywords for semantic search
        ///   - chatId: Optional chat association (nil for global memories)
        public init(
            type: MemoryType,
            content: String,
            date: Date? = nil,
            keywords: [String] = [],
            chatId: UUID? = nil
        ) {
            self.type = type
            self.content = content
            self.date = date
            self.keywords = keywords
            self.chatId = chatId
            Logger.database.info("MemoryCommands.Create initialized with type: \(type.rawValue)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("MemoryCommands.Create.execute started")

            guard let userId else {
                Logger.database.error("MemoryCommands.Create.execute failed: user not found")
                throw DatabaseError.userNotFound
            }

            Logger.database.info("Fetching user with id: \(userId.id.hashValue)")
            let user = try context.getUser(id: userId)
            Logger.database.info("Successfully fetched user: \(user.id)")

            // Find chat if chatId is provided
            var chat: Chat?
            if let chatId {
                let chatDescriptor = FetchDescriptor<Chat>(
                    predicate: #Predicate<Chat> { $0.id == chatId }
                )
                chat = try context.fetch(chatDescriptor).first
                if chat == nil {
                    Logger.database.warning("Chat not found for memory, creating global memory")
                }
            }

            Logger.database.info("Creating new memory of type: \(type.rawValue)")
            let memory = Memory(
                type: type,
                content: content,
                date: date,
                keywords: keywords,
                chat: chat,
                user: user
            )
            context.insert(memory)

            Logger.database.info("Saving context changes")
            try context.save()

            Logger.database.info("MemoryCommands.Create.execute completed - memory id: \(memory.id)")
            return memory.id
        }
    }

    /// Creates or updates the soul memory for a user
    public struct UpsertSoul: WriteCommand {
        private let content: String

        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        /// Initialize an UpsertSoul command
        /// - Parameter content: The soul/persona content
        public init(content: String) {
            self.content = content
            Logger.database.info("MemoryCommands.UpsertSoul initialized")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("MemoryCommands.UpsertSoul.execute started")

            guard let userId else {
                Logger.database.error("MemoryCommands.UpsertSoul.execute failed: user not found")
                throw DatabaseError.userNotFound
            }

            let user = try context.getUser(id: userId)

            // Try to find existing soul memory
            let soulType = MemoryType.soul.rawValue
            let descriptor = FetchDescriptor<Memory>(
                predicate: #Predicate<Memory> { memory in
                    memory.typeRaw == soulType && memory.chat == nil
                }
            )
            let existingMemories = try context.fetch(descriptor)
            let existingSoul = existingMemories.first { $0.user?.id == user.id }

            if let existingSoul {
                Logger.database.info("Updating existing soul memory: \(existingSoul.id)")
                existingSoul.content = content
                existingSoul.updatedAt = Date()
                try context.save()
                return existingSoul.id
            } else {
                Logger.database.info("Creating new soul memory")
                let memory = Memory(
                    type: .soul,
                    content: content,
                    keywords: ["soul", "persona", "identity"],
                    user: user
                )
                context.insert(memory)
                try context.save()
                Logger.database.info("MemoryCommands.UpsertSoul.execute completed - memory id: \(memory.id)")
                return memory.id
            }
        }
    }

    /// Appends content to today's daily log
    public struct AppendToDaily: WriteCommand {
        private let content: String
        private let chatId: UUID?

        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        /// Initialize an AppendToDaily command
        /// - Parameters:
        ///   - content: The content to append
        ///   - chatId: Optional chat association
        public init(content: String, chatId: UUID? = nil) {
            self.content = content
            self.chatId = chatId
            Logger.database.info("MemoryCommands.AppendToDaily initialized")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("MemoryCommands.AppendToDaily.execute started")

            guard let userId else {
                Logger.database.error("MemoryCommands.AppendToDaily.execute failed: user not found")
                throw DatabaseError.userNotFound
            }

            let user = try context.getUser(id: userId)

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

            // Try to find existing daily log for today
            let dailyType = MemoryType.daily.rawValue
            let descriptor = FetchDescriptor<Memory>(
                predicate: #Predicate<Memory> { memory in
                    memory.typeRaw == dailyType
                }
            )
            let dailyMemories = try context.fetch(descriptor)
            let existingDaily = dailyMemories.first { memory in
                memory.user?.id == user.id &&
                memory.chat?.id == chat?.id &&
                memory.date != nil &&
                calendar.isDate(memory.date!, inSameDayAs: today)
            }

            if let existingDaily {
                Logger.database.info("Appending to existing daily log: \(existingDaily.id)")
                existingDaily.content = existingDaily.content + "\n" + content
                existingDaily.updatedAt = Date()
                try context.save()
                return existingDaily.id
            } else {
                Logger.database.info("Creating new daily log for today")
                let memory = Memory(
                    type: .daily,
                    content: content,
                    date: today,
                    keywords: ["daily"],
                    chat: chat,
                    user: user
                )
                context.insert(memory)
                try context.save()
                Logger.database.info("MemoryCommands.AppendToDaily.execute completed - memory id: \(memory.id)")
                return memory.id
            }
        }
    }
}

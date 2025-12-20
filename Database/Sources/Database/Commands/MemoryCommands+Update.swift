import Foundation
import SwiftData
import OSLog
import Abstractions

// MARK: - Memory Update Commands
extension MemoryCommands {
    /// Updates a memory's content
    public struct Update: WriteCommand {
        private let memoryId: UUID
        private let content: String
        private let keywords: [String]?

        public var requiresUser: Bool { false }
        public var requiresRag: Bool { false }

        /// Initialize an Update command
        /// - Parameters:
        ///   - memoryId: The ID of the memory to update
        ///   - content: The new content
        ///   - keywords: Optional new keywords (nil to keep existing)
        public init(memoryId: UUID, content: String, keywords: [String]? = nil) {
            self.memoryId = memoryId
            self.content = content
            self.keywords = keywords
            Logger.database.info("MemoryCommands.Update initialized for memory: \(memoryId)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("MemoryCommands.Update.execute started for memory: \(memoryId)")

            let descriptor = FetchDescriptor<Memory>(
                predicate: #Predicate<Memory> { $0.id == memoryId }
            )

            guard let memory = try context.fetch(descriptor).first else {
                Logger.database.error("MemoryCommands.Update.execute failed: memory not found")
                throw DatabaseError.memoryNotFound
            }

            memory.content = content
            memory.updatedAt = Date()
            if let keywords {
                memory.keywords = keywords
            }

            try context.save()

            Logger.database.info("MemoryCommands.Update.execute completed successfully")
            return memory.id
        }
    }

    /// Adds keywords to a memory
    public struct AddKeywords: WriteCommand {
        private let memoryId: UUID
        private let keywords: [String]

        public var requiresUser: Bool { false }
        public var requiresRag: Bool { false }

        /// Initialize an AddKeywords command
        /// - Parameters:
        ///   - memoryId: The ID of the memory
        ///   - keywords: Keywords to add
        public init(memoryId: UUID, keywords: [String]) {
            self.memoryId = memoryId
            self.keywords = keywords
            Logger.database.info("MemoryCommands.AddKeywords initialized for memory: \(memoryId)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("MemoryCommands.AddKeywords.execute started")

            let descriptor = FetchDescriptor<Memory>(
                predicate: #Predicate<Memory> { $0.id == memoryId }
            )

            guard let memory = try context.fetch(descriptor).first else {
                Logger.database.error("MemoryCommands.AddKeywords.execute failed: memory not found")
                throw DatabaseError.memoryNotFound
            }

            // Add new keywords, avoiding duplicates
            var existingKeywords = Set(memory.keywords)
            existingKeywords.formUnion(keywords)
            memory.keywords = Array(existingKeywords)
            memory.updatedAt = Date()

            try context.save()

            Logger.database.info("MemoryCommands.AddKeywords.execute completed - keywords count: \(memory.keywords.count)")
            return memory.id
        }
    }
}

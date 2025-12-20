import Foundation
import SwiftData
import OSLog
import Abstractions

// MARK: - Chat Management Commands
extension ChatCommands {
    public struct Rename: WriteCommand {
        private let chatId: UUID
        private let newName: String

        public init(chatId: UUID, newName: String) {
            self.chatId = chatId
            self.newName = newName
            Logger.database.info("ChatCommands.Rename initialized - chatId: \(chatId), newName: \(newName)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("ChatCommands.Rename.execute started for chat: \(chatId)")

            // Validate the new name
            let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else {
                Logger.database.error("ChatCommands.Rename.execute failed: new name is empty or whitespace")
                throw DatabaseError.invalidInput("Chat title cannot be empty")
            }

            guard trimmedName.count <= 100 else {
                Logger.database.error("ChatCommands.Rename.execute failed: new name exceeds 100 characters")
                throw DatabaseError.invalidInput("Chat title cannot exceed 100 characters")
            }

            // Check for invalid characters (example validation)
            let allowedCharacters = CharacterSet.alphanumerics.union(.whitespaces).union(.punctuationCharacters)
            guard trimmedName.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
                Logger.database.error("ChatCommands.Rename.execute failed: new name contains invalid characters")
                throw DatabaseError.invalidInput("Chat title contains invalid characters")
            }

            let descriptor = FetchDescriptor<Chat>(
                predicate: #Predicate<Chat> { $0.id == chatId }
            )

            Logger.database.info("Fetching chat with id: \(chatId)")
            let chats = try context.fetch(descriptor)

            guard let chat = chats.first else {
                Logger.database.error("ChatCommands.Rename.execute failed: chat not found with id: \(chatId)")
                throw DatabaseError.chatNotFound
            }

            let oldName = chat.name
            Logger.database.info("Renaming chat from '\(oldName)' to '\(trimmedName)'")
            chat.name = trimmedName

            Logger.database.info("Saving context changes")
            try context.save()

            Logger.database.info("ChatCommands.Rename.execute completed successfully")
            return chat.id
        }
    }

    public struct Delete: WriteCommand & AnonymousCommand {
        private let id: UUID

        public init(id: UUID) {
            self.id = id
            Logger.database.info("ChatCommands.Delete initialized with id: \(id)")
        }

        public func execute(in context: ModelContext) throws -> UUID {
            // AnonymousCommand doesn't need userId or rag
            try execute(in: context, userId: nil, rag: nil)
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("ChatCommands.Delete.execute started for chat: \(id)")

            let descriptor = FetchDescriptor<Chat>(
                predicate: #Predicate<Chat> { $0.id == id }
            )

            Logger.database.info("Fetching chat with id: \(id)")
            let chats = try context.fetch(descriptor)

            guard let chat = chats.first else {
                Logger.database.error("ChatCommands.Delete.execute failed: chat not found with id: \(id)")
                throw DatabaseError.chatNotFound
            }

            let chatId = chat.id
            Logger.database.info("Found chat to delete: \(chatId)")

            Logger.database.info("Deleting chat from context")
            context.delete(chat)

            Logger.database.info("Saving context changes")
            try context.save()

            Logger.database.info("ChatCommands.Delete.execute completed successfully")
            return chatId
        }
    }

    public struct AutoRenameFromContent: WriteCommand {
        private let chatId: UUID
        private let externalProvider: (@Sendable (String) throws -> String)?

        // Private logger for timing operations
        private let logger = Logger(subsystem: "Database", category: "AutoRename")

        // Main initializer for runtime use
        public init(chatId: UUID) {
            self.chatId = chatId
            self.externalProvider = nil
            Logger.database.info("ChatCommands.AutoRenameFromContent initialized for chat: \(chatId)")
        }

        // Test initializer with external provider
        @preconcurrency
        public init(chatId: UUID, externalProvider: @escaping @Sendable (String) throws -> String) {
            self.chatId = chatId
            self.externalProvider = externalProvider
            Logger.database.info("ChatCommands.AutoRenameFromContent initialized for testing with chat: \(chatId)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("ChatCommands.AutoRenameFromContent.execute started")

            // Fetch the chat
            let chatDescriptor = FetchDescriptor<Chat>(
                predicate: #Predicate<Chat> { $0.id == chatId }
            )

            guard let chat = try context.fetch(chatDescriptor).first else {
                Logger.database.error("Chat not found with id: \(chatId)")
                throw DatabaseError.chatNotFound
            }

            // Check if chat already has a custom name (not "New Chat")
            guard chat.name == "New Chat" else {
                Logger.database.info("Chat already has custom name: '\(chat.name)', skipping rename")
                return chat.id
            }

            // Get messages ordered by creation date
            let sortedMessages = chat.messages.sorted { message1, message2 in
                message1.createdAt < message2.createdAt
            }

            // Need at least 2 messages (user + assistant)
            guard sortedMessages.count >= 2 else {
                Logger.database.info("Not enough messages for auto-rename (found: \(sortedMessages.count))")
                return chat.id
            }

            // Get the second message (assistant's response)
            let secondMessage = sortedMessages[1]

            // Check if the second message has a response (assistant message)
            guard let content = secondMessage.response,
                  !content.isEmpty else {
                Logger.database.info("Second message is not a valid assistant response")
                return chat.id
            }

            // Generate title using the provided logic
            let newTitle: String
            if let externalProvider = externalProvider {
                // Test path - use the injected provider
                newTitle = try externalProvider(content)
            } else {
                // Production path - use internal generation
                newTitle = generateTitle(from: content)
            }

            Logger.database.info("Generated new title: '\(newTitle)'")

            // Update the chat name
            chat.name = newTitle
            try context.save()

            Logger.database.info("ChatCommands.AutoRenameFromContent.execute completed successfully")
            return chat.id
        }

        private func generateTitle(from content: String) -> String {
            // Start timing
            let startTime = CFAbsoluteTimeGetCurrent()

            // Clean the content - remove markdown, code blocks, etc.
            let cleanedContent = content
                .replacingOccurrences(of: "```[\\s\\S]*?```", with: "", options: .regularExpression)
                .replacingOccurrences(of: "`[^`]*`", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\*\\*([^*]+)\\*\\*", with: "$1", options: .regularExpression)
                .replacingOccurrences(of: "\\*([^*]+)\\*", with: "$1", options: .regularExpression)
                .replacingOccurrences(of: "#+\\s*", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]+\\)", with: "$1", options: .regularExpression)
                .replacingOccurrences(of: "[\\n\\r]+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Extract first meaningful sentence or phrase
            let sentences = cleanedContent.components(separatedBy: CharacterSet(charactersIn: ".!?"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let title: String
            if let firstSentence = sentences.first {
                // Take first 50 characters of the first sentence
                let truncated = String(firstSentence.prefix(50))
                title = truncated.count < firstSentence.count ? truncated + "..." : truncated
            } else {
                // Fallback to first 50 characters of cleaned content
                let truncated = String(cleanedContent.prefix(50))
                title = truncated.count < cleanedContent.count ? truncated + "..." : truncated
            }

            // Log timing
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            logger.info("Title generation completed in \(String(format: "%.3f", timeElapsed))s")

            return title.isEmpty ? "New Chat" : title
        }
    }
}

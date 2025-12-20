import Foundation
import SwiftData
import OSLog
import Abstractions

// MARK: - Chat Read Commands
extension ChatCommands {
    public struct Read: ReadCommand {
        public typealias Result = Chat

        private let chatId: UUID

        public init(chatId: UUID) {
            self.chatId = chatId
            Logger.database.info("ChatCommands.Read initialized with chatId: \(chatId)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> Chat {
            Logger.database.info("ChatCommands.Read.execute started for chat: \(chatId)")

            let descriptor = FetchDescriptor<Chat>(
                predicate: #Predicate<Chat> { $0.id == chatId }
            )

            Logger.database.info("Fetching chat with id: \(chatId)")
            let chats = try context.fetch(descriptor)

            guard let chat = chats.first else {
                Logger.database.error("ChatCommands.Read.execute failed: chat not found with id: \(chatId)")
                throw DatabaseError.chatNotFound
            }

            Logger.database.info("ChatCommands.Read.execute completed successfully")
            return chat
        }
    }

    public struct GetAll: ReadCommand {
        public typealias Result = [Chat]

        public init() {
            Logger.database.info("ChatCommands.GetAll initialized")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> [Chat] {
            Logger.database.info("ChatCommands.GetAll.execute started")

            guard let userId else {
                Logger.database.error("ChatCommands.GetAll.execute failed: user not found")
                throw DatabaseError.userNotFound
            }

            Logger.database.info("Fetching user with id: \(userId.id.hashValue)")
            let user = try context.getUser(id: userId)
            Logger.database.info("Successfully fetched user: \(user.id)")

            let chats = Array(user.chats)
            Logger.database.info("ChatCommands.GetAll.execute completed - found \(chats.count) chats")
            return chats
        }
    }

    public struct HasChats: ReadCommand {
        public typealias Result = Bool

        public init() {}

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> Bool {
            guard let userId else {
                throw DatabaseError.userNotFound
            }

            guard let user = context.model(for: userId) as? User else {
                throw DatabaseError.userNotFound
            }

            return !user.chats.isEmpty
        }
    }

    public struct GetFirst: ReadCommand {
        public typealias Result = Chat

        public init() {
            Logger.database.info("ChatCommands.GetFirst initialized")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> Chat {
            Logger.database.info("ChatCommands.GetFirst.execute started")

            guard let userId else {
                Logger.database.error("ChatCommands.GetFirst.execute failed: user not found")
                throw DatabaseError.userNotFound
            }

            Logger.database.info("Fetching user with id: \(userId.id.hashValue)")
            let user = try context.getUser(id: userId)
            Logger.database.info("Successfully fetched user: \(user.id)")

            guard let firstChat = user.chats.first else {
                Logger.database.error("ChatCommands.GetFirst.execute failed: no chats found for user")
                throw DatabaseError.chatNotFound
            }

            Logger.database.info("ChatCommands.GetFirst.execute completed successfully - chat id: \(firstChat.id)")
            return firstChat
        }
    }
}

import Foundation
import SwiftData
import OSLog
import Abstractions

// MARK: - Chat Attachment Commands
extension ChatCommands {
    public struct HasAttachments: ReadCommand & AnonymousCommand {
        public typealias Result = Bool

        private let chatId: UUID

        public init(chatId: UUID) {
            self.chatId = chatId
            Logger.database.info("ChatCommands.HasAttachments initialized with chatId: \(chatId)")
        }

        public func execute(in context: ModelContext) throws -> Bool {
            // AnonymousCommand doesn't need userId or rag
            try execute(in: context, userId: nil, rag: nil)
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> Bool {
            Logger.database.info("ChatCommands.HasAttachments.execute started for chat: \(chatId)")

            let chat = try ChatCommands.Read(chatId: chatId).execute(in: context, userId: userId, rag: rag)

            // Get all files from all messages in the chat
            let messageFiles = chat.messages.compactMap { $0.file }.flatMap { $0 }

            // Also check for files attached directly to the chat
            let chatDescriptor = FetchDescriptor<FileAttachment>(
                predicate: #Predicate<FileAttachment> { $0.chat?.id == chatId }
            )
            let chatFiles = try context.fetch(chatDescriptor)

            let hasAttachments = !messageFiles.isEmpty || !chatFiles.isEmpty
            Logger.database.info("ChatCommands.HasAttachments.execute completed - has attachments: \(hasAttachments)")
            return hasAttachments
        }
    }

    public struct AttachmentFileTitles: ReadCommand & AnonymousCommand {
        public typealias Result = [String]

        private let chatId: UUID

        public init(chatId: UUID) {
            self.chatId = chatId
            Logger.database.info("ChatCommands.AttachmentFileTitles initialized with chatId: \(chatId)")
        }

        public func execute(in context: ModelContext) throws -> [String] {
            // AnonymousCommand doesn't need userId or rag
            try execute(in: context, userId: nil, rag: nil)
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> [String] {
            Logger.database.info("ChatCommands.AttachmentFileTitles.execute started for chat: \(chatId)")

            let chat = try ChatCommands.Read(chatId: chatId).execute(in: context, userId: userId, rag: rag)

            // Get all files from all messages in the chat
            let messageFiles = chat.messages.compactMap { $0.file }.flatMap { $0 }

            // Also get files attached directly to the chat
            let chatDescriptor = FetchDescriptor<FileAttachment>(
                predicate: #Predicate<FileAttachment> { $0.chat?.id == chatId }
            )
            let chatFiles = try context.fetch(chatDescriptor)

            // Combine all files and get their titles
            let allFiles = messageFiles + chatFiles
            let titles = allFiles.map { $0.name }
            Logger.database.info("ChatCommands.AttachmentFileTitles.execute completed - found \(titles.count) file titles")
            return titles
        }
    }
}

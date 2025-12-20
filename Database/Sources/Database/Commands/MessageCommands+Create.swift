import Foundation
import SwiftData
import OSLog
import Abstractions
import SwiftUI

// MARK: - Message Creation Commands
extension MessageCommands {
    public struct Create: WriteCommand & AnonymousCommand {
        // MARK: - Properties

        /// Logger for message creation operations
        private static let logger = Logger(subsystem: "Database", category: "MessageCommands")

        let chatId: UUID
        let userInput: String?
        let isDeepThinker: Bool
        public var requiresRag: Bool { true }

        // MARK: - Initialization

        public init(chatId: UUID, userInput: String?, isDeepThinker: Bool) {
            Self.logger.info("Create message command created - Chat: \(chatId), DeepThinker: \(isDeepThinker)")

            if let input = userInput {
                let inputPreview = String(input.prefix(50))
                Self.logger.debug("User input preview: \(inputPreview, privacy: .private)...")
                Self.logger.debug("User input length: \(input.count) characters")
            } else {
                Self.logger.debug("No user input provided")
            }

            self.chatId = chatId
            self.userInput = userInput
            self.isDeepThinker = isDeepThinker
        }

        // MARK: - Command Execution

        public func execute(in context: ModelContext) throws -> UUID {
            Self.logger.notice("Starting message creation for chat: \(chatId)")

            let startTime = CFAbsoluteTimeGetCurrent()

            do {
                Self.logger.info("Fetching chat with ID: \(chatId)")
                let descriptor = FetchDescriptor<Chat>(
                    predicate: #Predicate<Chat> { $0.id == chatId }
                )

                guard let chat = try context.performFetch(descriptor).first else {
                    Self.logger.error("Chat not found with ID: \(chatId)")
                    throw DatabaseError.chatNotFound
                }

                Self.logger.info("Chat found - Title: \(chat.id.uuidString, privacy: .public)")
                Self.logger.debug("Selected model: \(chat.languageModel.displayName, privacy: .public) (isDeepThinker: \(isDeepThinker))")

                Self.logger.debug("Creating message object...")
                let message = Message(
                    userInput: userInput,
                    chat: chat,
                    languageModelConfiguration: chat.languageModelConfig.copy(), // Here we create a copy that is owned by the Chat
                    languageModel: chat.languageModel,
                    imageModel: chat.imageModel
                )

                Self.logger.info("Message created with ID: \(message.id)")

                Self.logger.debug("Updating chat timestamp...")
                chat.updatedAt = Date()

                // Fetch and attach pending file attachments
                Self.logger.info("Searching for pending file attachments...")
                var fileDescriptor = FetchDescriptor<FileAttachment>(
                    predicate: #Predicate<FileAttachment> { file in
                        file.message == nil &&
                        file.chat != nil &&
                        file.chat?.id == chatId
                    }
                )
                fileDescriptor.includePendingChanges = true

                do {
                    let pendingFiles = try context.fetch(fileDescriptor)
                    Self.logger.info("Found \(pendingFiles.count) pending file attachments")

                    if !pendingFiles.isEmpty {
                        for (index, file) in pendingFiles.enumerated() {
                            Self.logger.debug("File \(index + 1): \(file.name, privacy: .public) (\(file.type, privacy: .public))")
                        }
                    }

                    addFileAttachments(to: message, pendingFiles)

                    Self.logger.debug("Inserting message into context...")
                    context.insert(message)

                    Self.logger.debug("Saving context...")
                    try context.save()

                    let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                    Self.logger.notice("Message creation completed in \(String(format: "%.3f", executionTime))s")
                    Self.logger.info(
                        "Summary - Message ID: \(message.id), Files attached: \(pendingFiles.count)"
                    )

                    return message.id
                } catch {
                    let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                    Self.logger.error(
                        "File attachment operation failed after \(String(format: "%.3f", executionTime))s: \(error.localizedDescription)"
                    )
                    throw error
                }
            } catch {
                let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                Self.logger.error("Message creation failed after \(String(format: "%.3f", executionTime))s: \(error.localizedDescription)")
                throw error
            }
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Self.logger.notice("Starting message creation with user context for chat: \(chatId)")
            return try execute(in: context)
        }

        // MARK: - Helper Methods

        private func addFileAttachments(to message: Message, _ files: [FileAttachment]) {
            Self.logger.debug("Starting file attachment process for \(files.count) files")

            let startTime = CFAbsoluteTimeGetCurrent()

            guard !files.isEmpty else {
                Self.logger.debug("No files to attach")
                return
            }

            for (index, file) in files.enumerated() {
                Self.logger.debug("Attaching file \(index + 1)/\(files.count): \(file.name, privacy: .public)")
                // File-message relationship is handled automatically
            }
            message.file = files

            let executionTime = CFAbsoluteTimeGetCurrent() - startTime
            Self.logger.info("File attachment completed in \(String(format: "%.3f", executionTime))s")
        }
    }
}

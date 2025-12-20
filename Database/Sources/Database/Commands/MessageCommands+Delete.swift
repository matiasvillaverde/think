import Foundation
import SwiftData
import OSLog
import Abstractions

// MARK: - Message Delete Commands
extension MessageCommands {
    public struct Delete: WriteCommand & AnonymousCommand {
        // MARK: - Properties

        /// Logger for message deletion operations
        private static let logger = Logger(subsystem: "Database", category: "MessageCommands")

        private let messageId: UUID

        // MARK: - Initialization

        public init(id: UUID) {
            Self.logger.info("Delete message command created for ID: \(id)")
            self.messageId = id
        }

        // MARK: - Command Execution

        public func execute(in context: ModelContext) throws -> UUID {
            Self.logger.notice("Starting message deletion for ID: \(messageId)")

            let startTime = CFAbsoluteTimeGetCurrent()

            do {
                Self.logger.debug("Creating fetch descriptor for message...")
                let descriptor = FetchDescriptor<Message>(
                    predicate: #Predicate<Message> { $0.id == messageId }
                )

                Self.logger.debug("Fetching message from context...")
                let messages = try context.fetch(descriptor)

                guard let message = messages.first else {
                    Self.logger.error("Message not found with ID: \(messageId)")
                    throw DatabaseError.messageNotFound
                }

                let chatId = message.chat?.id
                let hasResponse = message.response != nil
                let hasTools = message.channels?.contains { $0.type == .tool } ?? false
                let hasFiles = message.file?.isEmpty == false

                Self.logger.info(
                    "Message details - Chat: \(chatId?.uuidString ?? "nil", privacy: .public)"
                )
                Self.logger.debug("Response: \(hasResponse), Tools: \(hasTools), Files: \(hasFiles)")

                Self.logger.debug("Deleting message from context...")
                context.delete(message)

                Self.logger.debug("Saving context...")
                try context.save()

                let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                Self.logger.notice("Message deletion completed in \(String(format: "%.3f", executionTime))s")

                return messageId
            } catch {
                let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                Self.logger.error("Message deletion failed after \(String(format: "%.3f", executionTime))s: \(error.localizedDescription)")
                throw error
            }
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Self.logger.notice("Starting message deletion with user context for ID: \(messageId)")
            return try execute(in: context)
        }
    }
}

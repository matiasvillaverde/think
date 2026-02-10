import Abstractions
import Foundation
import OSLog
import SwiftData

// MARK: - Message Append Commands
extension MessageCommands {
    /// Appends content to the message's final channel (creating it if needed).
    ///
    /// Used for error reporting on failed generations so the user sees an inline,
    /// actionable message in the chat UI rather than only a transient toast.
    public struct AppendFinalChannelContent: WriteCommand {
        public typealias Result = UUID

        private static let logger = Logger(
            subsystem: "Database", category: "MessageCommands"
        )

        private let messageId: UUID
        private let appendedContent: String
        private let separator: String
        private let isComplete: Bool

        public var requiresRag: Bool { false }

        public init(
            messageId: UUID,
            appendedContent: String,
            separator: String = "\n\n---\n\n",
            isComplete: Bool
        ) {
            self.messageId = messageId
            self.appendedContent = appendedContent
            self.separator = separator
            self.isComplete = isComplete
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            let descriptor = FetchDescriptor<Message>(
                predicate: #Predicate<Message> { $0.id == messageId }
            )

            guard let message = try context.fetch(descriptor).first else {
                Self.logger.error("Message not found with ID: \(messageId)")
                throw DatabaseError.messageNotFound
            }

            let finalChannel: Channel
            if let channels = message.channels,
               let existing = channels
                   .filter({ $0.type == .final })
                   .min(by: { $0.order < $1.order }) {
                finalChannel = existing
            } else {
                let newChannel = Channel(
                    id: UUID(),
                    type: .final,
                    content: "",
                    order: 0,
                    recipient: nil,
                    associatedToolId: nil,
                    toolExecution: nil,
                    isComplete: false
                )
                newChannel.message = message
                context.insert(newChannel)
                if message.channels == nil {
                    message.channels = [newChannel]
                } else {
                    message.channels?.append(newChannel)
                }
                finalChannel = newChannel
            }

            let existingText: String = finalChannel.content
            let nextText: String
            if existingText.isEmpty {
                nextText = appendedContent
            } else {
                nextText = existingText + separator + appendedContent
            }

            finalChannel.updateContent(nextText)

            if isComplete {
                if finalChannel.isComplete == false {
                    finalChannel.markAsComplete()
                }
            } else {
                finalChannel.isComplete = false
            }

            message.version += 1
            try context.save()
            return message.id
        }
    }
}


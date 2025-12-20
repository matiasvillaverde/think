import Foundation
import SwiftData
import OSLog
import Abstractions

// MARK: - Message Read Commands
extension MessageCommands {
    public struct Read: ReadCommand {
        // MARK: - Properties

        public typealias Result = Message

        /// Logger for message read operations
        private static let logger = Logger(subsystem: "Database", category: "MessageCommands")

        private let messageId: UUID

        // MARK: - Initialization

        public init(id: UUID) {
            Self.logger.info("Read message command created for ID: \(id)")
            self.messageId = id
        }

        // MARK: - Command Execution

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> Message {
            Self.logger.notice("Starting message read for ID: \(messageId)")

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

                let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                Self.logger.notice("Message read completed in \(String(format: "%.3f", executionTime))s")
                Self.logger.info("Message details - Chat: \(message.chat?.id.uuidString ?? "nil", privacy: .public), Has Response: \(message.response != nil)")

                return message
            } catch {
                let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                Self.logger.error("Message read failed after \(String(format: "%.3f", executionTime))s: \(error.localizedDescription)")
                throw error
            }
        }
    }

    public struct GetAll: ReadCommand {
        // MARK: - Properties

        public typealias Result = [Message]

        /// Logger for message fetch operations
        private static let logger = Logger(subsystem: "Database", category: "MessageCommands")

        private let chatId: UUID

        // MARK: - Initialization

        public init(chatId: UUID) {
            Self.logger.info("GetAll messages command created for chat: \(chatId)")
            self.chatId = chatId
        }

        // MARK: - Command Execution

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> [Message] {
            Self.logger.notice("Starting fetch all messages for chat: \(chatId)")

            let startTime = CFAbsoluteTimeGetCurrent()

            do {
                Self.logger.debug("Creating optimized fetch descriptor...")
                var descriptor = FetchDescriptor<Message>(
                    predicate: #Predicate<Message> { $0.chat?.id == chatId }
                )

                // Sort by creation date for consistent ordering
                descriptor.sortBy = [SortDescriptor(\Message.createdAt)]

                Self.logger.debug("Fetching messages from context...")
                let messages = try context.fetch(descriptor)

                let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                Self.logger.notice("Message fetch completed in \(String(format: "%.3f", executionTime))s")
                Self.logger.info("Fetched \(messages.count) messages for chat")

                // Log message distribution
                if !messages.isEmpty {
                    let withResponses = messages.filter { $0.response != nil }.count
                    let withTools = messages.filter { message in
                        message.channels?.contains { $0.type == .tool } ?? false
                    }.count
                    let withFiles = messages.filter { $0.file != nil && !$0.file!.isEmpty }.count

                    Self.logger.debug("Message statistics - Responses: \(withResponses), Tools: \(withTools), Files: \(withFiles)")
                }

                return messages
            } catch {
                let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                Self.logger.error("Message fetch failed after \(String(format: "%.3f", executionTime))s: \(error.localizedDescription)")
                throw error
            }
        }
    }

    public struct CountMessages: ReadCommand {
        // MARK: - Properties

        public typealias Result = Int

        /// Logger for message count operations
        private static let logger = Logger(subsystem: "Database", category: "MessageCommands")

        private let chatId: UUID

        // MARK: - Initialization

        public init(chatId: UUID) {
            Self.logger.info("CountMessages command created for chat: \(chatId)")
            self.chatId = chatId
        }

        // MARK: - Command Execution

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> Int {
            Self.logger.notice("Starting message count for chat: \(chatId)")

            let startTime = CFAbsoluteTimeGetCurrent()

            do {
                // First verify the chat exists
                Self.logger.debug("Verifying chat exists...")
                let chatDescriptor = FetchDescriptor<Chat>(
                    predicate: #Predicate<Chat> { $0.id == chatId }
                )

                guard try context.fetchCount(chatDescriptor) > 0 else {
                    Self.logger.error("Chat not found with ID: \(chatId)")
                    throw DatabaseError.chatNotFound
                }

                Self.logger.debug("Creating optimized fetch descriptor for count...")
                var descriptor = FetchDescriptor<Message>(
                    predicate: #Predicate<Message> { $0.chat?.id == chatId }
                )

                // We only need the count, not the actual messages
                descriptor.fetchLimit = 0

                Self.logger.debug("Performing count query...")
                let count = try context.fetchCount(descriptor)

                let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                Self.logger.notice("Message count completed in \(String(format: "%.3f", executionTime))s")
                Self.logger.info("Chat \(chatId) has \(count) messages")

                return count
            } catch {
                let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                Self.logger.error("Message count failed after \(String(format: "%.3f", executionTime))s: \(error.localizedDescription)")
                throw error
            }
        }
    }
}

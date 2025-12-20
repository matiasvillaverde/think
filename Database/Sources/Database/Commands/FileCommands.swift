import AsyncAlgorithms
import Foundation
import SwiftData
import OSLog
import Abstractions
import SwiftUI

// swiftlint:disable line_length nesting

// MARK: - Logger Extension
extension Logger {
    static let fileCommands = Logger(
        subsystem: "Database",
        category: "FileCommands"
    )
}

// MARK: - File Commands
public enum FileCommands {
    public struct Create: WriteCommand {
        private let fileURL: URL
        private let chatId: UUID
        public var requiresRag: Bool { true }

        private let database: DatabaseProtocol

        public init(
            fileURL: URL,
            chatId: UUID,
            database: DatabaseProtocol
        ) {
            self.fileURL = fileURL
            self.chatId = chatId
            self.database = database

            Logger.fileCommands.info("Initializing Create command for file: \(fileURL.lastPathComponent, privacy: .public) in chat: \(chatId, privacy: .private)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.fileCommands.notice("Starting file creation execution for: \(fileURL.lastPathComponent, privacy: .public)")

            guard let rag else {
                Logger.fileCommands.error("RAG system not available - database not ready")
                throw DatabaseError.databaseNotReady
            }
            Logger.fileCommands.debug("RAG system confirmed available")

            Logger.fileCommands.debug("Fetching chat with ID: \(chatId, privacy: .private)")
            let descriptor = FetchDescriptor<Chat>(
                predicate: #Predicate<Chat> { $0.id == chatId }
            )
            guard let chat = try context.fetch(descriptor).first else {
                Logger.fileCommands.error("Chat not found with ID: \(chatId, privacy: .private)")
                throw DatabaseError.chatNotFound
            }
            Logger.fileCommands.debug("Successfully retrieved chat")

            Logger.fileCommands.info("Creating file attachment for: \(fileURL.lastPathComponent, privacy: .public)")
            let attachment = try FileAttachment(url: fileURL, chat: chat)
            context.insert(attachment)

            Logger.fileCommands.debug("Saving file attachment to context")
            try context.save()
            Logger.fileCommands.notice("File attachment saved successfully with ID: \(attachment.id, privacy: .private)")

            Logger.fileCommands.debug("Configuring RAG processing")
            let configuration = Configuration(
                tokenUnit: .word,
                strategy: .extractKeywords,
                table: chat.generateTableName(),
                chunking: .fileDefault
            )
            Logger.fileCommands.debug("RAG configuration created with table: \(chat.generateTableName(), privacy: .private)")

            let id = attachment.id
            let persistedId = attachment.id

            Logger.fileCommands.info("Starting background RAG processing task")
            attachment.backgroundTask = Task.detached(priority: .background) {
                Logger.fileCommands.debug("Background task started for file processing")

                do {
                    for try await progress in await rag.add(
                        fileURL: fileURL,
                        id: id,
                        configuration: configuration
                    )._throttle(for: .milliseconds(300), latest: true) {
                        let currentProgress = progress.fractionCompleted
                        Logger.fileCommands.debug("RAG processing progress: \(String(format: "%.2f", currentProgress * 100), privacy: .public)%")

                        guard !Task.isCancelled else {
                            Logger.fileCommands.notice("Background task cancelled during RAG processing")
                            return
                        }

                        Logger.fileCommands.debug("Updating progress in database")
                        try await database.write(
                            FileCommands.UpdateProgress(
                                fileId: persistedId,
                                fractionCompleted: currentProgress
                            )
                        )
                    }

                    Logger.fileCommands.debug("Saving database after RAG processing completion")
                    try await database.save()
                    Logger.fileCommands.notice("RAG processing completed successfully for file: \(fileURL.lastPathComponent, privacy: .public)")
                } catch {
                    Logger.fileCommands.error("RAG processing failed with error: \(error.localizedDescription, privacy: .public)")
                }
            }

            Logger.fileCommands.notice("File creation execution completed successfully, returning ID: \(attachment.id, privacy: .private)")
            return attachment.id
        }
    }

    public struct UpdateProgress: WriteCommand {
        private let fileId: UUID
        private let fractionCompleted: Double
        public var requiresRag: Bool { false }

        public init(fileId: UUID, fractionCompleted: Double) {
            self.fileId = fileId
            self.fractionCompleted = fractionCompleted

            Logger.fileCommands.debug("Initializing UpdateProgress command for file: \(fileId, privacy: .private) with progress: \(String(format: "%.2f", fractionCompleted * 100), privacy: .public)%")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.fileCommands.debug("Starting progress update execution for file: \(fileId, privacy: .private)")

            let descriptor = FetchDescriptor<FileAttachment>(
                predicate: #Predicate<FileAttachment> { $0.id == fileId }
            )
            guard let fileAttachment = try context.fetch(descriptor).first else {
                Logger.fileCommands.error("File attachment not found with ID: \(fileId, privacy: .private)")
                throw DatabaseError.chatNotFound
            }
            Logger.fileCommands.debug("Successfully retrieved file attachment")

            // Always update if this is the final progress (1.0)
            if fractionCompleted == 1 {
                Logger.fileCommands.notice("Final progress update (100%) - marking file as saved")
                withAnimation(.spring) {
                    fileAttachment.ragState = .saved
                    fileAttachment.progress = fractionCompleted
                }
                Logger.fileCommands.debug("Saving context after final progress update")
                try context.save()
                Logger.fileCommands.notice("File processing completed and saved successfully")
                return fileAttachment.id
            }

            Logger.fileCommands.debug("Intermediate progress update - marking file as saving")
            withAnimation(.spring) {
                fileAttachment.ragState = .saving
                fileAttachment.progress = fractionCompleted
            }
            Logger.fileCommands.debug("Saving context after progress update")
            try context.save()
            Logger.fileCommands.debug("Progress update completed successfully")

            return fileAttachment.id
        }
    }

    public struct Delete: WriteCommand {
        private let fileId: UUID
        public var requiresRag: Bool { true }

        public init(fileId: UUID) {
            self.fileId = fileId

            Logger.fileCommands.info("Initializing Delete command for file: \(fileId, privacy: .private)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.fileCommands.notice("Starting file deletion execution for ID: \(fileId, privacy: .private)")

            guard let rag else {
                Logger.fileCommands.error("RAG system not available - database not ready")
                throw DatabaseError.databaseNotReady
            }
            Logger.fileCommands.debug("RAG system confirmed available")

            Logger.fileCommands.debug("Fetching file attachment for deletion")
            let descriptor = FetchDescriptor<FileAttachment>(
                predicate: #Predicate<FileAttachment> { $0.id == fileId }
            )
            guard let file = try context.fetch(descriptor).first else {
                Logger.fileCommands.error("File not found with ID: \(fileId, privacy: .private)")
                throw DatabaseError.fileNotFound
            }
            Logger.fileCommands.debug("Successfully retrieved file attachment for deletion")

            Logger.fileCommands.debug("Cancelling background task if exists")
            file.backgroundTask?.cancel()
            file.backgroundTask = nil
            Logger.fileCommands.debug("Background task cancelled and cleared")

            Logger.fileCommands.info("Deleting file attachment from context")
            withAnimation(.easeOut) {
                context.delete(file)
            }

            Logger.fileCommands.debug("Saving context after file deletion")
            try context.save()
            Logger.fileCommands.notice("File attachment deleted from database successfully")

            let tableName = file.chat?.generateTableName() ?? Constants.defaultTable
            let id = file.id
            Logger.fileCommands.debug("Starting background RAG cleanup for table: \(tableName, privacy: .private)")

            Task.detached(priority: .background) {
                do {
                    Logger.fileCommands.debug("Executing RAG deletion for file ID: \(id, privacy: .private)")
                    try await rag.delete(id: id, table: tableName)
                    Logger.fileCommands.notice("RAG cleanup completed successfully for file: \(id, privacy: .private)")
                } catch {
                    Logger.fileCommands.error("RAG cleanup failed with error: \(error.localizedDescription, privacy: .public)")
                }
            }

            Logger.fileCommands.notice("File deletion execution completed successfully")
            return file.id
        }
    }

    public struct Get: ReadCommand {
        public typealias Result = FileAttachment
        private let fileId: UUID

        public init(fileId: UUID) {
            self.fileId = fileId

            Logger.fileCommands.debug("Initializing Get command for file: \(fileId, privacy: .private)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> FileAttachment {
            Logger.fileCommands.debug("Starting file retrieval execution for ID: \(fileId, privacy: .private)")

            let descriptor = FetchDescriptor<FileAttachment>(
                predicate: #Predicate<FileAttachment> { $0.id == fileId }
            )
            guard let file = try context.fetch(descriptor).first else {
                Logger.fileCommands.error("File not found with ID: \(fileId, privacy: .private)")
                throw DatabaseError.fileNotFound
            }

            Logger.fileCommands.debug("File retrieval completed successfully")
            return file
        }
    }
}

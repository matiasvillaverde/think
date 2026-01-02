import Abstractions
import Foundation
import OSLog
import SwiftData

// MARK: - Canvas Commands

public enum CanvasCommands {}

extension CanvasCommands {
    /// Creates a new canvas document.
    public struct Create: WriteCommand {
        private let title: String
        private let content: String
        private let chatId: UUID?

        public init(
            title: String,
            content: String = "",
            chatId: UUID?
        ) {
            self.title = title
            self.content = content
            self.chatId = chatId
            Logger.database.info("CanvasCommands.Create initialized")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            guard let userId else {
                throw DatabaseError.userNotFound
            }
            let user = try context.getUser(id: userId)

            let chat = try fetchChat(in: context, user: user)
            let canvas = CanvasDocument(
                title: title,
                content: content,
                chat: chat
            )
            context.insert(canvas)
            try context.save()
            return canvas.id
        }

        private func fetchChat(in context: ModelContext, user: User) throws -> Chat? {
            guard let chatId else {
                return nil
            }

            guard user.chats.contains(where: { $0.id == chatId }) else {
                throw DatabaseError.chatNotFound
            }

            let descriptor = FetchDescriptor<Chat>(
                predicate: #Predicate<Chat> { $0.id == chatId }
            )
            return try context.fetch(descriptor).first
        }
    }

    /// Fetch a canvas by id.
    public struct Get: ReadCommand {
        private let id: UUID

        public init(id: UUID) {
            self.id = id
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> CanvasDocument {
            let descriptor = FetchDescriptor<CanvasDocument>(
                predicate: #Predicate<CanvasDocument> { $0.id == id }
            )
            guard let canvas = try context.fetch(descriptor).first else {
                throw DatabaseError.invalidInput("Canvas not found")
            }
            return canvas
        }
    }

    /// List canvases, optionally filtered by chat.
    public struct List: ReadCommand {
        private let chatId: UUID?

        public init(chatId: UUID? = nil) {
            self.chatId = chatId
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> [CanvasDocument] {
            if let chatId {
                let descriptor = FetchDescriptor<CanvasDocument>(
                    predicate: #Predicate<CanvasDocument> { canvas in
                        canvas.chat?.id == chatId
                    }
                )
                return try context.fetch(descriptor)
            }

            let descriptor = FetchDescriptor<CanvasDocument>()
            return try context.fetch(descriptor)
        }
    }

    /// Updates an existing canvas.
    public struct Update: WriteCommand {
        private let id: UUID
        private let title: String?
        private let content: String?

        public init(
            id: UUID,
            title: String? = nil,
            content: String? = nil
        ) {
            self.id = id
            self.title = title
            self.content = content
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            let canvas = try CanvasCommands.Get(id: id).execute(
                in: context,
                userId: userId,
                rag: rag
            )

            if let title {
                canvas.title = title
            }
            if let content {
                canvas.content = content
            }
            canvas.updatedAt = Date()

            try context.save()
            return canvas.id
        }
    }

    /// Deletes a canvas.
    public struct Delete: WriteCommand {
        private let id: UUID

        public init(id: UUID) {
            self.id = id
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            let canvas = try CanvasCommands.Get(id: id).execute(
                in: context,
                userId: userId,
                rag: rag
            )
            context.delete(canvas)
            try context.save()
            return canvas.id
        }
    }

    /// Gets the most recent canvas for a chat, creating a default one if needed.
    public struct GetOrCreateDefault: WriteCommand {
        private let chatId: UUID
        private let title: String

        public init(chatId: UUID, title: String = "Canvas") {
            self.chatId = chatId
            self.title = title
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            let descriptor = FetchDescriptor<CanvasDocument>(
                predicate: #Predicate<CanvasDocument> { canvas in
                    canvas.chat?.id == chatId
                },
                sortBy: [SortDescriptor(\CanvasDocument.updatedAt, order: .reverse)]
            )
            if let existing = try context.fetch(descriptor).first {
                return existing.id
            }

            let canvas = CanvasDocument(title: title, chat: try fetchChat(in: context))
            context.insert(canvas)
            try context.save()
            return canvas.id
        }

        private func fetchChat(in context: ModelContext) throws -> Chat? {
            let descriptor = FetchDescriptor<Chat>(
                predicate: #Predicate<Chat> { $0.id == chatId }
            )
            guard let chat = try context.fetch(descriptor).first else {
                throw DatabaseError.chatNotFound
            }
            return chat
        }
    }
}

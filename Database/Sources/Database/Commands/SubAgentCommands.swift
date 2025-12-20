import Foundation
import SwiftData
import OSLog
import Abstractions

/// Commands for sub-agent run operations
public enum SubAgentCommands {}

// MARK: - Creation Commands
extension SubAgentCommands {
    /// Creates a new sub-agent run record
    public struct Create: WriteCommand {
        private let prompt: String
        private let mode: SubAgentMode
        private let tools: [String]
        private let parentMessageId: UUID?
        private let chatId: UUID?

        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        /// Initialize a Create command
        public init(
            prompt: String,
            mode: SubAgentMode,
            tools: [String] = [],
            parentMessageId: UUID? = nil,
            chatId: UUID? = nil
        ) {
            self.prompt = prompt
            self.mode = mode
            self.tools = tools
            self.parentMessageId = parentMessageId
            self.chatId = chatId
            Logger.database.info("SubAgentCommands.Create initialized")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("SubAgentCommands.Create.execute started")

            guard let userId else {
                throw DatabaseError.userNotFound
            }

            let user = try context.getUser(id: userId)

            // Find parent message if provided
            var parentMessage: Message?
            if let parentMessageId {
                let descriptor = FetchDescriptor<Message>(
                    predicate: #Predicate<Message> { $0.id == parentMessageId }
                )
                parentMessage = try context.fetch(descriptor).first
            }

            // Find chat if provided
            var chat: Chat?
            if let chatId {
                let descriptor = FetchDescriptor<Chat>(
                    predicate: #Predicate<Chat> { $0.id == chatId }
                )
                chat = try context.fetch(descriptor).first
            }

            let run = SubAgentRun(
                prompt: prompt,
                mode: mode,
                tools: tools,
                parentMessage: parentMessage,
                chat: chat,
                user: user
            )
            context.insert(run)
            try context.save()

            Logger.database.info("SubAgentCommands.Create.execute completed - run id: \(run.id)")
            return run.id
        }
    }
}

// MARK: - Read Commands
extension SubAgentCommands {
    /// Reads a single sub-agent run by ID
    public struct Read: ReadCommand {
        public typealias Result = SubAgentRun

        private let runId: UUID

        public var requiresUser: Bool { false }
        public var requiresRag: Bool { false }

        public init(runId: UUID) {
            self.runId = runId
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> SubAgentRun {
            let descriptor = FetchDescriptor<SubAgentRun>(
                predicate: #Predicate<SubAgentRun> { $0.id == runId }
            )

            let runs = try context.fetch(descriptor)
            guard let run = runs.first else {
                throw DatabaseError.subAgentRunNotFound
            }

            return run
        }
    }

    /// Gets all runs for a chat
    public struct GetForChat: ReadCommand {
        public typealias Result = [SubAgentRun]

        private let chatId: UUID

        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        public init(chatId: UUID) {
            self.chatId = chatId
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> [SubAgentRun] {
            guard let userId else {
                throw DatabaseError.userNotFound
            }

            let user = try context.getUser(id: userId)

            let descriptor = FetchDescriptor<SubAgentRun>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            let runs = try context.fetch(descriptor)

            return runs.filter { $0.chat?.id == chatId && $0.user?.id == user.id }
        }
    }

    /// Gets all active (running) sub-agent runs
    public struct GetActive: ReadCommand {
        public typealias Result = [SubAgentRun]

        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        public init() {}

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> [SubAgentRun] {
            guard let userId else {
                throw DatabaseError.userNotFound
            }

            let user = try context.getUser(id: userId)
            let runningStatus = SubAgentStatus.running.rawValue

            let descriptor = FetchDescriptor<SubAgentRun>(
                predicate: #Predicate<SubAgentRun> { $0.statusRaw == runningStatus },
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
            let runs = try context.fetch(descriptor)

            return runs.filter { $0.user?.id == user.id }
        }
    }
}

// MARK: - Update Commands
extension SubAgentCommands {
    /// Marks a run as completed
    public struct MarkCompleted: WriteCommand {
        private let runId: UUID
        private let output: String
        private let toolsUsed: [String]
        private let durationMs: Int

        public var requiresUser: Bool { false }
        public var requiresRag: Bool { false }

        public init(runId: UUID, output: String, toolsUsed: [String], durationMs: Int) {
            self.runId = runId
            self.output = output
            self.toolsUsed = toolsUsed
            self.durationMs = durationMs
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            let descriptor = FetchDescriptor<SubAgentRun>(
                predicate: #Predicate<SubAgentRun> { $0.id == runId }
            )

            guard let run = try context.fetch(descriptor).first else {
                throw DatabaseError.subAgentRunNotFound
            }

            run.markCompleted(output: output, toolsUsed: toolsUsed, durationMs: durationMs)
            try context.save()
            return run.id
        }
    }

    /// Marks a run as failed
    public struct MarkFailed: WriteCommand {
        private let runId: UUID
        private let error: String
        private let durationMs: Int

        public var requiresUser: Bool { false }
        public var requiresRag: Bool { false }

        public init(runId: UUID, error: String, durationMs: Int) {
            self.runId = runId
            self.error = error
            self.durationMs = durationMs
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            let descriptor = FetchDescriptor<SubAgentRun>(
                predicate: #Predicate<SubAgentRun> { $0.id == runId }
            )

            guard let run = try context.fetch(descriptor).first else {
                throw DatabaseError.subAgentRunNotFound
            }

            run.markFailed(error: error, durationMs: durationMs)
            try context.save()
            return run.id
        }
    }

    /// Marks a run as cancelled
    public struct MarkCancelled: WriteCommand {
        private let runId: UUID
        private let durationMs: Int

        public var requiresUser: Bool { false }
        public var requiresRag: Bool { false }

        public init(runId: UUID, durationMs: Int) {
            self.runId = runId
            self.durationMs = durationMs
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            let descriptor = FetchDescriptor<SubAgentRun>(
                predicate: #Predicate<SubAgentRun> { $0.id == runId }
            )

            guard let run = try context.fetch(descriptor).first else {
                throw DatabaseError.subAgentRunNotFound
            }

            run.markCancelled(durationMs: durationMs)
            try context.save()
            return run.id
        }
    }
}

// MARK: - Delete Commands
extension SubAgentCommands {
    /// Deletes a sub-agent run by ID
    public struct Delete: WriteCommand {
        private let runId: UUID

        public var requiresUser: Bool { false }
        public var requiresRag: Bool { false }

        public init(runId: UUID) {
            self.runId = runId
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            let descriptor = FetchDescriptor<SubAgentRun>(
                predicate: #Predicate<SubAgentRun> { $0.id == runId }
            )

            guard let run = try context.fetch(descriptor).first else {
                throw DatabaseError.subAgentRunNotFound
            }

            let deletedId = run.id
            context.delete(run)
            try context.save()
            return deletedId
        }
    }
}

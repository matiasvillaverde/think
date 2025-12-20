import Foundation
import SwiftData
import OSLog
import Abstractions

// MARK: - Tool Policy Creation Commands
extension ToolPolicyCommands {
    /// Creates a new tool policy
    public struct Create: WriteCommand {
        private let profile: ToolProfile
        private let allowList: [String]
        private let denyList: [String]
        private let isGlobal: Bool
        private let chatId: UUID?
        private let personalityId: UUID?

        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        /// Initialize a Create command
        /// - Parameters:
        ///   - profile: The base tool profile
        ///   - allowList: Additional tools to allow
        ///   - denyList: Tools to explicitly deny
        ///   - isGlobal: Whether this is a global default policy
        ///   - chatId: Optional chat association (highest priority)
        ///   - personalityId: Optional personality association
        public init(
            profile: ToolProfile,
            allowList: [String] = [],
            denyList: [String] = [],
            isGlobal: Bool = false,
            chatId: UUID? = nil,
            personalityId: UUID? = nil
        ) {
            self.profile = profile
            self.allowList = allowList
            self.denyList = denyList
            self.isGlobal = isGlobal
            self.chatId = chatId
            self.personalityId = personalityId
            Logger.database.info("ToolPolicyCommands.Create initialized with profile: \(profile.rawValue)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("ToolPolicyCommands.Create.execute started")

            guard let userId else {
                Logger.database.error("ToolPolicyCommands.Create.execute failed: user not found")
                throw DatabaseError.userNotFound
            }

            let user = try context.getUser(id: userId)

            // Find chat if chatId is provided
            var chat: Chat?
            if let chatId {
                let chatDescriptor = FetchDescriptor<Chat>(
                    predicate: #Predicate<Chat> { $0.id == chatId }
                )
                chat = try context.fetch(chatDescriptor).first
            }

            // Find personality if personalityId is provided
            var personality: Personality?
            if let personalityId {
                let personalityDescriptor = FetchDescriptor<Personality>(
                    predicate: #Predicate<Personality> { $0.id == personalityId }
                )
                personality = try context.fetch(personalityDescriptor).first
            }

            Logger.database.info("Creating new tool policy with profile: \(profile.rawValue)")
            let policy = ToolPolicy(
                profile: profile,
                allowList: allowList,
                denyList: denyList,
                isGlobal: isGlobal,
                chat: chat,
                personality: personality,
                user: user
            )
            context.insert(policy)

            try context.save()

            Logger.database.info("ToolPolicyCommands.Create.execute completed - policy id: \(policy.id)")
            return policy.id
        }
    }

    /// Creates or updates a policy for a chat
    public struct UpsertForChat: WriteCommand {
        private let chatId: UUID
        private let profile: ToolProfile
        private let allowList: [String]
        private let denyList: [String]

        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        /// Initialize an UpsertForChat command
        public init(
            chatId: UUID,
            profile: ToolProfile,
            allowList: [String] = [],
            denyList: [String] = []
        ) {
            self.chatId = chatId
            self.profile = profile
            self.allowList = allowList
            self.denyList = denyList
            Logger.database.info("ToolPolicyCommands.UpsertForChat initialized for chat: \(chatId)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("ToolPolicyCommands.UpsertForChat.execute started")

            guard let userId else {
                Logger.database.error("ToolPolicyCommands.UpsertForChat.execute failed: user not found")
                throw DatabaseError.userNotFound
            }

            let user = try context.getUser(id: userId)

            // Find the chat
            let chatDescriptor = FetchDescriptor<Chat>(
                predicate: #Predicate<Chat> { $0.id == chatId }
            )
            guard let chat = try context.fetch(chatDescriptor).first else {
                Logger.database.error("ToolPolicyCommands.UpsertForChat.execute failed: chat not found")
                throw DatabaseError.chatNotFound
            }

            // Try to find existing policy for this chat
            let descriptor = FetchDescriptor<ToolPolicy>()
            let policies = try context.fetch(descriptor)
            let existingPolicy = policies.first { $0.chat?.id == chatId && $0.user?.id == user.id }

            if let existingPolicy {
                Logger.database.info("Updating existing policy: \(existingPolicy.id)")
                existingPolicy.setProfile(profile)
                existingPolicy.allowList = allowList
                existingPolicy.denyList = denyList
                try context.save()
                return existingPolicy.id
            } else {
                Logger.database.info("Creating new policy for chat: \(chatId)")
                let policy = ToolPolicy(
                    profile: profile,
                    allowList: allowList,
                    denyList: denyList,
                    chat: chat,
                    user: user
                )
                context.insert(policy)
                try context.save()
                return policy.id
            }
        }
    }

    /// Creates or updates the global default policy
    public struct UpsertGlobal: WriteCommand {
        private let profile: ToolProfile
        private let allowList: [String]
        private let denyList: [String]

        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        /// Initialize an UpsertGlobal command
        public init(
            profile: ToolProfile,
            allowList: [String] = [],
            denyList: [String] = []
        ) {
            self.profile = profile
            self.allowList = allowList
            self.denyList = denyList
            Logger.database.info("ToolPolicyCommands.UpsertGlobal initialized")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("ToolPolicyCommands.UpsertGlobal.execute started")

            guard let userId else {
                Logger.database.error("ToolPolicyCommands.UpsertGlobal.execute failed: user not found")
                throw DatabaseError.userNotFound
            }

            let user = try context.getUser(id: userId)

            // Try to find existing global policy
            let descriptor = FetchDescriptor<ToolPolicy>(
                predicate: #Predicate<ToolPolicy> { $0.isGlobal == true }
            )
            let policies = try context.fetch(descriptor)
            let existingPolicy = policies.first { $0.user?.id == user.id }

            if let existingPolicy {
                Logger.database.info("Updating existing global policy: \(existingPolicy.id)")
                existingPolicy.setProfile(profile)
                existingPolicy.allowList = allowList
                existingPolicy.denyList = denyList
                try context.save()
                return existingPolicy.id
            } else {
                Logger.database.info("Creating new global policy")
                let policy = ToolPolicy(
                    profile: profile,
                    allowList: allowList,
                    denyList: denyList,
                    isGlobal: true,
                    user: user
                )
                context.insert(policy)
                try context.save()
                return policy.id
            }
        }
    }
}

import Foundation
import SwiftData
import OSLog
import Abstractions

// MARK: - Tool Policy Read Commands
extension ToolPolicyCommands {
    /// Reads a single tool policy by ID
    public struct Read: ReadCommand {
        public typealias Result = ToolPolicy

        private let policyId: UUID

        public var requiresUser: Bool { false }
        public var requiresRag: Bool { false }

        /// Initialize a Read command
        /// - Parameter policyId: The ID of the policy to read
        public init(policyId: UUID) {
            self.policyId = policyId
            Logger.database.info("ToolPolicyCommands.Read initialized with policyId: \(policyId)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> ToolPolicy {
            Logger.database.info("ToolPolicyCommands.Read.execute started for policy: \(policyId)")

            let descriptor = FetchDescriptor<ToolPolicy>(
                predicate: #Predicate<ToolPolicy> { $0.id == policyId }
            )

            let policies = try context.fetch(descriptor)
            guard let policy = policies.first else {
                Logger.database.error("ToolPolicyCommands.Read.execute failed: policy not found")
                throw DatabaseError.toolPolicyNotFound
            }

            Logger.database.info("ToolPolicyCommands.Read.execute completed successfully")
            return policy
        }
    }

    /// Gets the policy for a specific chat
    public struct GetForChat: ReadCommand {
        public typealias Result = ToolPolicy?

        private let chatId: UUID

        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        /// Initialize a GetForChat command
        /// - Parameter chatId: The chat ID to get policy for
        public init(chatId: UUID) {
            self.chatId = chatId
            Logger.database.info("ToolPolicyCommands.GetForChat initialized for chat: \(chatId)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> ToolPolicy? {
            Logger.database.info("ToolPolicyCommands.GetForChat.execute started")

            guard let userId else {
                Logger.database.error("ToolPolicyCommands.GetForChat.execute failed: user not found")
                throw DatabaseError.userNotFound
            }

            let user = try context.getUser(id: userId)

            let descriptor = FetchDescriptor<ToolPolicy>()
            let policies = try context.fetch(descriptor)
            let chatPolicy = policies.first { $0.chat?.id == chatId && $0.user?.id == user.id }

            Logger.database.info("ToolPolicyCommands.GetForChat.execute completed - found: \(chatPolicy != nil)")
            return chatPolicy
        }
    }

    /// Gets the global default policy
    public struct GetGlobal: ReadCommand {
        public typealias Result = ToolPolicy?

        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        public init() {
            Logger.database.info("ToolPolicyCommands.GetGlobal initialized")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> ToolPolicy? {
            Logger.database.info("ToolPolicyCommands.GetGlobal.execute started")

            guard let userId else {
                Logger.database.error("ToolPolicyCommands.GetGlobal.execute failed: user not found")
                throw DatabaseError.userNotFound
            }

            let user = try context.getUser(id: userId)

            let descriptor = FetchDescriptor<ToolPolicy>(
                predicate: #Predicate<ToolPolicy> { $0.isGlobal == true }
            )
            let policies = try context.fetch(descriptor)
            let globalPolicy = policies.first { $0.user?.id == user.id }

            Logger.database.info("ToolPolicyCommands.GetGlobal.execute completed - found: \(globalPolicy != nil)")
            return globalPolicy
        }
    }

    /// Resolves the effective policy for a chat by checking chat > personality > user > global
    public struct ResolveForChat: ReadCommand {
        public typealias Result = ResolvedToolPolicy

        private let chatId: UUID

        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        /// Initialize a ResolveForChat command
        /// - Parameter chatId: The chat ID to resolve policy for
        public init(chatId: UUID) {
            self.chatId = chatId
            Logger.database.info("ToolPolicyCommands.ResolveForChat initialized for chat: \(chatId)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> ResolvedToolPolicy {
            Logger.database.info("ToolPolicyCommands.ResolveForChat.execute started")

            guard let userId else {
                Logger.database.error("ToolPolicyCommands.ResolveForChat.execute failed: user not found")
                throw DatabaseError.userNotFound
            }

            let user = try context.getUser(id: userId)

            // Fetch the chat to get personality
            let chatDescriptor = FetchDescriptor<Chat>(
                predicate: #Predicate<Chat> { $0.id == chatId }
            )
            let chat = try context.fetch(chatDescriptor).first

            // Collect applicable policies in priority order
            var policies: [ToolPolicy] = []

            let descriptor = FetchDescriptor<ToolPolicy>()
            let allPolicies = try context.fetch(descriptor).filter { $0.user?.id == user.id }

            // 1. Chat-specific policy (highest priority)
            if let chatPolicy = allPolicies.first(where: { $0.chat?.id == chatId }) {
                policies.append(chatPolicy)
            }

            // 2. Personality-specific policy
            if let personalityId = chat?.personality?.id,
               let personalityPolicy = allPolicies.first(where: {
                   $0.personality?.id == personalityId && $0.chat == nil
               }) {
                policies.append(personalityPolicy)
            }

            // 3. Global default policy
            if let globalPolicy = allPolicies.first(where: { $0.isGlobal }) {
                policies.append(globalPolicy)
            }

            // If no policies found, return full access
            guard let primaryPolicy = policies.first else {
                Logger.database.info("No policies found, returning full access")
                return .allowAll
            }

            // Start with the most specific policy's profile
            var allowed = primaryPolicy.profile.includedTools
            let sourceProfile = primaryPolicy.profile
            var addedTools: Set<ToolIdentifier> = []
            var removedTools: Set<ToolIdentifier> = []

            // Apply allow/deny lists from all policies (most specific wins)
            for policy in policies {
                let allowedFromList = policy.allowList.compactMap { ToolIdentifier.from(toolName: $0) }
                let deniedFromList = policy.denyList.compactMap { ToolIdentifier.from(toolName: $0) }

                for tool in allowedFromList where !allowed.contains(tool) {
                    allowed.insert(tool)
                    addedTools.insert(tool)
                }

                for tool in deniedFromList where allowed.contains(tool) {
                    allowed.remove(tool)
                    removedTools.insert(tool)
                }
            }

            let resolved = ResolvedToolPolicy(
                allowedTools: allowed,
                sourceProfile: sourceProfile,
                addedTools: addedTools,
                removedTools: removedTools
            )

            Logger.database.info("""
                ToolPolicyCommands.ResolveForChat.execute completed - \
                allowed: \(allowed.count) tools, profile: \(sourceProfile.rawValue)
                """)
            return resolved
        }
    }
}

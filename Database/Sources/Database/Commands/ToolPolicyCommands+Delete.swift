import Foundation
import SwiftData
import OSLog
import Abstractions

// MARK: - Tool Policy Delete Commands
extension ToolPolicyCommands {
    /// Deletes a tool policy by ID
    public struct Delete: WriteCommand {
        private let policyId: UUID

        public var requiresUser: Bool { false }
        public var requiresRag: Bool { false }

        /// Initialize a Delete command
        /// - Parameter policyId: The ID of the policy to delete
        public init(policyId: UUID) {
            self.policyId = policyId
            Logger.database.info("ToolPolicyCommands.Delete initialized for policy: \(policyId)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("ToolPolicyCommands.Delete.execute started")

            let descriptor = FetchDescriptor<ToolPolicy>(
                predicate: #Predicate<ToolPolicy> { $0.id == policyId }
            )

            let policies = try context.fetch(descriptor)
            guard let policy = policies.first else {
                Logger.database.error("ToolPolicyCommands.Delete.execute failed: policy not found")
                throw DatabaseError.toolPolicyNotFound
            }

            let deletedId = policy.id
            context.delete(policy)
            try context.save()

            Logger.database.info("ToolPolicyCommands.Delete.execute completed")
            return deletedId
        }
    }

    /// Deletes the policy for a specific chat
    public struct DeleteForChat: WriteCommand {
        private let chatId: UUID

        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        /// Initialize a DeleteForChat command
        public init(chatId: UUID) {
            self.chatId = chatId
            Logger.database.info("ToolPolicyCommands.DeleteForChat initialized for chat: \(chatId)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("ToolPolicyCommands.DeleteForChat.execute started")

            guard let userId else {
                throw DatabaseError.userNotFound
            }

            let user = try context.getUser(id: userId)

            let descriptor = FetchDescriptor<ToolPolicy>()
            let policies = try context.fetch(descriptor)
            let chatPolicies = policies.filter { $0.chat?.id == chatId && $0.user?.id == user.id }

            for policy in chatPolicies {
                context.delete(policy)
            }

            try context.save()
            Logger.database.info(
                "ToolPolicyCommands.DeleteForChat.execute completed - deleted \(chatPolicies.count) policies"
            )
            return chatId
        }
    }
}

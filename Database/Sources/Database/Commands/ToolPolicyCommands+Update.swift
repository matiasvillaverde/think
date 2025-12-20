import Foundation
import SwiftData
import OSLog
import Abstractions

// MARK: - Tool Policy Update Commands
extension ToolPolicyCommands {
    /// Updates a tool policy
    public struct Update: WriteCommand {
        private let policyId: UUID
        private let profile: ToolProfile?
        private let allowList: [String]?
        private let denyList: [String]?

        public var requiresUser: Bool { false }
        public var requiresRag: Bool { false }

        /// Initialize an Update command
        /// - Parameters:
        ///   - policyId: The ID of the policy to update
        ///   - profile: New profile (nil to keep existing)
        ///   - allowList: New allow list (nil to keep existing)
        ///   - denyList: New deny list (nil to keep existing)
        public init(
            policyId: UUID,
            profile: ToolProfile? = nil,
            allowList: [String]? = nil,
            denyList: [String]? = nil
        ) {
            self.policyId = policyId
            self.profile = profile
            self.allowList = allowList
            self.denyList = denyList
            Logger.database.info("ToolPolicyCommands.Update initialized for policy: \(policyId)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("ToolPolicyCommands.Update.execute started")

            let descriptor = FetchDescriptor<ToolPolicy>(
                predicate: #Predicate<ToolPolicy> { $0.id == policyId }
            )

            let policies = try context.fetch(descriptor)
            guard let policy = policies.first else {
                Logger.database.error("ToolPolicyCommands.Update.execute failed: policy not found")
                throw DatabaseError.toolPolicyNotFound
            }

            if let profile {
                policy.setProfile(profile)
            }
            if let allowList {
                policy.allowList = allowList
            }
            if let denyList {
                policy.denyList = denyList
            }
            policy.updatedAt = Date()

            try context.save()
            Logger.database.info("ToolPolicyCommands.Update.execute completed")
            return policy.id
        }
    }

    /// Adds a tool to the allow list
    public struct AddToAllowList: WriteCommand {
        private let policyId: UUID
        private let toolName: String

        public var requiresUser: Bool { false }
        public var requiresRag: Bool { false }

        /// Initialize an AddToAllowList command
        public init(policyId: UUID, toolName: String) {
            self.policyId = policyId
            self.toolName = toolName
            Logger.database.info("ToolPolicyCommands.AddToAllowList initialized")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("ToolPolicyCommands.AddToAllowList.execute started")

            let descriptor = FetchDescriptor<ToolPolicy>(
                predicate: #Predicate<ToolPolicy> { $0.id == policyId }
            )

            let policies = try context.fetch(descriptor)
            guard let policy = policies.first else {
                throw DatabaseError.toolPolicyNotFound
            }

            if !policy.allowList.contains(toolName) {
                policy.allowList.append(toolName)
                // Remove from deny list if present
                policy.denyList.removeAll { $0 == toolName }
                policy.updatedAt = Date()
                try context.save()
            }

            Logger.database.info("ToolPolicyCommands.AddToAllowList.execute completed")
            return policy.id
        }
    }

    /// Adds a tool to the deny list
    public struct AddToDenyList: WriteCommand {
        private let policyId: UUID
        private let toolName: String

        public var requiresUser: Bool { false }
        public var requiresRag: Bool { false }

        /// Initialize an AddToDenyList command
        public init(policyId: UUID, toolName: String) {
            self.policyId = policyId
            self.toolName = toolName
            Logger.database.info("ToolPolicyCommands.AddToDenyList initialized")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("ToolPolicyCommands.AddToDenyList.execute started")

            let descriptor = FetchDescriptor<ToolPolicy>(
                predicate: #Predicate<ToolPolicy> { $0.id == policyId }
            )

            let policies = try context.fetch(descriptor)
            guard let policy = policies.first else {
                throw DatabaseError.toolPolicyNotFound
            }

            if !policy.denyList.contains(toolName) {
                policy.denyList.append(toolName)
                // Remove from allow list if present
                policy.allowList.removeAll { $0 == toolName }
                policy.updatedAt = Date()
                try context.save()
            }

            Logger.database.info("ToolPolicyCommands.AddToDenyList.execute completed")
            return policy.id
        }
    }
}

import Foundation
import SwiftData
import OSLog
import Abstractions

// MARK: - Skill Update Commands
extension SkillCommands {
    /// Updates a skill's content
    public struct Update: WriteCommand {
        private let skillId: UUID
        private let name: String?
        private let skillDescription: String?
        private let instructions: String?
        private let tools: [String]?

        public var requiresUser: Bool { false }
        public var requiresRag: Bool { false }

        /// Initialize an Update command
        /// - Parameters:
        ///   - skillId: The ID of the skill to update
        ///   - name: New name (nil to keep existing)
        ///   - skillDescription: New description (nil to keep existing)
        ///   - instructions: New instructions (nil to keep existing)
        ///   - tools: New tools array (nil to keep existing)
        public init(
            skillId: UUID,
            name: String? = nil,
            skillDescription: String? = nil,
            instructions: String? = nil,
            tools: [String]? = nil
        ) {
            self.skillId = skillId
            self.name = name
            self.skillDescription = skillDescription
            self.instructions = instructions
            self.tools = tools
            Logger.database.info("SkillCommands.Update initialized for skill: \(skillId)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("SkillCommands.Update.execute started")

            let descriptor = FetchDescriptor<Skill>(
                predicate: #Predicate<Skill> { $0.id == skillId }
            )

            let skills = try context.fetch(descriptor)
            guard let skill = skills.first else {
                Logger.database.error("SkillCommands.Update.execute failed: skill not found")
                throw DatabaseError.skillNotFound
            }

            if let name {
                skill.name = name
            }
            if let skillDescription {
                skill.skillDescription = skillDescription
            }
            if let instructions {
                skill.instructions = instructions
            }
            if let tools {
                skill.tools = tools
            }
            skill.updatedAt = Date()

            try context.save()
            Logger.database.info("SkillCommands.Update.execute completed")
            return skill.id
        }
    }

    /// Toggles a skill's enabled state
    public struct SetEnabled: WriteCommand {
        private let skillId: UUID
        private let isEnabled: Bool

        public var requiresUser: Bool { false }
        public var requiresRag: Bool { false }

        /// Initialize a SetEnabled command
        /// - Parameters:
        ///   - skillId: The ID of the skill to update
        ///   - isEnabled: The new enabled state
        public init(skillId: UUID, isEnabled: Bool) {
            self.skillId = skillId
            self.isEnabled = isEnabled
            Logger.database.info("SkillCommands.SetEnabled initialized for skill: \(skillId)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("SkillCommands.SetEnabled.execute started")

            let descriptor = FetchDescriptor<Skill>(
                predicate: #Predicate<Skill> { $0.id == skillId }
            )

            let skills = try context.fetch(descriptor)
            guard let skill = skills.first else {
                Logger.database.error("SkillCommands.SetEnabled.execute failed: skill not found")
                throw DatabaseError.skillNotFound
            }

            skill.isEnabled = isEnabled
            skill.updatedAt = Date()

            try context.save()
            Logger.database.info("SkillCommands.SetEnabled.execute completed - enabled: \(isEnabled)")
            return skill.id
        }
    }
}

import Foundation
import SwiftData
import OSLog
import Abstractions

// MARK: - Skill Delete Commands
extension SkillCommands {
    /// Deletes a skill by ID
    public struct Delete: WriteCommand {
        private let skillId: UUID

        public var requiresUser: Bool { false }
        public var requiresRag: Bool { false }

        /// Initialize a Delete command
        /// - Parameter skillId: The ID of the skill to delete
        public init(skillId: UUID) {
            self.skillId = skillId
            Logger.database.info("SkillCommands.Delete initialized for skill: \(skillId)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("SkillCommands.Delete.execute started")

            let descriptor = FetchDescriptor<Skill>(
                predicate: #Predicate<Skill> { $0.id == skillId }
            )

            let skills = try context.fetch(descriptor)
            guard let skill = skills.first else {
                Logger.database.error("SkillCommands.Delete.execute failed: skill not found")
                throw DatabaseError.skillNotFound
            }

            let deletedId = skill.id
            context.delete(skill)
            try context.save()

            Logger.database.info("SkillCommands.Delete.execute completed")
            return deletedId
        }
    }

    /// Deletes all user-created skills (not system skills)
    public struct DeleteAllUserSkills: WriteCommand {
        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        public init() {
            Logger.database.info("SkillCommands.DeleteAllUserSkills initialized")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("SkillCommands.DeleteAllUserSkills.execute started")

            guard let userId else {
                Logger.database.error("SkillCommands.DeleteAllUserSkills.execute failed: user not found")
                throw DatabaseError.userNotFound
            }

            let user = try context.getUser(id: userId)

            let descriptor = FetchDescriptor<Skill>(
                predicate: #Predicate<Skill> { skill in
                    !skill.isSystem
                }
            )
            let userSkills = try context.fetch(descriptor).filter { $0.user?.id == user.id }

            for skill in userSkills {
                context.delete(skill)
            }

            try context.save()
            Logger.database.info(
                "SkillCommands.DeleteAllUserSkills.execute completed - deleted \(userSkills.count) skills"
            )
            return user.id
        }
    }
}
